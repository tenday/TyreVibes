import Foundation
import Combine

// MARK: - ViewModel
@MainActor
class SignUpViewModel: ObservableObject {
    
    // MARK: - Form Properties
    @Published var fullName = ""
    @Published var username = ""
    @Published var phoneNumber = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var agreedToTerms = false
    @Published var selectedCountry: Country = Country(id: 1, name: "Italy", iso2Code: "IT", dialCode: "+39", flagEmoji: "🇮🇹")
    
    // MARK: - Countries List & Search
    @Published var countries: [Country] = []
    @Published var searchText = ""
    
    // MARK: - Validation & State
    @Published var passwordRequirements: [PasswordRequirement] = []
    @Published var isLoadingCreationAccount = false
    @Published var isLoadingCountries = false
    @Published var isLoadingCheckingOtp = false
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var showSuccessAlert = false
    @Published var fullOtp = ""
    @Published var showCreationSuccessScreen = false
    
    private var cancellables = Set<AnyCancellable>()
    private let authService = AuthService()

    // MARK: - Computed Properties (Logic)
    var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var isPasswordValid: Bool {
        passwordRequirements.allSatisfy { $0.isValid }
    }
    
    var isConfirmPasswordValid: Bool {
        !password.isEmpty && password == confirmPassword
    }
    
    var isSignUpButtonEnabled: Bool {
        !fullName.isEmpty && !username.isEmpty && !phoneNumber.isEmpty &&
        isEmailValid && isPasswordValid && isConfirmPasswordValid && agreedToTerms
    }
    
