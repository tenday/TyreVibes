import SwiftUI
import Combine
import Security
import AuthenticationServices
import LocalAuthentication

enum LoginFormFocus {
    case email
    case password
}

@MainActor
class LoginViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var email = ""
    @Published var password = ""
    @Published var rememberMe = false
    
    @Published var isLoading = false
    @Published var alertItem: AlertItem?
    @Published var formFocus: LoginFormFocus?

    @AppStorage("useFaceID") var useFaceID: Bool = false

    // MARK: - Dependencies
    private let authService: AuthService
    private let sessionManager: SessionManager
    private let userProfileService: UserProfileService

    // MARK: - Initializer
    init(
        authService: AuthService = AuthService(),
        sessionManager: SessionManager,
        userProfileService: UserProfileService = UserProfileService()
    ) {
        self.authService = authService
        self.sessionManager = sessionManager
        self.userProfileService = userProfileService
        super.init()
    }
    
    var isLoginButtonEnabled: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
    }

    // MARK: - Email/Password Sign In
    func signIn() {
        formFocus = nil
        guard isLoginButtonEnabled else { return }

        isLoading = true
        Task {
            do {
                try await authService.signIn(email: email, password: password)
                _ = try await userProfileService.fetchAndCacheUserProfile()

                if rememberMe {
                    try KeychainHelper.save(email: email, password: password)
                } else {
                    KeychainHelper.delete()
                }
                UserDefaults.standard.set(rememberMe, forKey: "rememberMe")

                sessionManager.isLoggedIn = true
            } catch {
                let alert = ErrorMapper.mapErrorToAlert(error, fallbackTitle: "Login fallito")
                self.alertItem = AlertItem(title: alert.title, message: alert.message)
            }
            self.isLoading = false
        }
    }

    // MARK: - Sign In with Apple
    func signInWithApple(presentationAnchor: ASPresentationAnchor) {
        isLoading = true
        Task {
            do {
                try await authService.signInWithApple(presentationAnchor: presentationAnchor)
                _ = try await userProfileService.fetchAndCacheUserProfile()
                sessionManager.isLoggedIn = true
            } catch {
                let alert = ErrorMapper.mapErrorToAlert(error, fallbackTitle: "Login Apple fallito")
                self.alertItem = AlertItem(title: alert.title, message: alert.message)
            }
            self.isLoading = false
        }
    }

    // MARK: - Sign In with Google
    func signInWithGoogle() {
        isLoading = true
        Task {
            do {
                try await authService.signInWithGoogle()
                _ = try await userProfileService.fetchAndCacheUserProfile()
                sessionManager.isLoggedIn = true
            } catch {
                let alert = ErrorMapper.mapErrorToAlert(error, fallbackTitle: "Login Google fallito")
                self.alertItem = AlertItem(title: alert.title, message: alert.message)
            }
            self.isLoading = false
        }
    }
    
    // MARK: - Auto Login / Face ID
    public func attemptAutoLogin() {
        self.rememberMe = UserDefaults.standard.bool(forKey: "rememberMe")
        self.useFaceID = UserDefaults.standard.bool(forKey: "useFaceID")

        if rememberMe, let credentials = KeychainHelper.load() {
            self.email = credentials.email
            self.password = credentials.password
            self.rememberMe = true
            if useFaceID {
                authenticateWithFaceIDAndLogin()
            } else {
                signIn()
            }
        }
    }
    
    private func authenticateWithFaceIDAndLogin() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Accedi con Face ID"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                Task { @MainActor in
                    if success {
                        UserDefaults.standard.set(true, forKey: "useFaceID")
                        self.signIn()
                    }
                }
            }
        } else {
            // Face ID not available, proceed with normal sign-in
            Task { @MainActor in
                self.signIn()
            }
        }
    }
}

// Dummy AlertItem for compilation. Assume it's defined elsewhere.
struct AlertItem: Identifiable {
    var id = UUID()
    var title: String
    var message: String
}

// Dummy KeychainHelper for compilation. Assume it's defined elsewhere.
struct KeychainHelper {
    static func save(email: String, password: String) throws {}
    static func load() -> (email: String, password: String)? { return nil }
    static func delete() {}
}