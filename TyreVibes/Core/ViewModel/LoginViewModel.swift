import SwiftUI
import Combine
import Security
import AuthenticationServices
import LocalAuthentication
import Supabase

enum LoginFormFocus {
    case email
    case password
}

@MainActor
class LoginViewModel: NSObject, ObservableObject { // 2. Eredita da NSObject
    // MARK: - Published Properties
    @Published var email = ""
    @Published var password = ""
    @Published var rememberMe = false
    
    @Published var isLoading = false
    @Published var alertItem: AlertItem?
    @Published var showHomeScreen = false

    @Published var formFocus: LoginFormFocus?

    @AppStorage("useFaceID") var useFaceID: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false

    private let authService = AuthService()

    
    var isLoginButtonEnabled: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
    }

    // MARK: - Error Handling Helpers
    private func mapErrorToAlert(_ error: Error, fallbackTitle: String) -> (title: String, message: String) {
        if let authError = error as? AuthServiceError {
            switch authError {
            case .invalidMail(let reason):
                return ("Email non valida", reason)
            case .noUserFound:
                return ("Credenziali errate", "L'email o la password inserita non sono corrette. Riprova.")
            case .otpInvalid:
                return ("Codice OTP errato", "Il codice inserito non è corretto. Verifica e riprova.")
            case .otpExpired:
                return ("Codice OTP scaduto", "Il codice OTP è scaduto. Richiedine uno nuovo.")
            case .profileCreationFailed(let reason):
                return ("Errore creazione profilo", reason)
            case .signUpFailed(let reason):
                return ("Accesso fallito", reason.isEmpty ? "Si è verificato un errore durante l'accesso. Riprova." : reason)
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return ("Timeout", "La richiesta ha impiegato troppo tempo. Controlla la connessione e riprova.")
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return ("Errore di comunicazione", "Connessione assente o instabile. Verifica la rete e riprova.")
            default:
                break
            }
        }

        let nsErr = error as NSError
        if nsErr.domain == NSURLErrorDomain, nsErr.code == NSURLErrorTimedOut {
            return ("Timeout", "La richiesta ha impiegato troppo tempo. Controlla la connessione e riprova.")
        }

        if error is DecodingError {
            return ("Errore dati", "Risposta non valida dal server. Riprova più tardi.")
        }

        let message = error.localizedDescription.isEmpty ? "Si è verificato un errore imprevisto. Riprova." : error.localizedDescription
        return (fallbackTitle, message)
    }
    
    // MARK: - Email/Password Sign In
    
    func signIn() {
        formFocus = nil

        guard isLoginButtonEnabled else { return }

        isLoading = true
        Task {
            do {
                try await authService.signIn(email: email, password: password)

                // Fetch and cache user profile immediately after login
                await fetchAndCacheUserProfile()

                if rememberMe {
                    try KeychainHelper.save(email: email, password: password)
                } else {
                    KeychainHelper.delete()
                }

                UserDefaults.standard.set(rememberMe, forKey: "rememberMe")

                isLoggedIn = true
                showHomeScreen = true
            } catch {
                let alert = mapErrorToAlert(error, fallbackTitle: "Login fallito")
                self.alertItem = AlertItem(title: alert.title, message: alert.message)
            }
            self.isLoading = false
        }
    }
    
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
            if !useFaceID {
                Task { @MainActor in
                    self.signIn()
                }
                return
            }
            let reason = "Accedi con Face ID"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                if success {
                    UserDefaults.standard.set(true, forKey: "useFaceID")
                    Task { @MainActor in
                        self.signIn()
                    }
                }
            }
        } else {
            // Face ID non disponibile → login normale
            Task { @MainActor in
                self.signIn()
            }
        }
    }
    
    // MARK: - Sign In with Apple
    func signInWithApple(presentationAnchor: ASPresentationAnchor) {
        Task {
            do {
                try await authService.signInWithApple(presentationAnchor: presentationAnchor)

                // Fetch and cache user profile immediately after login
                await fetchAndCacheUserProfile()

                // Login con successo. La navigazione avverrà in un altro punto.
                isLoggedIn = true
                showHomeScreen = true
            } catch {
                let alert = mapErrorToAlert(error, fallbackTitle: "Login Apple fallito")
                self.alertItem = AlertItem(title: alert.title, message: alert.message)
            }
        }
    }

    // MARK: - Sign In with Google
    func signInWithGoogle() {
        isLoading = true
        Task {
            do {
                try await authService.signInWithGoogle()

                // Fetch and cache user profile immediately after login
                await fetchAndCacheUserProfile()

                // On success, the session publisher in SupabaseManager will trigger the navigation
                // so we just need to stop the loading indicator.
                isLoggedIn = true
                showHomeScreen = true
            } catch {
                let alert = mapErrorToAlert(error, fallbackTitle: "Login Google fallito")
                self.alertItem = AlertItem(title: alert.title, message: alert.message)
            }
            isLoading = false
        }
    }

    // MARK: - Profile Fetching
    private func fetchAndCacheUserProfile() async {
        do {
            // Get current user session
            let session = try await SupabaseManager.client.auth.session
            let userId = session.user.id

            // Fetch user profile from Supabase
            let response: Users = try await SupabaseManager.client
                .from("users")
                .select("*")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            // Create profile object
            let profile = UserProfile(
                name: response.fullName,
                email: session.user.email ?? "",
                phone: "\(response.countryDialCode ?? "") \(response.phoneNumber ?? "")",
                profileImageUrl: nil
            )

            // Cache profile
            if let encoded = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(encoded, forKey: "cachedUserProfile")
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "cachedUserProfileTimestamp")
            }
        } catch {
            print("Failed to fetch user profile: \(error.localizedDescription)")
        }
    }
}
