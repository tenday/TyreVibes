//
//  PushNotificationManager.swift
//  TyreVibes
//
//  Created by Claude on 09/11/25.
//

import Foundation
import UserNotifications
import UIKit

/// Gestisce le notifiche push APNs (Apple Push Notification service)
@MainActor
class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published var deviceToken: String?
    @Published var isRegisteredForRemoteNotifications = false
    @Published var lastError: Error?

    private override init() {
        super.init()
    }

    // MARK: - Registration

    /// Registra l'app per ricevere notifiche remote (push)
    func registerForPushNotifications() async throws {
        // Prima richiedi i permessi per le notifiche locali
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions)

        guard granted else {
            throw PushNotificationError.permissionDenied
        }

        // Registra per le notifiche remote (questo genera il device token)
        UIApplication.shared.registerForRemoteNotifications()
        isRegisteredForRemoteNotifications = true
    }

    /// Chiamato quando il device token viene generato con successo
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        // Converti il device token in stringa esadecimale
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        print("📱 APNs Device Token: \(tokenString)")
        self.deviceToken = tokenString

        // Invia il token al backend Supabase
        Task {
            await sendDeviceTokenToBackend(token: tokenString)
        }
    }

    /// Chiamato quando la registrazione fallisce
    func didFailToRegisterForRemoteNotifications(with error: Error) {
        print("❌ Errore registrazione push notifications: \(error.localizedDescription)")
        self.lastError = error
        self.isRegisteredForRemoteNotifications = false
    }

    // MARK: - Backend Communication

    /// Invia il device token al backend Supabase per salvarlo nel database
    private func sendDeviceTokenToBackend(token: String) async {
        do {
            // Ottieni il JWT token e userId per autenticare la chiamata
            guard let session = try? await SupabaseManager.client.auth.session else {
                print("⚠️ Sessione non valida, impossibile salvare device token")
                return
            }

            let jwtToken = session.accessToken
            let userId = session.user.id.uuidString

            // Crea il payload
            let payload: [String: Any] = [
                "user_id": userId,
                "device_token": token,
                "platform": "ios",
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                "device_model": UIDevice.current.model,
                "os_version": UIDevice.current.systemVersion
            ]

            // Invia al backend
            try await NotificationAPIService.shared.registerDeviceToken(payload: payload, jwtToken: jwtToken)

            print("✅ Device token registrato con successo sul backend")

        } catch {
            print("❌ Errore invio device token al backend: \(error.localizedDescription)")
            self.lastError = error
        }
    }

    // MARK: - Handle Push Notifications

    /// Gestisce una notifica push ricevuta
    func handleRemoteNotification(userInfo: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📬 Notifica push ricevuta: \(userInfo)")

        // Estrai i dati dalla notifica
        guard let aps = userInfo["aps"] as? [String: Any] else {
            completionHandler(.noData)
            return
        }

        // Gestisci il badge
        if let badge = aps["badge"] as? Int {
            UNUserNotificationCenter.current().setBadgeCount(badge)
        }

        // Estrai dati custom
        let notificationType = userInfo["type"] as? String ?? "custom"
        let vehicleId = userInfo["vehicle_id"] as? String
        let tyreId = userInfo["tyre_id"] as? String
        let actionRequired = userInfo["action_required"] as? Bool ?? false

        // Crea una notifica in-app
        Task { @MainActor in
            // Converti il tipo stringa in AppNotification.NotificationType
            let notifType = convertToAppNotificationType(notificationType)

            let notification = AppNotification(
                id: UUID().uuidString,
                type: notifType,
                title: aps["alert"] as? String ?? (aps["alert"] as? [String: String])?["title"] ?? "Notifica",
                message: (aps["alert"] as? [String: String])?["body"] ?? "",
                timestamp: Date(),
                isRead: false,
                vehicleId: vehicleId,
                tyreId: tyreId,
                priority: .medium,
                actionRequired: actionRequired,
                scheduledDate: nil,
                predictedDate: nil,
                metadata: nil
            )

            // Aggiungi alla NotificationStore
            NotificationStore.shared.addNotification(notification)

            completionHandler(.newData)
        }
    }

    /// Gestisce il tap su una notifica push
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo

        print("👆 Utente ha tappato la notifica: \(userInfo)")

        // Estrai info per navigazione
        let notificationType = userInfo["type"] as? String
        let vehicleId = userInfo["vehicle_id"] as? String
        let tyreId = userInfo["tyre_id"] as? String

        // Invia notification per deep linking
        NotificationCenter.default.post(
            name: .pushNotificationTapped,
            object: nil,
            userInfo: [
                "type": notificationType ?? "unknown",
                "vehicle_id": vehicleId ?? "",
                "tyre_id": tyreId ?? ""
            ]
        )
    }

    // MARK: - Utility

    /// Converte il tipo di notifica stringa in AppNotification.NotificationType
    private func convertToAppNotificationType(_ typeString: String) -> AppNotification.NotificationType {
        switch typeString {
        case "tyre_inspection", "inspection":
            return .inspection
        case "tyre_replacement":
            return .tyreReplacement
        case "pressure_check":
            return .pressureAlert
        case "tyre_rotation", "rotation":
            return .rotation
        case "wheel_alignment", "alignment":
            return .alignment
        case "seasonal_change":
            return .seasonalReminder
        case "warranty_expiry", "warranty":
            return .warranty
        default:
            return .maintenanceReminder
        }
    }

    /// Deregistra dalle notifiche push (es. al logout)
    func unregisterForPushNotifications() async {
        guard let token = deviceToken else { return }

        do {
            // Rimuovi il token dal backend
            guard let session = try? await SupabaseManager.client.auth.session else {
                print("⚠️ Sessione non valida")
                return
            }

            try await NotificationAPIService.shared.unregisterDeviceToken(token: token, jwtToken: session.accessToken)

            // Deregistra localmente
            UIApplication.shared.unregisterForRemoteNotifications()

            deviceToken = nil
            isRegisteredForRemoteNotifications = false

            print("✅ Device token deregistrato con successo")

        } catch {
            print("❌ Errore deregistrazione device token: \(error.localizedDescription)")
        }
    }
}

// MARK: - Errors

enum PushNotificationError: LocalizedError {
    case permissionDenied
    case tokenNotAvailable
    case backendError(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permesso per le notifiche negato"
        case .tokenNotAvailable:
            return "Device token non disponibile"
        case .backendError(let message):
            return "Errore backend: \(message)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
}
