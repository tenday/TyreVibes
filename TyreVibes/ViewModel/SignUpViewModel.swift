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
                handleError(error, title: "Network Error")
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
                try await authService.verifyOtp(otpCode: self.fullOtp, phoneNumber: self.phoneNumber)
                self.showCreationSuccessScreen = true
            } catch {
                // Mostra un alert chiaro per gli errori di verifica OTP
                self.handleError(error, title: "Verifica OTP fallita")
                self.alertTitle = "Codice OTP non valido"
                self.alertMessage = "Codice OTP non valido. Riprova."
                self.showAlert = true
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
                try await authService.sendOtp(phoneNumber:  selectedCountry.dialCode + phoneNumber)
                completion(.success(()))
            } catch {
                handleError(error, title: "Registration Failed")
                completion(.failure(error))
            }
            self.isLoadingCreationAccount = false
        }
    }
    
    
    
    private func handleError(_ error: Error, title: String) {
        self.alertTitle = title
        if let authError = error as? AuthServiceError {
            switch authError {
            case .signUpFailed(let reason): self.alertMessage = "Sign-up Error: \(reason)"
            case .profileCreationFailed(let reason): self.alertMessage = "Profile Error: \(reason)"
            case .noUserFound: self.alertMessage = "No user was found after sign up."
            case .invalidMail(let reason): self.alertMessage = "Invalid email: \(reason)"
            }
        } else {
            self.alertMessage = error.localizedDescription
        }
        self.showAlert = true
    }
    
    func resendCode() {
        isLoadingCheckingOtp = true
        Task {
            do {
                try await authService.sendOtp(phoneNumber: selectedCountry.dialCode + phoneNumber)
            } catch {
                handleError(error, title: "Impossibile inviare nuovamente il codice OTP")
                self.alertTitle = "Codice OTP non valido"
                self.alertMessage = "Codice OTP non valido. Riprova."
                self.showAlert = true
            }
            isLoadingCheckingOtp = false
        }
    }
}

   
