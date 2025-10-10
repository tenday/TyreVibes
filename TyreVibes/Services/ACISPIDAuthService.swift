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
        var components = URLComponents(string: "https://login.aci.it/index.php/")
        components?.queryItems = [
            URLQueryItem(name: "do", value: "loginSpidMobile"),
            URLQueryItem(name: "application_key", value: "bollonet"),
            URLQueryItem(name: "purl", value: vehicleEndpoint.absoluteString)
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
            authError = error
            completion(.failure(error))
            return
        }

        isAuthenticating = true
        authError = nil

        // Pulisci i cookie se richiesto
        if clearCookies {
            print("🧹 [ACISPIDAuth] Pulizia cookie prima dell'autenticazione...")
            let dataStore = WKWebsiteDataStore.default()
            dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {
                    print("✅ [ACISPIDAuth] Cookie puliti, avvio autenticazione")
                    completion(.success(url))
                }
            }
        } else {
            completion(.success(url))
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
            completion(.failure(.authenticationFailed))
            return
        }

        var request = URLRequest(url: vehicleEndpoint)
        request.httpMethod = "GET"

        if let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"] {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }

        print("🚗 [ACISPIDAuth] Richiesta vehicle -> \(vehicleEndpoint.absoluteString)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [ACISPIDAuth] Errore rete vehicle: \(error.localizedDescription)")
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [ACISPIDAuth] HTTP \(httpResponse.statusCode) da vehicle")
                completion(.failure(.httpError(httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            if let preview = String(data: data, encoding: .utf8) {
                print("📥 [ACISPIDAuth] vehicle payload: \(preview.prefix(200))…")
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
