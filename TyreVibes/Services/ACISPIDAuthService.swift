import Foundation
import SwiftUI
import WebKit

/// Servizio per gestire l'autenticazione SPID tramite ACI
class ACISPIDAuthService: ObservableObject {
    static let shared = ACISPIDAuthService()

    private let vehicleEndpoint = URL(string: "https://bollo.aci.it/api/v2/vehicle")!

    @Published var isAuthenticating: Bool = false
    @Published var authError: ACIAuthError?
    @Published var authCookies: [HTTPCookie] = []
    @Published var vehicleResponse: BolloAPIResponse?

    private init() {}

    private var loginURL: URL? {
        // Pagina di login ACI: l'utente vede il bottone SPID, lo preme,
        // e il redirect naturale post-SPID porta a bollo.aci.it con il ssoid.
        // L'app Angular di bollo.aci.it gestisce da sola: POST /user → /fase0 → /fase1 → GET /vehicle.
        var components = URLComponents(string: "https://login.aci.it/index.php")
        components?.queryItems = [
            URLQueryItem(name: "do", value: "genNotAuth"),
            URLQueryItem(name: "id", value: "login"),
            URLQueryItem(name: "application_key", value: "bollonet")
        ]
        return components?.url
    }

    /// Avvia il flusso di autenticazione SPID tramite ACI
    /// - Parameters:
    ///   - clearCookies: Se true, pulisce i cookie prima di avviare l'autenticazione
    ///   - completion: Callback con l'URL di login o errore
    func startAuthentication(clearCookies: Bool = true, completion: @escaping (Result<URL, ACIAuthError>) -> Void) {
        print("🔐 [ACISPIDAuth] Avvio autenticazione SPID Mobile...")

        guard let url = loginURL else {
            let error = ACIAuthError.invalidURL
            DispatchQueue.main.async {
                self.authError = error
                completion(.failure(error))
            }
            return
        }

        DispatchQueue.main.async {
            self.isAuthenticating = true
            self.authError = nil
        }

        // Pulisci i cookie se richiesto
        if clearCookies {
            print("🧹 [ACISPIDAuth] Pulizia cookie prima dell'autenticazione...")
            let dataStore = WKWebsiteDataStore.default()
            dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {
                    print("✅ [ACISPIDAuth] Cookie puliti, avvio autenticazione")
                    // IMPORTANTE: Garantisce che il completion avvenga sul main thread
                    DispatchQueue.main.async {
                        completion(.success(url))
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(.success(url))
            }
        }
    }

    /// Gestisce il completamento dell'autenticazione salvando i cookie
    /// - Parameters:
    ///   - url: URL di redirect dopo l'autenticazione
    ///   - cookies: Cookie di sessione ottenuti
    func handleAuthenticationSuccess(url: URL, cookies: [HTTPCookie]) {
        print("✅ [ACISPIDAuth] Autenticazione completata con successo")
        print("📥 [ACISPIDAuth] URL finale: \(url.absoluteString)")
        print("🍪 [ACISPIDAuth] Cookie ricevuti: \(cookies.count)")

        authCookies = cookies
        isAuthenticating = false

        for cookie in cookies {
            print("🍪 [ACISPIDAuth] Cookie: \(cookie.name) = \(cookie.value)")
        }
    }

    /// Gestisce il completamento del recupero dati veicolo dopo autenticazione
    func handleVehicleResponse(_ response: BolloAPIResponse) {
        DispatchQueue.main.async {
            print("🚗 [ACISPIDAuth] Risposta vehicle ricevuta (veicoli: \(response.veicoli?.count ?? 0))")
            self.vehicleResponse = response
            self.isAuthenticating = false
            self.authError = nil
        }
    }

    /// Recupera i dati dei veicoli usando i cookie forniti
    func fetchVehicleData(
        using cookies: [HTTPCookie],
        completion: @escaping (Result<BolloAPIResponse, ACIAuthError>) -> Void
    ) {
        guard !cookies.isEmpty else {
            print("❌ [ACISPIDAuth] Nessun cookie fornito per fetchVehicleData")
            completion(.failure(.authenticationFailed))
            return
        }

        // MARK: - reCAPTCHA (anchor + reload) — integrazione minima
        /// Configurazione per reCAPTCHA anchor/reload
        struct RecaptchaConfig {
            let siteKey: String             // es: "6LcFLzYUAAAAAJ8GvWPHV3lJukQAOAP52rMQ6g67"
            let origin: String              // es: "https://bollo.aci.it:443"
            let locale: String              // es: "it"
            let version: String             // es: "bGi-DxR800F5_ueMVcTwXc6q" (varia nel tempo)
            let size: String                // es: "invisible"
            let anchorMs: Int               // es: 20000
            let executeMs: Int              // es: 15000

            init(
                siteKey: String,
                origin: String = "https://bollo.aci.it",
                locale: String = "it",
                version: String = "bGi-DxR800F5_ueMVcTwXc6q",
                size: String = "invisible",
                anchorMs: Int = 20000,
                executeMs: Int = 15000
            ) {
                self.siteKey = siteKey
                self.origin = origin
                self.locale = locale
                self.version = version
                self.size = size
                self.anchorMs = anchorMs
                self.executeMs = executeMs
            }

            /// URL di anchor (GET) come visto da DevTools
            func anchorURL() -> URL? {
                // co = base64(origin)
                let coB64 = Data(origin.utf8).base64EncodedString()
                var components = URLComponents(string: "https://www.google.com/recaptcha/api2/anchor")
                components?.queryItems = [
                    URLQueryItem(name: "ar", value: "1"),
                    URLQueryItem(name: "k", value: siteKey),
                    URLQueryItem(name: "co", value: "aHR0cHM6Ly9ib2xsby5hY2kuaXQ6NDQz"),
                    URLQueryItem(name: "hl", value: locale),
                    URLQueryItem(name: "v", value: version),
                    URLQueryItem(name: "size", value: size),
                    URLQueryItem(name: "anchor-ms", value: String(anchorMs)),
                    URLQueryItem(name: "execute-ms", value: String(executeMs)),
                    URLQueryItem(name: "cb", value: String((0..<16).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! }))
                ]
                return components?.url
            }

            /// URL di reload (POST) — il token viene restituito nel body della risposta
            func reloadURL() -> URL? {
                var components = URLComponents(string: "https://www.google.com/recaptcha/api2/reload")
                components?.queryItems = [
                    URLQueryItem(name: "k", value: siteKey)
                ]
                return components?.url
            }
        }

        /// Risultato della chiamata anchor con token e bft
        struct AnchorResult {
            let token: String
            let bft: String
        }

        /// Effettua la chiamata di anchor per inizializzare l'iframe/cookie di reCAPTCHA e restituisce il token anchor e il bft.
        /// Cerca il valore dell'input hidden "recaptcha-token" e "recaptcha-bft" nella risposta HTML.
        func recaptchaAnchor(config: RecaptchaConfig, completion: @escaping (Result<AnchorResult, ACIAuthError>) -> Void) {
            guard let url = config.anchorURL() else {
                completion(.failure(.invalidURL))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "Accept")
            request.setValue("https://bollo.aci.it/", forHTTPHeaderField: "Referer")
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ [reCAPTCHA] Anchor error: \(error.localizedDescription)")
                    completion(.failure(.networkError(error)))
                    return
                }
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data, let html = String(data: data, encoding: .utf8) else {
                    print("❌ [reCAPTCHA] Anchor: risposta non valida o status code errato")
                    completion(.failure(.invalidResponse))
                    return
                }

                // Cerca <input type="hidden" id="recaptcha-token" value="...">
                let tokenPattern = #"<input[^>]*id=["']recaptcha-token["'][^>]*value=["']([^"']+)["']"#
                guard let tokenRegex = try? NSRegularExpression(pattern: tokenPattern, options: []),
                      let tokenMatch = tokenRegex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
                      let tokenRange = Range(tokenMatch.range(at: 1), in: html) else {
                    print("⚠️ [reCAPTCHA] Anchor: recaptcha-token non trovato nell'HTML")
                    print("📄 [reCAPTCHA] HTML response preview: \(html.prefix(500))")
                    completion(.failure(.invalidResponse))
                    return
                }
                let token = String(html[tokenRange])

                // Cerca il bft (bot fingerprint token) - può essere in diversi formati
                var bft = ""

                // Pattern 1: <input type="hidden" id="recaptcha-bft" value="...">
                let bftPattern1 = #"<input[^>]*id=["']recaptcha-bft["'][^>]*value=["']([^"']+)["']"#
                if let bftRegex1 = try? NSRegularExpression(pattern: bftPattern1, options: []),
                   let bftMatch1 = bftRegex1.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
                   let bftRange1 = Range(bftMatch1.range(at: 1), in: html) {
                    bft = String(html[bftRange1])
                    print("✅ [reCAPTCHA] BFT trovato (pattern 1): \(bft.prefix(40))…")
                }

                // Pattern 2: cerca nel JavaScript - var bft = "..."
                if bft.isEmpty {
                    let bftPattern2 = #"var\s+bft\s*=\s*["']([^"']+)["']"#
                    if let bftRegex2 = try? NSRegularExpression(pattern: bftPattern2, options: []),
                       let bftMatch2 = bftRegex2.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
                       let bftRange2 = Range(bftMatch2.range(at: 1), in: html) {
                        bft = String(html[bftRange2])
                        print("✅ [reCAPTCHA] BFT trovato (pattern 2): \(bft.prefix(40))…")
                    }
                }

                // Pattern 3: cerca window.recaptcha.bft o similari
                if bft.isEmpty {
                    let bftPattern3 = #"bft["\s:]+["']([^"']+)["']"#
                    if let bftRegex3 = try? NSRegularExpression(pattern: bftPattern3, options: []),
                       let bftMatch3 = bftRegex3.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
                       let bftRange3 = Range(bftMatch3.range(at: 1), in: html) {
                        bft = String(html[bftRange3])
                        print("✅ [reCAPTCHA] BFT trovato (pattern 3): \(bft.prefix(40))…")
                    }
                }

                if bft.isEmpty {
                    print("⚠️ [reCAPTCHA] BFT non trovato nell'HTML anchor - continuo senza")
                    print("📄 [reCAPTCHA] HTML snippet per debug: \(html.prefix(1000))")
                }

                print("✅ [reCAPTCHA] Anchor token trovato: \(token.prefix(40))…")
                let result = AnchorResult(token: token, bft: bft)
                completion(.success(result))
            }.resume()
        }

        /// Effettua la chiamata di reload per ottenere il token `_GRECAPTCHA...`.
        /// Riceve anchorToken, bft e li passa nel body come parametri.
        func recaptchaReload(config: RecaptchaConfig, anchorToken: String, bft: String, completion: @escaping (Result<String, ACIAuthError>) -> Void) {
            guard let url = config.reloadURL() else {
                completion(.failure(.invalidURL))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            request.setValue("https://www.google.com", forHTTPHeaderField: "Origin")
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

            // Costruisci il Referer con il bft se presente
            let refererURL: String
            if !bft.isEmpty {
                refererURL = "https://www.google.com/recaptcha/api2/bframe?hl=\(config.locale)&v=\(config.version)&k=\(config.siteKey)&bft=\(bft)"
            } else {
                refererURL = "https://www.google.com/recaptcha/api2/bframe?hl=\(config.locale)&v=\(config.version)&k=\(config.siteKey)"
            }
            request.setValue(refererURL, forHTTPHeaderField: "Referer")

            // Costruisci il body con tutti i parametri necessari
            var bodyParams = ["v": config.version, "k": config.siteKey, "c": anchorToken, "co": "aHR0cHM6Ly9ib2xsby5hY2kuaXQ6NDQz", "hl": config.locale, "size": config.size, "chr": "[]", "vh": "", "bg": ""]

            // Aggiungi il bft se presente
            if !bft.isEmpty {
                bodyParams["bft"] = bft
            }

            // Converti i parametri in stringa URL-encoded
            let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")

            print("🔍 [reCAPTCHA] Reload body: \(bodyString.prefix(200))…")
            request.httpBody = bodyString.data(using: .utf8)

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ [reCAPTCHA] Reload error: \(error.localizedDescription)")
                    completion(.failure(.networkError(error)))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    print("❌ [reCAPTCHA] Reload: risposta non HTTP")
                    completion(.failure(.invalidResponse))
                    return
                }

                print("📡 [reCAPTCHA] Reload status code: \(http.statusCode)")

                guard (200...299).contains(http.statusCode), let data = data else {
                    print("❌ [reCAPTCHA] Reload: status code \(http.statusCode) o nessun dato")
                    completion(.failure(.invalidResponse))
                    return
                }

                guard let body = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                    print("❌ [reCAPTCHA] Reload: impossibile decodificare la risposta")
                    completion(.failure(.invalidResponse))
                    return
                }

                print("📥 [reCAPTCHA] Reload response (primi 500): \(body.prefix(500))")

                // Prova diversi pattern per estrarre il token

                // Pattern 1: Cerca _GRECAPTCHA seguito da token alfanumerico
                if let range = body.range(of: "_GRECAPTCHA") {
                    let remainingString = String(body[range.lowerBound...])
                    // Estrai token fino al primo carattere non valido
                    let token = remainingString.split(whereSeparator: { $0 == "\"" || $0 == "\n" || $0 == "," || $0 == "]" || $0 == ")" }).first.map(String.init) ?? ""
                    if !token.isEmpty && token.count > 20 {
                        print("✅ [reCAPTCHA] Token estratto (pattern 1): \(token.prefix(50))…")
                        completion(.success(token))
                        return
                    }
                }

                // Pattern 2: Cerca ["rresp","TOKEN",...] formato array JSON
                let pattern2 = #"\["rresp","([^"]+)""#
                if let regex2 = try? NSRegularExpression(pattern: pattern2, options: []),
                   let match2 = regex2.firstMatch(in: body, options: [], range: NSRange(location: 0, length: body.utf16.count)),
                   let range2 = Range(match2.range(at: 1), in: body) {
                    let token = String(body[range2])
                    if !token.isEmpty && token.count > 20 {
                        print("✅ [reCAPTCHA] Token estratto (pattern 2): \(token.prefix(50))…")
                        completion(.success(token))
                        return
                    }
                }

                // Pattern 3: Cerca qualsiasi stringa lunga che assomiglia a un token
                let pattern3 = #"[A-Za-z0-9_-]{50,}"#
                if let regex3 = try? NSRegularExpression(pattern: pattern3, options: []),
                   let match3 = regex3.firstMatch(in: body, options: [], range: NSRange(location: 0, length: body.utf16.count)),
                   let range3 = Range(match3.range, in: body) {
                    let token = String(body[range3])
                    print("✅ [reCAPTCHA] Token estratto (pattern 3): \(token.prefix(50))…")
                    completion(.success(token))
                    return
                }

                print("⚠️ [reCAPTCHA] Body reload ricevuto ma token non trovato con nessun pattern")
                print("📄 [reCAPTCHA] Body completo: \(body)")
                completion(.failure(.invalidResponse))
            }.resume()
        }

        /// Esegue anchor → reload e ritorna il token reCAPTCHA.
        /// Chiama recaptchaAnchor per ottenere anchorToken e bft, poi li passa a recaptchaReload.
        func getRecaptchaToken(
            siteKey: String = "6LcFLzYUAAAAAJ8GvWPHV3lJukQAOAP52rMQ6g67",
            completion: @escaping (Result<String, ACIAuthError>) -> Void
        ) {
            print("🎯 [reCAPTCHA] Inizio processo reCAPTCHA: anchor → reload")
            let config = RecaptchaConfig(siteKey: siteKey)

            recaptchaAnchor(config: config) { anchorResult in
                switch anchorResult {
                case .failure(let err):
                    print("❌ [reCAPTCHA] Errore anchor: \(err.localizedDescription)")
                    completion(.failure(err))
                case .success(let result):
                    print("✅ [reCAPTCHA] Anchor completato - token: \(result.token.prefix(30))…, bft: \(result.bft.isEmpty ? "N/A" : result.bft.prefix(30) + "…")")
                    recaptchaReload(config: config, anchorToken: result.token, bft: result.bft, completion: completion)
                }
            }
        }
        

        getRecaptchaToken { result in
            switch result {
            case .failure(let err):
                print("❌ [ACISPIDAuth] Errore token reCAPTCHA: \(err.localizedDescription)")
                completion(.failure(err))
            case .success(let token):
                print("🎫 [ACISPIDAuth] Token reCAPTCHA ottenuto: \(token.prefix(40))…")

                var request = URLRequest(url: self.vehicleEndpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                if let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"] {
                    request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
                    print("🍪 [ACISPIDAuth] Cookie header impostato: \(cookieHeader.prefix(100))…")
                }

                // Inserisci il token nel body JSON
                let body: [String: Any] = [
                    "g-recaptcha-response": token
                    // aggiungi altri parametri se necessari (es. "targa", "cf", ecc.)
                ]
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)

                print("🚗 [ACISPIDAuth] Richiesta vehicle -> \(self.vehicleEndpoint.absoluteString)")

                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        print("❌ [ACISPIDAuth] Errore rete vehicle: \(error.localizedDescription)")
                        completion(.failure(.networkError(error)))
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("❌ [ACISPIDAuth] Risposta non HTTP valida")
                        completion(.failure(.invalidResponse))
                        return
                    }

                    print("📡 [ACISPIDAuth] HTTP Status Code: \(httpResponse.statusCode)")

                    guard (200...299).contains(httpResponse.statusCode) else {
                        print("❌ [ACISPIDAuth] HTTP \(httpResponse.statusCode) da vehicle")
                        completion(.failure(.httpError(httpResponse.statusCode)))
                        return
                    }

                    guard let data = data else {
                        print("❌ [ACISPIDAuth] Nessun dato nella risposta")
                        completion(.failure(.invalidResponse))
                        return
                    }

                    if let preview = String(data: data, encoding: .utf8) {
                        print("📥 [ACISPIDAuth] vehicle payload: \(preview.prefix(300))…")
                    }

                    do {
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(BolloAPIResponse.self, from: data)
                        completion(.success(response))
                    } catch {
                        print("❌ [ACISPIDAuth] Decoding vehicle fallito: \(error.localizedDescription)")
                        completion(.failure(.decodingError))
                    }
                }.resume()
            }
        }
    }

    /// Gestisce gli errori durante l'autenticazione
    func handleAuthenticationFailure(error: ACIAuthError) {
        print("❌ [ACISPIDAuth] Errore durante l'autenticazione: \(error.localizedDescription)")
        authError = error
        isAuthenticating = false
    }

    /// Reset dello stato di autenticazione
    func reset() {
        isAuthenticating = false
        authError = nil
        authCookies = []
        vehicleResponse = nil

        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {
                print("🧹 [ACISPIDAuth] Cookie puliti")
                // 🔄 Nota: non chiudiamo la WebView, l'utente può continuare a navigare sulla pagina
                print("ℹ️ [ACISPIDAuth] La WebView rimane aperta per consentire la navigazione")
            }
        }
    }

    /// Verifica se l'utente è autenticato controllando la presenza di dati vehicle o cookie
    func isAuthenticated() -> Bool {
        return vehicleResponse != nil || !authCookies.isEmpty
    }

    /// Ottiene i cookie per una chiamata API
    func getAuthCookies() -> [HTTPCookie] {
        return authCookies
    }

    /// Recupera i dati di bollo per una targa dal payload vehicle ottenuto in autenticazione
    func bolloData(for plate: String) -> BolloData? {
        guard let response = vehicleResponse else { return nil }
        return ACISPIDAuthService.extractBolloData(from: response, for: plate)
    }

    static func extractBolloData(from response: BolloAPIResponse, for plate: String) -> BolloData? {
        guard let veicoli = response.veicoli else { return nil }

        guard let veicolo = veicoli.first(where: { $0.targa.uppercased() == plate.uppercased() }),
              let bolloInfo = veicolo.bollo else {
            return nil
        }

        return BolloData(from: bolloInfo, storico: veicolo.storicoPagamenti ?? [])
    }
}

// MARK: - Errors

enum ACIAuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case networkError(Error)
    case authenticationCancelled
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL non valido per l'autenticazione ACI"
        case .invalidResponse:
            return "Risposta non valida dal server ACI"
        case .httpError(let code):
            return "Errore HTTP \(code) durante l'autenticazione"
        case .decodingError:
            return "Impossibile decodificare la risposta del server"
        case .networkError(let error):
            return "Errore di rete: \(error.localizedDescription)"
        case .authenticationCancelled:
            return "Autenticazione annullata dall'utente"
        case .authenticationFailed:
            return "Autenticazione fallita"
        }
    }
}
