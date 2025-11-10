//
//  TyreVibesApp.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 11/05/25.
//

import SwiftUI
import GoogleSignIn
import Supabase

@main
struct TyreVibesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var notificationStore = NotificationStore()
    @StateObject private var bugReportManager = BugReportManager()
    @StateObject private var pushNotificationManager = PushNotificationManager.shared
    @State private var showResetPasswordScreen = false
    @State private var authStateChangeTask: Any? = nil
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoggedIn {
                    BottomNavigationView()
                } else {
                    LoginScreen()
                }
                SplashScreen()
            }
            
            .sheet(isPresented: $showResetPasswordScreen) {
                ResetPasswordScreen()
            }
            .onOpenURL { url in
                if GIDSignIn.sharedInstance.handle(url) {
                    return
                }
                if url.scheme == "it.tyrevibes.app" && url.host == "reset-password" {
                    showResetPasswordScreen = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didRequestLogout)) { _ in
                isLoggedIn = false
                // Deregistra dalle push notifications al logout
                Task {
                    await pushNotificationManager.unregisterForPushNotifications()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .pushNotificationTapped)) { notification in
                // Gestisci deep linking dalle push notifications
                if let userInfo = notification.userInfo,
                   let type = userInfo["type"] as? String {
                    handlePushNotificationDeepLink(type: type, userInfo: userInfo)
                }
            }
            .environment(\.locale, languageManager.locale)
            .environmentObject(languageManager)
            .environmentObject(notificationStore)
            .environmentObject(bugReportManager)
            .sheet(isPresented: $bugReportManager.showBugReportSheet) {
                BugReportSheet(manager: bugReportManager)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .scrollIndicators(.hidden)
            }
            .onAppear {
                Task { @MainActor in
                    let token = await SupabaseManager.client.auth.onAuthStateChange { event, session in
                        if case .passwordRecovery = event {
                            showResetPasswordScreen = true
                        }
                    }
                    authStateChangeTask = token as Any
                }
            }
            .onDisappear {
                if let cancellable = authStateChangeTask as? AnyObject, cancellable.responds(to: Selector(("cancel"))) {
                    _ = cancellable.perform(Selector(("cancel")))
                }
                authStateChangeTask = nil
            }
        }
    }

    // MARK: - Deep Link Handling

    /// Gestisce la navigazione quando l'utente tappa su una push notification
    private func handlePushNotificationDeepLink(type: String, userInfo: [AnyHashable: Any]) {
        print("🔗 Deep link da push notification: \(type)")

        // Esempi di navigazione basata sul tipo di notifica
        switch type {
        case "tyre_inspection", "tyre_replacement", "pressure_check":
            // Naviga alla schermata dei veicoli/pneumatici
            if let vehicleId = userInfo["vehicle_id"] as? String {
                print("📍 Naviga al veicolo: \(vehicleId)")
                // TODO: Implementare navigazione specifica
            }

        case "seasonal_change":
            // Naviga alla sezione cambio stagionale
            print("📍 Naviga al cambio stagionale")
            // TODO: Implementare navigazione

        case "warranty_expiry":
            // Naviga alla sezione garanzie
            print("📍 Naviga alle garanzie")
            // TODO: Implementare navigazione

        default:
            // Naviga alla schermata notifiche
            print("📍 Naviga alla schermata notifiche")
            // TODO: Implementare navigazione
        }
    }
}

