import Foundation

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL non valido"
        case .invalidResponse:
            return "Risposta dal server non valida"
        case .httpError(let statusCode, let message):
            return "Errore HTTP \(statusCode): \(message ?? "Errore sconosciuto")"
        case .decodingError(let error):
            return "Errore decodifica dati: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Errore codifica dati: \(error.localizedDescription)"
        case .networkError(let error):
            return "Errore di rete: \(error.localizedDescription)"
        case .unauthorized:
            return "Non autorizzato - Effettua il login"
        case .forbidden:
            return "Accesso negato"
        case .notFound:
            return "Risorsa non trovata"
        case .serverError:
            return "Errore del server - Riprova più tardi"
        case .timeout:
            return "Timeout della richiesta"
        }
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

// MARK: - Network Manager
class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private let baseURL: String
    private let timeout: TimeInterval = 30.0

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        self.session = URLSession(configuration: config)

        // Load base URL from Api.plist
        if let path = Bundle.main.path(forResource: "Api", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let baseURLString = plist["BASE_URL"] as? String {
            self.baseURL = baseURLString
        } else {
            self.baseURL = ""
            print("⚠️ [NetworkManager] BASE_URL not found in Api.plist")
        }
    }

    // MARK: - Generic Request Method
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        body: Data? = nil
    ) async throws -> T {
        // Build URL
        guard var urlComponents = URLComponents(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }

        // Add query parameters for GET requests
        if method == .get, let parameters = parameters {
            urlComponents.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: "\(value)")
            }
        }

        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add body for POST/PUT/PATCH
        if let body = body {
            request.httpBody = body
        } else if method != .get, let parameters = parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            } catch {
                throw NetworkError.encodingError(error)
            }
        }

        // Log request
        logRequest(request)

        // Track API call start time
        let startTime = Date()
        var success = false
        var statusCode: Int?
        var errorType: String?

        // Execute request
        do {
            let (data, response) = try await session.data(for: request)

            // Get status code for tracking
            if let httpResponse = response as? HTTPURLResponse {
                statusCode = httpResponse.statusCode
            }

            // Validate response
            try validateResponse(response, data: data)

            // Log response
            logResponse(response, data: data)

            // Decode response
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601

                let decodedData = try decoder.decode(T.self, from: data)
                success = true

                // Track successful API call
                let duration = Date().timeIntervalSince(startTime)
                let latency = duration * 1000 // ms

                Task {
                    await AnalyticsManager.shared.track(
                        .apiRequestCompleted(
                            endpoint: endpoint,
                            duration: duration,
                            success: true,
                            statusCode: statusCode,
                            errorType: nil
                        )
                    )

                    if let code = statusCode {
                        await AnalyticsManager.shared.track(
                            .apiLatency(endpoint: endpoint, latency: latency, statusCode: code)
                        )
                    }
                }

                return decodedData
            } catch {
                // Try to print the response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❌ [NetworkManager] Decoding failed. Response: \(jsonString)")
                }

                errorType = "decoding_error"

                // Track decoding error
                let duration = Date().timeIntervalSince(startTime)
                Task {
                    await AnalyticsManager.shared.track(
                        .apiRequestCompleted(
                            endpoint: endpoint,
                            duration: duration,
                            success: false,
                            statusCode: statusCode,
                            errorType: errorType
                        )
                    )
                }

                throw NetworkError.decodingError(error)
            }
        } catch let error as NetworkError {
            errorType = getErrorType(error)

            // Track network error
            let duration = Date().timeIntervalSince(startTime)
            Task {
                await AnalyticsManager.shared.track(
                    .apiRequestCompleted(
                        endpoint: endpoint,
                        duration: duration,
                        success: false,
                        statusCode: statusCode,
                        errorType: errorType
                    )
                )
            }

            throw error
        } catch {
            errorType = "network_error"

            // Track general error
            let duration = Date().timeIntervalSince(startTime)
            Task {
                await AnalyticsManager.shared.track(
                    .apiRequestCompleted(
                        endpoint: endpoint,
                        duration: duration,
                        success: false,
                        statusCode: statusCode,
                        errorType: errorType
                    )
                )
            }

            throw NetworkError.networkError(error)
        }
    }

    // MARK: - Request without response body
    func requestWithoutResponse(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        body: Data? = nil
    ) async throws {
        // Build URL
        guard var urlComponents = URLComponents(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }

        if method == .get, let parameters = parameters {
            urlComponents.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: "\(value)")
            }
        }

        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = body {
            request.httpBody = body
        } else if method != .get, let parameters = parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            } catch {
                throw NetworkError.encodingError(error)
            }
        }

        logRequest(request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        logResponse(response, data: data)
    }

    // MARK: - Validate Response
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 408:
            throw NetworkError.timeout
        case 500...599:
            throw NetworkError.serverError
        default:
            let message = String(data: data, encoding: .utf8)
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    // MARK: - Logging
    private func logRequest(_ request: URLRequest) {
        #if DEBUG
        print("🌐 [NetworkManager] Request: \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "")")
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("📋 [NetworkManager] Headers: \(headers)")
        }
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("📦 [NetworkManager] Body: \(bodyString.prefix(500))")
        }
        #endif
    }

    private func logResponse(_ response: URLResponse, data: Data) {
        #if DEBUG
        if let httpResponse = response as? HTTPURLResponse {
            print("✅ [NetworkManager] Response: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 [NetworkManager] Data: \(responseString.prefix(500))")
            }
        }
        #endif
    }

    // MARK: - Convenience Methods
    func get<T: Decodable>(
        endpoint: String,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        try await request(endpoint: endpoint, method: .get, parameters: parameters, headers: headers)
    }

    func post<T: Decodable>(
        endpoint: String,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        try await request(endpoint: endpoint, method: .post, parameters: parameters, headers: headers)
    }

    func post<T: Decodable, E: Encodable>(
        endpoint: String,
        body: E,
        headers: [String: String]? = nil
    ) async throws -> T {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        let bodyData = try encoder.encode(body)
        return try await request(endpoint: endpoint, method: .post, headers: headers, body: bodyData)
    }

    func delete(
        endpoint: String,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil
    ) async throws {
        try await requestWithoutResponse(endpoint: endpoint, method: .delete, parameters: parameters, headers: headers)
    }

    // MARK: - Helper Methods

    private func getErrorType(_ error: NetworkError) -> String {
        switch error {
        case .invalidURL:
            return "invalid_url"
        case .invalidResponse:
            return "invalid_response"
        case .httpError:
            return "http_error"
        case .decodingError:
            return "decoding_error"
        case .encodingError:
            return "encoding_error"
        case .networkError:
            return "network_error"
        case .unauthorized:
            return "unauthorized"
        case .forbidden:
            return "forbidden"
        case .notFound:
            return "not_found"
        case .serverError:
            return "server_error"
        case .timeout:
            return "timeout"
        }
    }
}