    var filteredCountries: [Country] {
        if searchText.isEmpty {
            return countries
        } else {
            return countries.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.dialCode.contains(searchText) }
        }
    }
    
    // MARK: - Initialization
    init() {
        setupPasswordValidation()
        setupUsernameFormatting()
    }
    
    // MARK: - Methods
    private func setupPasswordValidation() {
        $password
            .removeDuplicates()
            .map { pass -> [PasswordRequirement] in
                return [
                    PasswordRequirement(text: "At least one upper case letter", isValid: pass.rangeOfCharacter(from: .uppercaseLetters) != nil),
                    PasswordRequirement(text: "At least one numeral (0-9)", isValid: pass.rangeOfCharacter(from: .decimalDigits) != nil),
                    PasswordRequirement(text: "Minimum 6 characters", isValid: pass.count >= 6),
                    PasswordRequirement(text: "At least one special symbol (!@#...)", isValid: pass.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()<>{}|-")) != nil)
                ]
            }
            .assign(to: \.passwordRequirements, on: self)
            .store(in: &cancellables)
    }
    
    private func setupUsernameFormatting() {
        $username
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newUsername in
                if !newUsername.hasPrefix("@") && !newUsername.isEmpty {
                    self?.username = "@" + newUsername
                }
            }
            .store(in: &cancellables)
    }
    
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
                self.alertTitle = alert.title
                self.alertMessage = alert.message
                self.showAlert = true
            }
            self.isLoadingCountries = false
        }
    }
    
    func verifyOtp() {
        isLoadingCheckingOtp = true

        Task { [weak self] in
            guard let self = self else { return }
            defer { self.isLoadingCheckingOtp = false }

            // Validazione locale OTP (6 cifre numeriche)
            let digits = CharacterSet.decimalDigits
            let isSixDigits = self.fullOtp.count == 6
            let isNumeric = CharacterSet(charactersIn: self.fullOtp).isSubset(of: digits)
            guard isSixDigits && isNumeric else {
                self.alertTitle = "Codice OTP non valido"
                self.alertMessage = "Inserisci un codice di 6 cifre."
                self.showAlert = true
                return
            }

            do {
                try await authService.verifyOtp(otpCode: self.fullOtp, phoneNumber: selectedCountry.dialCode + phoneNumber)
                
                createAccount { result in
                    switch result {
                    case .success:
                        self.showCreationSuccessScreen = true
                    case .failure(let error):
                        let alert = self.mapErrorToAlert(error, fallbackTitle: "Registrazione fallita")
                        self.alertTitle = alert.title
                        self.alertMessage = alert.message
                        self.showAlert = true
                    }
                }
            } catch {
                if let authError = error as? AuthServiceError {
                    switch authError {
                    case .otpInvalid:
                        self.alertTitle = "Codice OTP errato"
                        self.alertMessage = "Il codice inserito non è corretto. Verifica e riprova."
                        self.showAlert = true
                    case .otpExpired:
                        self.alertTitle = "Codice OTP scaduto"
                        self.alertMessage = "Il codice OTP è scaduto. Richiedine uno nuovo."
                        self.showAlert = true
                    default:
                        let alert = mapErrorToAlert(error, fallbackTitle: "Verifica OTP fallita")
                        self.alertTitle = alert.title
                        self.alertMessage = alert.message
                        self.showAlert = true
                    }
                } else {
                    let alert = mapErrorToAlert(error, fallbackTitle: "Verifica OTP fallita")
                    self.alertTitle = alert.title
                    self.alertMessage = alert.message
                    self.showAlert = true
                }
            }
        }
    }

    func createAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        isLoadingCreationAccount = true
        showSuccessAlert = false


        Task {
            do {

                try await authService.createAccount(
                    email: email,
                    password: password,
                    fullName: fullName,
                    username: username,
                    phoneNumber: phoneNumber,
                    selectedCountry: selectedCountry,
                    agreedToTerms: agreedToTerms
                )
                self.alertTitle = "Registration Successful"
                self.alertMessage = "Please check your email to verify your account."
                self.showSuccessAlert = true
                self.showAlert = true
                completion(.success(()))
            } catch {
                let alert = mapErrorToAlert(error, fallbackTitle: "Registrazione fallita")
                self.alertTitle = alert.title
                self.alertMessage = alert.message
                self.showAlert = true
                completion(.failure(error))
            }
            self.isLoadingCreationAccount = false
        }
    }
    
    
    
    private func isUserAlreadyExistsReason(_ reason: String) -> Bool {
        let lower = reason.lowercased()
        return lower.contains("already") ||
               lower.contains("exists") ||
               lower.contains("409") ||
               lower.contains("in use") ||
               lower.contains("già") ||
               lower.contains("duplic")
    }

    private func mapErrorToAlert(_ error: Error, fallbackTitle: String) -> (title: String, message: String) {
        // AuthService domain-specific errors first
        if let authError = error as? AuthServiceError {
            switch authError {
            case .invalidMail(let reason):
                return ("Email non valida", reason)
            case .noUserFound:
                return ("Utente non trovato", "Nessun utente trovato dopo la registrazione.")
            case .profileCreationFailed(let reason):
                return ("Errore creazione profilo", reason)
            case .signUpFailed(let reason):
                if isUserAlreadyExistsReason(reason) {
                    return ("Utenza già registrata", "Esiste già un account con queste credenziali. Se hai dimenticato la password, prova il recupero.")
                } else {
                    return ("Registrazione fallita", reason.isEmpty ? "Si è verificato un errore durante la registrazione. Riprova." : reason)
                }
            case .otpInvalid:
                return ("Codice OTP errato", "Il codice inserito non è corretto. Verifica e riprova.")
            case .otpExpired:
                return ("Codice OTP scaduto", "Il codice OTP è scaduto. Richiedine uno nuovo.")
            }
        }

        // Network / transport errors
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

        // Generic HTTP-like numeric code surfaced as NSError (best-effort)
        let nsErr = error as NSError
        if nsErr.domain == NSURLErrorDomain {
            if nsErr.code == NSURLErrorTimedOut {
                return ("Timeout", "La richiesta ha impiegato troppo tempo. Controlla la connessione e riprova.")
            }
        }
        if nsErr.code == 409 { // Conflict – spesso usato per "già esistente"
            return ("Utenza già registrata", "Esiste già un account con queste credenziali. Se hai dimenticato la password, prova il recupero.")
        }

        // Decoding / data errors
        if error is DecodingError {
            return ("Errore dati", "Risposta non valida dal server. Riprova più tardi.")
        }

        // Fallback
        let message = (error.localizedDescription.isEmpty ? "Si è verificato un errore imprevisto. Riprova." : error.localizedDescription)
        return (fallbackTitle, message)
    }

    private func handleError(_ error: Error, title: String) {
        let alert = mapErrorToAlert(error, fallbackTitle: title)
        self.alertTitle = alert.title
        self.alertMessage = alert.message
        self.showAlert = true
    }
    
    func sendCode(completion: @escaping (Result<Void, Error>) -> Void) {
        isLoadingCheckingOtp = true
        Task {
            do {
                try await authService.sendOtp(phoneNumber: selectedCountry.dialCode + phoneNumber)
                completion(.success(()))
            } catch {
                let alert = mapErrorToAlert(error, fallbackTitle: "Invio OTP fallito")
                self.alertTitle = alert.title
                self.alertMessage = alert.message
                self.showAlert = true
                completion(.failure(error))
            }
            isLoadingCheckingOtp = false
        }
    }
}
