import SwiftUI
import Combine
import Security
import AuthenticationServices

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

    private let authService = AuthService()
    
    override init() {
        super.init()
        attemptAutoLogin()
    }
    
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
                
                if rememberMe {
                    try KeychainHelper.save(email: email, password: password)
                } else {
                    KeychainHelper.delete()
                }

                showHomeScreen = true
            } catch {
                let alert = mapErrorToAlert(error, fallbackTitle: "Login fallito")
                self.alertItem = AlertItem(title: alert.title, message: alert.message)
            }
            self.isLoading = false
        }
    }
    
    private func attemptAutoLogin() {
        if let credentials = KeychainHelper.load() {
            self.email = credentials.email
            self.password = credentials.password
            self.rememberMe = true
            signIn()
        }
    }
    
    // MARK: - Sign In with Apple
    func signInWithApple(presentationAnchor: ASPresentationAnchor) {
        Task {
            do {
                try await authService.signInWithApple(presentationAnchor: presentationAnchor)
                // Login con successo. La navigazione avverrà in un altro punto.
            } catch {
                let alert = mapErrorToAlert(error, fallbackTitle: "Login Apple fallito")
                self.alertItem = AlertItem(title: alert.title, message: alert.message)
            }
        }
    }

    

    
}
