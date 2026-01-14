import Foundation

#if canImport(llama)
import llama

final class LlamaCppRuntime: LocalLLMRuntime {
    private let queue = DispatchQueue(label: "com.tyrevibes.llama.runtime", qos: .userInitiated)
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var vocab: OpaquePointer?
    private var backendReady = false

    func loadModel(at path: String, config: LocalLLMConfig) throws {
        if model != nil, context != nil {
            return
        }

        if !backendReady {
            llama_backend_init()
            backendReady = true
        }

        var mparams = llama_model_default_params()
        mparams.n_gpu_layers = 0
        mparams.use_mmap = true
        mparams.use_mlock = false
        mparams.check_tensors = false

        guard let loadedModel = llama_model_load_from_file(path, mparams) else {
            throw LocalLLMError.modelNotFound
        }

        var cparams = llama_context_default_params()
        cparams.n_ctx = 2048
        cparams.n_batch = 512
        let threads = max(2, ProcessInfo.processInfo.activeProcessorCount - 1)
        cparams.n_threads = Int32(threads)
        cparams.n_threads_batch = Int32(threads)

        guard let ctx = llama_init_from_model(loadedModel, cparams) else {
            llama_model_free(loadedModel)
            throw LocalLLMError.runtimeUnavailable
        }

        model = loadedModel
        context = ctx
        vocab = llama_model_get_vocab(loadedModel)
    }

    func generate(prompt: String, config: LocalLLMConfig) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: LocalLLMError.generationFailed)
                    return
                }

                do {
                    let output = try self.generateSync(prompt: prompt, config: config)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func generateSync(prompt: String, config: LocalLLMConfig) throws -> String {
        guard let ctx = context, let vocab = vocab else {
            throw LocalLLMError.runtimeUnavailable
        }

        llama_memory_clear(llama_get_memory(ctx), true)

        let promptTokens = try tokenize(prompt, vocab: vocab, addSpecial: true)
        if promptTokens.isEmpty {
            throw LocalLLMError.generationFailed
        }

        let batch = promptTokens.withUnsafeBufferPointer { buffer in
            llama_batch_get_one(UnsafeMutablePointer(mutating: buffer.baseAddress), Int32(promptTokens.count))
        }
        var decodeBatch = batch
        if llama_decode(ctx, decodeBatch) != 0 {
            throw LocalLLMError.generationFailed
        }

        let sampler = try buildSampler(config: config)
        defer { llama_sampler_free(sampler) }

        var output = ""
        for _ in 0..<config.maxTokens {
            let token = llama_sampler_sample(sampler, ctx, -1)
            if llama_vocab_is_eog(vocab, token) {
                break
            }

            llama_sampler_accept(sampler, token)

            if let piece = tokenToString(token, vocab: vocab) {
                output.append(piece)
            }

            if containsStopSequence(output, stopSequences: config.stopSequences) {
                output = trimStopSequences(from: output, stopSequences: config.stopSequences)
                break
            }

            var tokenCopy = token
            decodeBatch = llama_batch_get_one(&tokenCopy, 1)
            if llama_decode(ctx, decodeBatch) != 0 {
                break
            }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildSampler(config: LocalLLMConfig) throws -> UnsafeMutablePointer<llama_sampler> {
        var params = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(params) else {
            throw LocalLLMError.runtimeUnavailable
        }

        guard let topK = llama_sampler_init_top_k(40) else {
            throw LocalLLMError.runtimeUnavailable
        }
        guard let topP = llama_sampler_init_top_p(Float(config.topP), 1) else {
            throw LocalLLMError.runtimeUnavailable
        }
        guard let temp = llama_sampler_init_temp(Float(config.temperature)) else {
            throw LocalLLMError.runtimeUnavailable
        }
        guard let dist = llama_sampler_init_dist(UInt32(Date().timeIntervalSince1970)) else {
            throw LocalLLMError.runtimeUnavailable
        }

        llama_sampler_chain_add(chain, topK)
        llama_sampler_chain_add(chain, topP)
        llama_sampler_chain_add(chain, temp)
        llama_sampler_chain_add(chain, dist)

        return chain
    }

    private func tokenize(_ text: String, vocab: OpaquePointer, addSpecial: Bool) throws -> [llama_token] {
        let utf8 = Array(text.utf8)
        let maxTokens = Int32(utf8.count + 8)
        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))

        let count = utf8.withUnsafeBufferPointer { buffer in
            return llama_tokenize(
                vocab,
                buffer.baseAddress?.withMemoryRebound(to: Int8.self, capacity: buffer.count) { $0 },
                Int32(buffer.count),
                &tokens,
                maxTokens,
                addSpecial,
                false
            )
        }

        if count < 0 {
            throw LocalLLMError.generationFailed
        }

        return Array(tokens.prefix(Int(count)))
    }

    private func tokenToString(_ token: llama_token, vocab: OpaquePointer) -> String? {
        var buffer = [Int8](repeating: 0, count: 256)
        var length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, true)

        if length < 0 {
            let needed = Int(-length)
            buffer = [Int8](repeating: 0, count: needed)
            length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, true)
        }

        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private func containsStopSequence(_ text: String, stopSequences: [String]) -> Bool {
        stopSequences.contains { text.contains($0) }
    }

    private func trimStopSequences(from text: String, stopSequences: [String]) -> String {
        for stop in stopSequences {
            if let range = text.range(of: stop) {
                return String(text[..<range.lowerBound])
            }
        }
        return text
    }
}

#else

final class LlamaCppRuntime: LocalLLMRuntime {
    func loadModel(at path: String, config: LocalLLMConfig) throws {
        throw LocalLLMError.runtimeUnavailable
    }

    func generate(prompt: String, config: LocalLLMConfig) async throws -> String {
        throw LocalLLMError.runtimeUnavailable
    }
}

#endif
