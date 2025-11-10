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
        guard let path = Bundle.main.path(forResource: "Api", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let urlString = plist["SUPABASE_URL"] as? String,
              let key = plist["SUPABASE_KEY"] as? String else {
            fatalError("Api.plist non trovato o le chiavi non sono configurate")
        }

        self.baseURL = urlString
        self.supabaseKey = key
    }

    // MARK: - Device Token Management

    /// Registra il device token sul backend Supabase
    /// - Parameters:
    ///   - payload: Dizionario contenente user_id, device_token, platform, etc.
    ///   - jwtToken: JWT token di autenticazione Supabase
    func registerDeviceToken(payload: [String: Any], jwtToken: String) async throws {
        let endpoint = "\(baseURL)/rest/v1/device_tokens"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        // Converti payload in JSON
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
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
        let endpoint = "\(baseURL)/rest/v1/device_tokens?device_token=eq.\(token)"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let (_, response) = try await URLSession.shared.data(for: request)

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
        let endpoint = "\(baseURL)/rest/v1/notifications?user_id=eq.\(userId)&order=timestamp.desc&limit=\(limit)"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)

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
        let endpoint = "\(baseURL)/rest/v1/notifications?id=eq.\(notificationId)"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let payload = ["is_read": true]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        request.httpBody = jsonData

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to mark as read")
        }
    }

    /// Elimina una notifica dal backend
    func deleteNotification(notificationId: String, jwtToken: String) async throws {
        let endpoint = "\(baseURL)/rest/v1/notifications?id=eq.\(notificationId)"

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")

        let (_, response) = try await URLSession.shared.data(for: request)

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

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Risposta del server non valida"
        case .serverError(let code, let message):
            return "Errore server (\(code)): \(message)"
        case .decodingError(let error):
            return "Errore decodifica: \(error.localizedDescription)"
        }
    }
}
