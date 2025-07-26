
import SwiftUI
import Combine
import Security


@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var rememberMe = false
    
    @Published var isLoading = false
    @Published var alertItem: AlertItem?
    
    private let authService = AuthService()
    
    init() {
        attemptAutoLogin()
    }
    var isLoginButtonEnabled: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    func signIn() {
        // Nascondi la tastiera
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        isLoading = true
        Task {
            do {
                try await authService.signIn(email: email, password: password)
                
                if rememberMe {
                    try KeychainHelper.save(email: email, password: password)
                    } else {
                    KeychainHelper.delete()
                    }
                // Se il login ha successo, qui dovresti navigare alla schermata principale dell'app.
                // Per ora, non facciamo nulla, ma l'indicatore di caricamento si fermerà.
            } catch {
                if !rememberMe {
                    self.alertItem = AlertItem(title: "Login Failed", message: error.localizedDescription)
                }
            }
            self.isLoading = false
        }
    }
    
    private func attemptAutoLogin() {
           // Carica le credenziali dal Keychain
           if let credentials = KeychainHelper.load() {
               self.email = credentials.email
               self.password = credentials.password
               self.rememberMe = true
               
               // Avvia il processo di sign-in automatico
               signIn()
           }
       }
}
