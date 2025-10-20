import Foundation
import SwiftUI

// MARK: - App Error Protocol
protocol AppErrorProtocol: LocalizedError {
    var title: String { get }
    var message: String { get }
    var actionTitle: String? { get }
    var shouldLog: Bool { get }
}

extension AppErrorProtocol {
    var actionTitle: String? { nil }
    var shouldLog: Bool { true }
}

// MARK: - Error Handler
@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published var currentError: AppErrorProtocol?
    @Published var showError: Bool = false

    private init() {}

    // MARK: - Handle Error
    func handle(_ error: Error, context: String? = nil) {
        let contextMessage = context.map { " (\($0))" } ?? ""

        // Log the error
        AppLogger.shared.error("Error\(contextMessage): \(error.localizedDescription)")

        // Convert to AppErrorProtocol if possible
        if let appError = error as? AppErrorProtocol {
            currentError = appError
        } else {
            // Wrap generic error
            currentError = GenericError(underlyingError: error)
        }

        showError = true
    }

    func clearError() {
        currentError = nil
        showError = false
    }
}

// MARK: - Generic Error Wrapper
struct GenericError: AppErrorProtocol {
    let underlyingError: Error

    var title: String {
        "Errore"
    }

    var message: String {
        underlyingError.localizedDescription
    }

    var errorDescription: String? {
        underlyingError.localizedDescription
    }
}

// MARK: - Error Alert Modifier
struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorHandler = ErrorHandler.shared

    func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.title ?? "Errore",
                isPresented: $errorHandler.showError,
                presenting: errorHandler.currentError
            ) { error in
                Button("OK") {
                    errorHandler.clearError()
                }
                if let actionTitle = error.actionTitle {
                    Button(actionTitle) {
                        // Handle action
                        errorHandler.clearError()
                    }
                }
            } message: { error in
                Text(error.message)
            }
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorAlertModifier())
    }
}

// MARK: - Specific App Errors
struct ValidationError: AppErrorProtocol {
    let field: String
    let reason: String

    var title: String { "Errore di Validazione" }
    var message: String { "\(field): \(reason)" }
    var errorDescription: String? { message }
}

struct ConnectionError: AppErrorProtocol {
    var title: String { "Errore di Connessione" }
    var message: String { "Impossibile connettersi al server. Verifica la tua connessione internet." }
    var errorDescription: String? { message }
    var actionTitle: String? { "Riprova" }
}

struct UnauthorizedError: AppErrorProtocol {
    var title: String { "Non Autorizzato" }
    var message: String { "Devi effettuare il login per accedere a questa funzionalità." }
    var errorDescription: String? { message }
    var actionTitle: String? { "Login" }
}
