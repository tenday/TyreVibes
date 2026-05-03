//
//  AppDelegate.swift
//  TyreVibes
//
//  Created by Claude on 09/11/25.
//

import UIKit
import UserNotifications

/// AppDelegate per gestire eventi lifecycle dell'app e notifiche push
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Imposta il delegate per le notifiche
        UNUserNotificationCenter.current().delegate = self

        // Registra per le notifiche push se l'utente è già loggato
        Task { @MainActor in
            // Controlla se l'utente è autenticato
            if let _ = try? await SupabaseManager.client.auth.session {
                try? await PushNotificationManager.shared.registerForPushNotifications()
            }
        }

        return true
    }

    // MARK: - Remote Notifications

    /// Chiamato quando il device token APNs viene generato con successo
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
        }
    }

    /// Chiamato quando la registrazione per le notifiche remote fallisce
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(with: error)
        }
    }

    /// Chiamato quando una notifica push viene ricevuta mentre l'app è in background
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.handleRemoteNotification(
                userInfo: userInfo,
                completionHandler: completionHandler
            )
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Chiamato quando una notifica arriva mentre l'app è in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Mostra la notifica anche se l'app è aperta
        completionHandler([.banner, .sound, .badge])
    }

    /// Chiamato quando l'utente interagisce con una notifica (tap)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            let userInfo = response.notification.request.content.userInfo

            if userInfo["notificationGroup"] as? String == "maintenance" {
                NotificationScheduler.shared.handleMaintenanceNotificationResponse(
                    actionIdentifier: response.actionIdentifier,
                    userInfo: userInfo
                )
            } else {
                // Gestisci il tap sulla notifica
                PushNotificationManager.shared.handleNotificationResponse(response)
            }

            completionHandler()
        }
    }
}
