import Foundation

enum DeepSeekServiceError: LocalizedError {
    case invalidURL
    case missingApiKey
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case emptyResponse
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Endpoint DeepSeek non configurato correttamente."
        case .missingApiKey:
            return "Serve la chiave API DeepSeek."
        case .invalidResponse:
            return "Risposta DeepSeek non valida."
        case .httpError(let statusCode, let message):
            return "Errore DeepSeek \(statusCode): \(message ?? "risposta sconosciuta")"
        case .emptyResponse:
            return "DeepSeek non ha restituito contenuto testuale."
        case .decodingError(let error):
            return "Impossibile decodificare la risposta DeepSeek: \(error.localizedDescription)"
        }
    }
}

protocol DeepSeekServiceProtocol {
    var isConfigured: Bool { get }
    func generateResponse(prompt: String) async throws -> String
}

final class DeepSeekService: DeepSeekServiceProtocol {
    static let shared = DeepSeekService()

    private struct ChatCompletionRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }

    private struct ChatCompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }

            let message: Message?
        }

        let choices: [Choice]?
    }

    private let session: URLSession
    private let baseURL: URL?
    private let apiKey: String?
    private let model: String

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 35
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)

        let configPlistPath: String? = {
            Bundle.main.path(forResource: "Api", ofType: "plist")
        }()
        let configPlist = configPlistPath.flatMap { NSDictionary(contentsOfFile: $0) }

        if let urlString = configPlist?["DEEPSEEK_BASE_URL"] as? String, !urlString.isEmpty {
            baseURL = URL(string: urlString)
        } else {
            baseURL = URL(string: "https://api.deepseek.com/chat/completions")
            #if DEBUG
            print("⚠️ [DeepSeekService] DEEPSEEK_BASE_URL missing in Api.plist, using default.")
            #endif
        }

        apiKey = configPlist?["DEEPSEEK_API_KEY"] as? String
        if let configuredModel = configPlist?["DEEPSEEK_MODEL"] as? String, !configuredModel.isEmpty {
            model = configuredModel
        } else {
            model = "deepseek-chat"
            #if DEBUG
            print("⚠️ [DeepSeekService] DEEPSEEK_MODEL missing in Api.plist, using default.")
            #endif
        }

        #if DEBUG
        if apiKey?.isEmpty ?? true {
            print("⚠️ [DeepSeekService] DEEPSEEK_API_KEY missing or empty in Api.plist.")
        }
        #endif
    }

    init(session: URLSession, baseURL: URL?, apiKey: String?, model: String) {
        self.session = session
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }

    func generateResponse(prompt: String) async throws -> String {
        #if DEBUG
        let start = Date()
        var outcome = "error"
        var lastStatusCode: Int?
        defer {
            let elapsedMs = Int(Date().timeIntervalSince(start) * 1_000)
            let statusPart = lastStatusCode.map { " status=\($0)" } ?? ""
            print("ℹ️ [DeepSeekService] \(outcome) model=\(model)\(statusPart) durationMs=\(elapsedMs)")
        }
        #endif

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw DeepSeekServiceError.emptyResponse
        }

        guard let url = baseURL else {
            throw DeepSeekServiceError.invalidURL
        }
        guard let key = apiKey, !key.isEmpty else {
            throw DeepSeekServiceError.missingApiKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let body = ChatCompletionRequest(
            model: model,
            messages: [.init(role: "user", content: trimmedPrompt)],
            temperature: 0.2,
            max_tokens: 256
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw DeepSeekServiceError.decodingError(error)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekServiceError.invalidResponse
        }

        #if DEBUG
        lastStatusCode = httpResponse.statusCode
        #endif

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = Self.compactMessage(from: data)
            throw DeepSeekServiceError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        let payload: ChatCompletionResponse
        do {
            payload = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw DeepSeekServiceError.decodingError(error)
        }

        guard let content = payload.choices?.first?.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw DeepSeekServiceError.emptyResponse
        }

        #if DEBUG
        outcome = "success"
        #endif

        return content
    }

    var isConfigured: Bool {
        baseURL != nil && !(apiKey?.isEmpty ?? true)
    }

    private static func compactMessage(from data: Data, maxLength: Int = 280) -> String? {
        guard let raw = String(data: data, encoding: .utf8)?
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        if raw.count <= maxLength { return raw }
        return String(raw.prefix(maxLength)) + "..."
    }
}
