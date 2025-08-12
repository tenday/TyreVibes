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
    
    @Published var formFocus: LoginFormFocus?

    private let authService = AuthService()
    
    override init() {
        super.init()
        attemptAutoLogin()
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
                
                if rememberMe {
                    try KeychainHelper.save(email: email, password: password)
                } else {
                    KeychainHelper.delete()
                }
                // Login con successo. La navigazione avverrà in un altro punto.
                
            } catch {
                // CORREZIONE: Mostra sempre l'alert in caso di errore
                self.alertItem = AlertItem(title: "Login Failed", message: error.localizedDescription)
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
                self.alertItem = AlertItem(title: "Apple Login Failed", message: error.localizedDescription)
            }
        }
    }

    

    
}

// Assicurati di avere queste struct di supporto nel tuo progetto


struct Credentials {
    let email: String
    let password: String
}

