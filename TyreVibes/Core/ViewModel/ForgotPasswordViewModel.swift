import SwiftUI

@MainActor
class ForgotPasswordViewModel: ObservableObject {
    @Published var email = ""
    @Published var isSendingLink = false
    @Published var didSendLink = false
    @Published var alertItem: AlertItem?

    private let authService = AuthService()

    var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: trimmed)
    }

    var isSendButtonEnabled: Bool {
        isEmailValid && !isSendingLink
    }

    func sendResetLink() {
        guard isEmailValid else {
            alertItem = AlertItem(title: "Email non valida", message: "Inserisci un indirizzo email corretto.")
            return
        }
        guard !isSendingLink else { return }

        isSendingLink = true
        didSendLink = false
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        Task {
            do {
                try await authService.sendPasswordReset(email: trimmedEmail)
                didSendLink = true
                alertItem = AlertItem(
                    title: "Email inviata",
                    message: "Ti abbiamo inviato un link per reimpostare la password. Controlla anche la cartella spam."
                )
            } catch {
                let alert = mapErrorToAlert(error, fallbackTitle: "Invio non riuscito")
                alertItem = AlertItem(title: alert.title, message: alert.message)
            }
            isSendingLink = false
        }
    }

    private func mapErrorToAlert(_ error: Error, fallbackTitle: String) -> (title: String, message: String) {
        if let authError = error as? AuthServiceError {
            switch authError {
            case .invalidMail(let reason):
                return ("Email non valida", reason)
            case .noUserFound:
                return ("Utente non trovato", "Non esiste un account associato a questa email.")
            default:
                break
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return ("Timeout", "La richiesta ha impiegato troppo tempo. Controlla la connessione e riprova.")
            case .notConnectedToInternet, .networkConnectionLost:
                return ("Connessione assente", "Verifica la tua connessione internet e riprova.")
            default:
                break
            }
        }

        let message = error.localizedDescription.isEmpty ? "Si è verificato un errore imprevisto. Riprova." : error.localizedDescription
        return (fallbackTitle, message)
    }
}
