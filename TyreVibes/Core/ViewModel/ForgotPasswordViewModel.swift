import SwiftUI

@MainActor
class ForgotPasswordViewModel: ObservableObject {
    @Published var email = ""
    @Published var isLoading = false
    @Published var alertItem: AlertItem?
    @Published var didSendResetLink = false

    private let authService = AuthService()

    var isSendButtonEnabled: Bool {
        !email.isEmpty && !isLoading
    }

    func sendPasswordResetLink() {
        guard isSendButtonEnabled else { return }

        isLoading = true
        didSendResetLink = false

        Task {
            do {
                try await authService.sendPasswordReset(email: email)
                didSendResetLink = true
                self.alertItem = AlertItem(title: "Link inviato", message: "Controlla la tua email per il link di reset della password.")
            } catch {
                self.alertItem = AlertItem(title: "Errore", message: error.localizedDescription)
            }
            self.isLoading = false
        }
    }
}