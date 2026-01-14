import SwiftUI

@MainActor
class ResetPasswordViewModel: ObservableObject {
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var alertItem: AlertItem?
    @Published var didResetPassword = false

    // Password validation states
    @Published var hasUpperCase = false
    @Published var hasNumber = false
    @Published var hasMinLength = false
    @Published var hasSpecialChar = false

    private let authService = AuthService()

    var passwordRequirements: [PasswordRequirement] {
        [
            PasswordRequirement(text: "At least one upper case letter", isValid: hasUpperCase),
            PasswordRequirement(text: "At least one numeral (0-9)", isValid: hasNumber),
            PasswordRequirement(text: "Minimum 6 characters", isValid: hasMinLength),
            PasswordRequirement(text: "At least one special symbol (!@#$%^&*<>()-)", isValid: hasSpecialChar)
        ]
    }

    var isResetButtonEnabled: Bool {
        isFormValid() && !isLoading
    }

    func validatePassword() {
        hasUpperCase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        hasMinLength = password.count >= 6
        hasSpecialChar = password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*<>()-")) != nil
    }

    private func isFormValid() -> Bool {
        return hasUpperCase && hasNumber && hasMinLength && hasSpecialChar &&
               !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }

    func resetPassword() {
        guard isResetButtonEnabled else { return }

        isLoading = true
        didResetPassword = false

        Task {
            do {
                try await authService.updateUserPassword(password: password)
                didResetPassword = true
                self.alertItem = AlertItem(title: "Password reimpostata", message: "La tua password è stata reimpostata con successo.")
            } catch {
                self.alertItem = AlertItem(title: "Errore", message: error.localizedDescription)
            }
            self.isLoading = false
        }
    }
}
