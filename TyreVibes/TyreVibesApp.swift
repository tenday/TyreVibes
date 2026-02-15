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
    @StateObject private var networkMonitor = NetworkMonitor.shared
    private let authService = AuthService()
    @State private var showResetPasswordScreen = false
    @State private var passwordRecoveryAlertItem: AlertItem?
    @State private var authStateChangeTask: Any? = nil

    init() {
        MaintenanceDataMigration.migrateIfNeeded()
    }

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
            .overlay(alignment: .top) {
                NetworkStatusBanner(isVisible: !networkMonitor.isReachable)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: networkMonitor.isReachable)
            }
            
            .sheet(isPresented: $showResetPasswordScreen) {
                ResetPasswordScreen()
            }
            .onOpenURL { url in
                if GIDSignIn.sharedInstance.handle(url) {
                    return
                }
                if isPasswordResetURL(url) {
                    if let alertItem = recoveryAlertItem(from: url) {
                        passwordRecoveryAlertItem = alertItem
                        return
                    }
                    Task {
                        do {
                            try await authService.handlePasswordRecovery(url: url)
                            await MainActor.run {
                                showResetPasswordScreen = true
                            }
                        } catch {
                            await MainActor.run {
                                passwordRecoveryAlertItem = recoveryAlertItem(from: error)
                            }
                        }
                    }
                    return
                }

                if isSupabaseAuthURL(url) {
                    SupabaseManager.client.auth.handle(url)
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
            .confirmationDialog("Cosa vuoi fare?", isPresented: $bugReportManager.showFeedbackOptions, titleVisibility: .visible) {
                Button("Segnala un Bug") {
                    bugReportManager.selectReportType(.bug)
                }
                Button("Invia Feedback") {
                    bugReportManager.selectReportType(.feedback)
                }
                Button("Annulla", role: .cancel) { }
            }
            .alert(item: $passwordRecoveryAlertItem) { alertItem in
                Alert(title: Text(alertItem.title), message: Text(alertItem.message), dismissButton: .default(Text("OK")))
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

        case "warranty_expiry":
            // Naviga alla sezione garanzie
            print("📍 Naviga alle garanzie")

        case "oil_change", "filter_reminder", "brake_reminder", "battery_reminder", "general_maintenance":
            // Naviga alla sezione manutenzione del veicolo
            if let vehicleId = userInfo["vehicle_id"] as? String {
                print("📍 Naviga alla manutenzione veicolo: \(vehicleId)")
            }

        default:
            // Naviga alla schermata notifiche
            print("📍 Naviga alla schermata notifiche")
        }
    }

    private func isPasswordResetURL(_ url: URL) -> Bool {
        if url.scheme == "it.tyrevibes.app" {
            return url.host == "reset-password"
        }

        if url.scheme == "https" {
            guard let host = url.host else { return false }
            guard host == "tyrevibes.com" || host == "www.tyrevibes.com" else { return false }
            return url.path == "/reset_password" || url.path == "/reset_password/"
        }

        return false
    }

    private func isSupabaseAuthURL(_ url: URL) -> Bool {
        if url.scheme == "it.tyrevibes.app" {
            return true
        }

        if url.scheme == "https" {
            guard let host = url.host else { return false }
            return host == "tyrevibes.com" || host == "www.tyrevibes.com"
        }

        return false
    }

    private func recoveryAlertItem(from url: URL) -> AlertItem? {
        let params = urlParameters(from: url)
        let errorCode = params["error_code"]?.lowercased()
        let error = params["error"]?.lowercased()
        let errorDescription = params["error_description"]?.replacingOccurrences(of: "+", with: " ")

        if errorCode == "otp_expired" || errorCode == "flow_state_expired" || errorCode == "session_expired" {
            return AlertItem(
                title: "Link scaduto",
                message: "Il link di recupero è scaduto. Richiedi un nuovo link per reimpostare la password."
            )
        }

        if error == "access_denied" || errorCode == "access_denied" {
            return AlertItem(
                title: "Link non valido",
                message: "Non è stato possibile aprire il link di reset. Richiedi un nuovo link."
            )
        }

        if let description = errorDescription, !description.isEmpty {
            return AlertItem(title: "Link non valido", message: description)
        }

        return nil
    }

    private func recoveryAlertItem(from error: Error) -> AlertItem {
        if let authError = error as? AuthError {
            switch authError {
            case .api(_, let errorCode, _, _):
                if errorCode == .otpExpired || errorCode == .flowStateExpired || errorCode == .sessionExpired {
                    return AlertItem(
                        title: "Link scaduto",
                        message: "Il link di recupero è scaduto. Richiedi un nuovo link per reimpostare la password."
                    )
                }
                if errorCode == .overEmailSendRateLimit || errorCode == .overRequestRateLimit {
                    return AlertItem(
                        title: "Troppi tentativi",
                        message: "Hai richiesto troppi link in poco tempo. Attendi qualche minuto e riprova."
                    )
                }
            case .implicitGrantRedirect(let message):
                return AlertItem(title: "Link non valido", message: message)
            default:
                break
            }
        }

        let message = error.localizedDescription.isEmpty
        ? "Non è stato possibile aprire il link di reset. Richiedi un nuovo link."
        : error.localizedDescription
        return AlertItem(title: "Errore", message: message)
    }

    private func urlParameters(from url: URL) -> [String: String] {
        var params: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems?.forEach { item in
                if let value = item.value {
                    params[item.name] = value
                }
            }
        }

        if let fragment = url.fragment,
           let fragmentComponents = URLComponents(string: "?\(fragment)") {
            fragmentComponents.queryItems?.forEach { item in
                if let value = item.value {
                    params[item.name] = value
                }
            }
        }

        return params
    }
}
