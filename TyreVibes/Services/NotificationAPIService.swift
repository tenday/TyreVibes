//
//  NotificationAPIService.swift
//  TyreVibes
//
//  Created by Claude on 09/11/25.
//

import Foundation

/// Service per gestire le chiamate API relative alle notifiche push con backend Supabase
class NotificationAPIService {
    static let shared = NotificationAPIService()

    private let baseURL: String
    private let supabaseKey: String

    private init() {
        // Ottieni l'URL e la key dal plist
        if let path = Bundle.main.path(forResource: "Api", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let urlString = plist["SUPABASE_URL"] as? String,
           let key = plist["SUPABASE_KEY"] as? String {
            self.baseURL = urlString
            self.supabaseKey = key
        } else {
            print("⚠️ [NotificationAPIService] Api.plist non trovato o chiavi mancanti. Il servizio non funzionerà.")
            self.baseURL = ""
            self.supabaseKey = ""
        }
    }

    // MARK: - Device Token Management

    /// Registra il device token sul backend Supabase
    /// - Parameters:
    ///   - payload: Dizionario contenente user_id, device_token, platform, etc.
    ///   - jwtToken: JWT token di autenticazione Supabase
    func registerDeviceToken(payload: [String: Any], jwtToken: String) async throws {
        guard !baseURL.isEmpty, !supabaseKey.isEmpty else {
            throw APIError.configurationError
        }
        
        // Usa upsert per evitare errori 409 (duplicate key) se il token esiste già
        let endpoint = "\(baseURL)/rest/v1/device_tokens?on_conflict=device_token"

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        // Converti payload in JSON
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        request.httpBody = jsonData

        let (data, response) = try await URLSession.tyreVibesShared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 409 {
            // Se il token esiste già consideriamo l'operazione riuscita
            print("ℹ️ Device token già registrato sul backend, nessuna azione necessaria")
            return
        }

        // Supabase restituisce 201 per creazione o 200 per upsert
        guard (200...201).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        print("✅ Device token registrato: \(String(data: data, encoding: .utf8) ?? "")")
    }

    /// Deregistra il device token dal backend
    func unregisterDeviceToken(token: String, jwtToken: String) async throws {
        guard !baseURL.isEmpty, !supabaseKey.isEmpty else {
            throw APIError.configurationError
        }
        
        let endpoint = "\(baseURL)/rest/v1/device_tokens?device_token=eq.\(token)"

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let (_, response) = try await URLSession.tyreVibesShared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...204).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to delete token")
        }

        print("✅ Device token deregistrato con successo")
    }

    // MARK: - Fetch Remote Notifications

    /// Recupera le notifiche dal server per l'utente corrente
    func fetchNotifications(userId: String, jwtToken: String, limit: Int = 50) async throws -> [AppNotification] {
        guard !baseURL.isEmpty, !supabaseKey.isEmpty else {
            throw APIError.configurationError
        }
        
        let endpoint = "\(baseURL)/rest/v1/notifications?user_id=eq.\(userId)&order=timestamp.desc&limit=\(limit)"

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.tyreVibesShared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Decodifica le notifiche
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let notifications = try decoder.decode([AppNotification].self, from: data)
        return notifications
    }

    /// Segna una notifica come letta sul backend
    func markNotificationAsRead(notificationId: String, jwtToken: String) async throws {
        guard !baseURL.isEmpty, !supabaseKey.isEmpty else {
            throw APIError.configurationError
        }
        
        let endpoint = "\(baseURL)/rest/v1/notifications?id=eq.\(notificationId)"

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let payload = ["is_read": true]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        request.httpBody = jsonData

        let (_, response) = try await URLSession.tyreVibesShared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to mark as read")
        }
    }

    /// Elimina una notifica dal backend
    func deleteNotification(notificationId: String, jwtToken: String) async throws {
        guard !baseURL.isEmpty, !supabaseKey.isEmpty else {
            throw APIError.configurationError
        }
        
        let endpoint = "\(baseURL)/rest/v1/notifications?id=eq.\(notificationId)"

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let (_, response) = try await URLSession.tyreVibesShared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...204).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to delete notification")
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case configurationError
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Risposta del server non valida"
        case .serverError(let code, let message):
            return "Errore server (\(code)): \(message)"
        case .decodingError(let error):
            return "Errore decodifica: \(error.localizedDescription)"
        case .configurationError:
            return "Configurazione mancante (Api.plist)"
        case .invalidURL:
            return "URL non valida"
        }
    }
}
