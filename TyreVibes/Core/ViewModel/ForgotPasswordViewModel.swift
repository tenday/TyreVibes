import SwiftUI
import Combine

@MainActor
class ForgotPasswordViewModel: ObservableObject {
    // Phone & countries
    @Published var selectedCountry: Country = Country(id: 1, name: "Italy", iso2Code: "IT", dialCode: "+39", flagEmoji: "🇮🇹")
    @Published var phoneNumber = ""
    @Published var countries: [Country] = []
    @Published var searchText = ""
    @Published var isLoadingCountries = false

    // OTP
    @Published var otpCode = ""
    @Published var isSendingOtp = false
    @Published var isOtpSent = false
    @Published var isVerifyingOtp = false
    @Published var isOtpVerified = false
    @Published var countdown = 0

    // Password
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var passwordRequirements: [PasswordRequirement] = []
    @Published var isResettingPassword = false

    // Alerts
    @Published var alertItem: AlertItem?
    @Published var didResetPassword = false

    private let authService = AuthService()
    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: Timer?

    init() {
        setupPasswordValidation()
    }

    deinit {
        countdownTimer?.invalidate()
    }

    // MARK: - Computed helpers
    var filteredCountries: [Country] {
        if searchText.isEmpty {
            return countries
        }
        return countries.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.dialCode.contains(searchText) }
    }

    private var fullPhoneNumber: String {
        selectedCountry.dialCode + phoneNumber
    }

    private var isPhoneValid: Bool {
        phoneNumber.count >= 6
    }

    var sendOtpButtonTitle: String {
        isOtpSent ? "Resend OTP" : "Send OTP"
    }

    var isSendButtonEnabled: Bool {
        isPhoneValid && !isSendingOtp && countdown == 0
    }

    var isVerifyButtonEnabled: Bool {
        otpCode.count == 6 && !isVerifyingOtp
    }

    var isPasswordValid: Bool {
        passwordRequirements.allSatisfy { $0.isValid }
    }

    var isConfirmPasswordValid: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var isResetButtonEnabled: Bool {
        isOtpVerified && isPasswordValid && isConfirmPasswordValid && !isResettingPassword
    }

    // MARK: - Country picker
    func fetchCountries() {
        isLoadingCountries = true

        guard countries.isEmpty else {
            self.isLoadingCountries = false
            return
        }

        Task {
            do {
                self.countries = try await authService.fetchCountries()
                if let italy = self.countries.first(where: { $0.iso2Code == "IT" }) {
                    self.selectedCountry = italy
                }
            } catch {
                let alert = mapErrorToAlert(error, fallbackTitle: "Errore di rete")
                self.alertItem = AlertItem(title: alert.title, message: alert.message)
            }
            self.isLoadingCountries = false
        }
    }

    // MARK: - Password validation
    private func setupPasswordValidation() {
        $password
            .removeDuplicates()
            .map { pass -> [PasswordRequirement] in
                [
                    PasswordRequirement(text: "At least one upper case letter", isValid: pass.rangeOfCharacter(from: .uppercaseLetters) != nil),
                    PasswordRequirement(text: "At least one numeral (0-9)", isValid: pass.rangeOfCharacter(from: .decimalDigits) != nil),
                    PasswordRequirement(text: "Minimum 6 characters", isValid: pass.count >= 6),
                    PasswordRequirement(text: "At least one special symbol (!@#...)", isValid: pass.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()<>{}|-")) != nil)
                ]
            }
            .assign(to: \.passwordRequirements, on: self)
            .store(in: &cancellables)
    }

    // MARK: - OTP flow
    func sendOtp() {
        guard isPhoneValid else {
            alertItem = AlertItem(title: "Numero non valido", message: "Inserisci un numero di telefono valido.")
            return
        }
        guard isSendButtonEnabled else { return }

        isSendingOtp = true
        isOtpSent = false
        isOtpVerified = false
        otpCode = ""

        Task {
            do {
                try await authService.sendOtp(phoneNumber: fullPhoneNumber)
                isOtpSent = true
                startCountdown()
            } catch {
                let alert = mapErrorToAlert(error, fallbackTitle: "Invio OTP fallito")
                self.alertItem = AlertItem(title: alert.title, message: alert.message)
            }
            self.isSendingOtp = false
        }
    }

    func verifyOtp() {
        guard isOtpSent else {
            alertItem = AlertItem(title: "OTP non inviato", message: "Invia prima il codice OTP al tuo numero.")
            return
        }
        guard isVerifyButtonEnabled else {
            alertItem = AlertItem(title: "Codice non valido", message: "Inserisci un codice OTP di 6 cifre.")
            return
        }

        isVerifyingOtp = true

        Task {
            do {
                try await authService.verifyOtp(otpCode: otpCode, phoneNumber: fullPhoneNumber)
                isOtpVerified = true
            } catch {
                let alert = mapErrorToAlert(error, fallbackTitle: "Verifica OTP fallita")
                self.alertItem = AlertItem(title: alert.title, message: alert.message)
            }
            self.isVerifyingOtp = false
        }
    }

    func resetPassword() {
        guard isResetButtonEnabled else { return }

        isResettingPassword = true
        didResetPassword = false

        Task {
            do {
                try await authService.updateUserPassword(password: password)
                didResetPassword = true
                alertItem = AlertItem(title: "Password aggiornata", message: "La tua password è stata cambiata con successo.")
            } catch {
                let alert = mapErrorToAlert(error, fallbackTitle: "Reset password fallito")
                self.alertItem = AlertItem(title: alert.title, message: alert.message)
            }
            self.isResettingPassword = false
        }
    }

    // MARK: - Helpers
    private func startCountdown() {
        countdownTimer?.invalidate()
        countdown = 60

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            if self.countdown > 0 {
                self.countdown -= 1
            } else {
                timer.invalidate()
                self.countdownTimer = nil
            }
        }
        if let timer = countdownTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func mapErrorToAlert(_ error: Error, fallbackTitle: String) -> (title: String, message: String) {
        if let authError = error as? AuthServiceError {
            switch authError {
            case .otpInvalid:
                return ("Codice OTP errato", "Il codice inserito non è corretto. Verifica e riprova.")
            case .otpExpired:
                return ("Codice OTP scaduto", "Il codice OTP è scaduto. Richiedine uno nuovo.")
            case .invalidMail(let reason):
                return ("Dato non valido", reason)
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
