import Foundation

struct LocalLLMConfig {
    let modelFileName: String
    let modelFileExtension: String
    let modelSubdirectory: String?
    let maxTokens: Int
    let temperature: Double
    let topP: Double
    let stopSequences: [String]

    static let `default` = LocalLLMConfig(
        modelFileName: "qwen2.5-1.5b-instruct-q8_0",
        modelFileExtension: "gguf",
        modelSubdirectory: nil,
        maxTokens: 256,
        temperature: 0.2,
        topP: 0.9,
        stopSequences: ["\nUser:", "\nUtente:"]
    )
}

enum LocalLLMState: Equatable {
    case idle
    case loading
    case ready
    case unavailable(String)
    case failed(String)
}

protocol LocalLLMRuntime {
    func loadModel(at path: String, config: LocalLLMConfig) throws
    func generate(prompt: String, config: LocalLLMConfig) async throws -> String
}

enum LocalLLMError: Error {
    case runtimeUnavailable
    case modelNotFound
    case generationFailed
    case downloadFailed
    case configurationMissing
}

final class LocalLLMService: ObservableObject {
    static let shared = LocalLLMService()

    @Published private(set) var state: LocalLLMState = .idle
    @Published private(set) var modelPath: String?

    private let runtime: LocalLLMRuntime
    private let config: LocalLLMConfig
    private var hasAttemptedLoad = false
    private let loadQueue = DispatchQueue(label: "com.tyrevibes.llm.load", qos: .userInitiated)

    init(runtime: LocalLLMRuntime = LlamaCppRuntime(), config: LocalLLMConfig = .default) {
        self.runtime = runtime
        self.config = config
    }

    var isReady: Bool {
        if case .ready = state {
            return true
        }
        return false
    }

    func prepare() {
        loadModelIfNeeded()
    }

    func loadModelIfNeeded() {
        guard !hasAttemptedLoad else { return }
        hasAttemptedLoad = true
        state = .loading

        Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await self.ensureModelAvailable()
                await MainActor.run {
                    self.modelPath = url.path
                }
                try await self.loadModel(at: url)
            } catch LocalLLMError.runtimeUnavailable {
                await self.failLoad(with: .unavailable("Runtime LLM non disponibile."))
            } catch LocalLLMError.configurationMissing {
                await self.failLoad(with: .unavailable("URL modello non configurato."))
            } catch LocalLLMError.modelNotFound {
                await self.failLoad(with: .unavailable("Modello LLM non disponibile."))
            } catch LocalLLMError.downloadFailed {
                await self.failLoad(with: .failed("Download modello fallito."))
            } catch {
                await self.failLoad(with: .failed("Errore caricamento modello."))
            }
        }
    }

    func generateResponse(prompt: String) async -> String? {
        if !isReady {
            if case .idle = state {
                loadModelIfNeeded()
            }
            return nil
        }

        do {
            let response = try await runtime.generate(prompt: prompt, config: config)
            return response.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            state = .failed("Errore generazione risposta.")
            return nil
        }
    }

    private func resolveModelURL(config: LocalLLMConfig) -> URL? {
        if let subdirectory = config.modelSubdirectory,
           let url = Bundle.main.url(
               forResource: config.modelFileName,
               withExtension: config.modelFileExtension,
               subdirectory: subdirectory
           ) {
            return url
        }

        return Bundle.main.url(
            forResource: config.modelFileName,
            withExtension: config.modelFileExtension
        )
    }

    private func ensureModelAvailable() async throws -> URL {
        let destination = try localModelURL()
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        guard let remoteURL = resolveRemoteModelURL() else {
            throw LocalLLMError.configurationMissing
        }

        try await downloadModel(from: remoteURL, to: destination)
        return destination
    }

    private func localModelURL() throws -> URL {
        let supportDir = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let llmDir = supportDir.appendingPathComponent("LLM", isDirectory: true)
        try FileManager.default.createDirectory(at: llmDir, withIntermediateDirectories: true)

        let fileName = "\(config.modelFileName).\(config.modelFileExtension)"
        return llmDir.appendingPathComponent(fileName)
    }

    private func resolveRemoteModelURL() -> URL? {
        guard let path = Bundle.main.path(forResource: "Api", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let urlString = plist["LLM_MODEL_URL"] as? String,
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }

    private func downloadModel(from remoteURL: URL, to destination: URL) async throws {
        let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LocalLLMError.downloadFailed
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: tempURL, to: destination)
    }

    private func loadModel(at url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            loadQueue.async { [weak self] in
                guard let self else { return }
                do {
                    try self.runtime.loadModel(at: url.path, config: self.config)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        await MainActor.run {
            self.state = .ready
        }
    }

    @MainActor
    private func failLoad(with state: LocalLLMState) {
        self.state = state
        self.hasAttemptedLoad = false
    }
}

struct StubLocalLLMRuntime: LocalLLMRuntime {
    func loadModel(at path: String, config: LocalLLMConfig) throws {
        throw LocalLLMError.runtimeUnavailable
    }

    func generate(prompt: String, config: LocalLLMConfig) async throws -> String {
        throw LocalLLMError.runtimeUnavailable
    }
}
