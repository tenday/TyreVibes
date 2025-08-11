import SwiftUI
import Combine


// MARK: - Main View
struct SignUpScreen: View {

    @StateObject private var viewModel = SignUpViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showOtpScreen = false
    @State private var showPhoneSheet: Bool = false
    @State private var showEmailVerificationSheet = false
    @State private var navigateToForgotPassword = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor.edgesIgnoringSafeArea(.all)
                VStack(spacing: 0) {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    NavigationLink(
                        destination: ForgotPasswordScreen()
                    ) {
                        EmptyView()
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Title and subtitle
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Create Account")
                                    .font(.customFont(size: 32, weight: .semibold))
                                    .fontWeight(.bold)

                                Text("Sign Up to get started")
                                    .font(.customFont(size: 16, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical)
                            //.padding(.top, -18)

                            // Form fields
                            VStack(spacing: 12) {
                                CustomTextField(iconName: "UsernameIcon", placeholder: "Enter Full Name", text: $viewModel.fullName)
                                CustomTextField(iconName: "UsernameIcon", placeholder: "@Username", text: $viewModel.username)
                                
                                PhoneNumberField(
                                    selectedCountry: $viewModel.selectedCountry,
                                    phoneNumber: $viewModel.phoneNumber,
                                    onFlagTap: { showPhoneSheet = true }
                                )

                                EmailField(email: $viewModel.email, isValid: viewModel.isEmailValid)

                                PasswordField(
                                    password: $viewModel.password,
                                    confirmPassword: $viewModel.confirmPassword,
                                    isPasswordValid: viewModel.isPasswordValid,
                                    isConfirmPasswordValid: viewModel.isConfirmPasswordValid,
                                    requirements: viewModel.passwordRequirements
                                )
                                TermsAndConditionsToggle(agreedToTerms: $viewModel.agreedToTerms)
                            }
                        }
                        .padding()
                        .padding(.bottom, 100)
                    }

                    Button(action: {
                        viewModel.createAccount(completion: { result in
                            switch result {
                            case .success:
                                showOtpScreen = true
                            case .failure(_):
                                errorMessage = "Registrazione fallita. si prega di riprovare più tardi"
                                showErrorAlert = true
                            }
                        })
                    }) {
                        if viewModel.isLoadingCreationAccount {
                            Text("")
                                .foregroundColor(Color.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(Color.customBitterSweet)
                                .overlay(ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                    .frame(height: 62)
                                    .frame(maxWidth: .infinity))
                        } else {
                            Text("Create Account")
                                .font(.customFont(size: 18, weight: .bold))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                        }
                    }
                    .background(Color.customBitterSweet)
                    .cornerRadius(100)
                    .opacity(viewModel.isSignUpButtonEnabled ? 1.0 : 0.6)
                    .disabled(!viewModel.isSignUpButtonEnabled || viewModel.isLoadingCreationAccount)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                    .background(Color.customBackgroundColor)
                }
                .sheet(isPresented: $showPhoneSheet) {
                    if viewModel.isLoadingCountries {
                        VStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .foregroundColor(.white)
                                .scaleEffect(1.5)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.customBackgroundColor.ignoresSafeArea())
                    } else {
                        CountrySelectionSheet(
                            countries: viewModel.filteredCountries,
                            searchText: $viewModel.searchText,
                            selectedCountry: $viewModel.selectedCountry,
                            onDone: { showPhoneSheet = false }
                        )
                    }
                }
                .sheet(isPresented: $showEmailVerificationSheet) {
                    EmailVerificationSheet(email: viewModel.email)
                }
                // Corrected alert usage
                .alert("Error", isPresented: $showErrorAlert, actions: {
                    Button("OK", role: .cancel) { }
                }, message: {
                    Text(errorMessage)
                })
                .onChange(of: showPhoneSheet) { _, isShowing in
                    if isShowing {
                        viewModel.fetchCountries()
                    }
                }
                .onChange(of: viewModel.showSuccessAlert) { _, newValue in
                    if newValue {
                        navigateToForgotPassword = true
                    }
                }
                .navigationBarItems(leading: Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                })
                .navigationBarHidden(true)
                .navigationDestination(isPresented: $showOtpScreen) {
                    
                    OTPVerificationView(viewModel: viewModel)
                }
                .navigationBarBackButtonHidden(true)
            }
        }
    }
}


// MARK: - Supporting Structs & Views

struct PasswordRequirement: Identifiable {
    let id = UUID()
    let text: String
    var isValid: Bool
}

// MODIFICA: Ripristinato lo stile originale della riga dei requisiti
struct PasswordRequirementRow: View {
    let requirement: PasswordRequirement

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 5)
                .fill(requirement.isValid ? Color.green : Color(hex: "3A3A3A"))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: requirement.isValid ? "checkmark" : "")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                )

            Text(requirement.text)
                .font(.customFont(size: 12, weight: .regular))
                .foregroundColor(requirement.isValid ? .green : .white)

            Spacer()
        }
    }
}

// MODIFICA: Ripristinato lo stile originale del checkbox
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Button(action: { configuration.isOn.toggle() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(configuration.isOn ? Color.white : Color(hex: "3A3A3A"))
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(hex: "3A3A3A"), lineWidth: 1)
                        )

                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .foregroundColor(.black)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            configuration.label
        }
        
    }
}

// MARK: - Subviews for Readability

struct CustomTextField: View {
    let iconName: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .foregroundColor(.white)
                .frame(height: 24)
            TextField(placeholder, text: $text)
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxHeight: .infinity)
                .disableAutocorrection(true)
                .autocapitalization(.none)
        }
        .padding()
        .frame(height: 62)
        .background(Color.customFieldColor)
        .cornerRadius(18)
    }
}

struct PhoneNumberField: View {
    @Binding var selectedCountry: Country
    @Binding var phoneNumber: String
    var onFlagTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onFlagTap) {
                HStack(spacing: 8) {
                    Text(selectedCountry.flagEmoji ?? "🏳️")
                        .font(.system(size: 26))
                    Text(selectedCountry.dialCode)
                        .font(.customFont(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 100, height: 62)
                .background(Color.customFieldColor)
                .cornerRadius(18)
            }
            .buttonStyle(PlainButtonStyle())

            HStack {
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.numberPad)
                    .onReceive(Just(phoneNumber)) { newValue in
                        let filtered = newValue.filter { "0123456789".contains($0) }
                        if filtered != newValue {
                            phoneNumber = filtered
                        }
                    }
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxHeight: .infinity)
            }
            .padding()
            .background(Color.customFieldColor)
            .cornerRadius(18)
        }
        .frame(height: 62)
    }
}

struct EmailField: View {
    @Binding var email: String
    let isValid: Bool

    var body: some View {
        HStack {
            Image("EmailIcon")
                .resizable()
                .scaledToFit()
                .frame(height: 24)
            TextField("Enter Email", text: $email)
                .frame(maxHeight: .infinity)
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .autocapitalization(.none)

            if !email.isEmpty {
                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isValid ? .green : .red)
            }
        }
        .padding()
        .background(Color.customFieldColor)
        .cornerRadius(18)
        .frame(height: 62)
    }
}

struct PasswordField: View {
    @Binding var password: String
    @Binding var confirmPassword: String
    let isPasswordValid: Bool
    let isConfirmPasswordValid: Bool
    let requirements: [PasswordRequirement]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image("PasswordIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                SecureField("Enter Password", text: $password)
                    .frame(maxHeight: .infinity)
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.customFieldColor)
            .cornerRadius(18)
            .frame(height: 62)

            if !password.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(requirements) { requirement in
                        PasswordRequirementRow(requirement: requirement)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }

            HStack {
                Image("PasswordConfirmationIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                SecureField("Confirm Password", text: $confirmPassword)
                    .frame(maxHeight: .infinity)
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                if !confirmPassword.isEmpty {
                    Image(systemName: isConfirmPasswordValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isConfirmPasswordValid ? .green : .red)
                }
            }
            .padding()
            .background(Color.customFieldColor)
            .cornerRadius(18)
            .frame(height: 62)
        }
    }
}

struct TermsAndConditionsToggle: View {
    @Binding var agreedToTerms: Bool

    var body: some View {
        HStack {
            Toggle(isOn: $agreedToTerms) {
                HStack(spacing: 2) {
                    Text("I agree to the")
                        .foregroundColor(.white)
                        .font(.customFont(size: 12, weight: .regular))

                    Button(action: {
                        if let url = URL(string: "https://tyrevibes.com") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Terms & Conditions")
                            .foregroundColor(Color.customBitterSweet)
                            .font(.customFont(size: 12, weight: .regular))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("and")
                        .foregroundColor(.white)
                        .font(.customFont(size: 12, weight: .regular))

                    Button(action: {
                        if let url = URL(string: "https://tyrevibes.com") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Privacy Policy")
                            .foregroundColor(Color.customBitterSweet)
                            .font(.customFont(size: 12, weight: .regular))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .toggleStyle(CheckboxToggleStyle())
        }
        .padding(.top, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CountrySelectionSheet: View {
    let countries: [Country]
    @Binding var searchText: String
    @Binding var selectedCountry: Country
    var onDone: () -> Void

    var body: some View {
        ZStack {
            Color.customBackgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Select Country")
                        .font(.customFont(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done", action: onDone)
                        .font(.customFont(size: 16, weight: .semibold))
                        .foregroundColor(Color.customBitterSweet)
                }
                .padding([.horizontal, .top], 24)
                .padding(.bottom, 20)

                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Search country", text: $searchText)
                        .foregroundColor(.white)
                }
                .padding()
                .frame(height: 62)
                .background(Color.customFieldColor)
                .cornerRadius(18)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(countries) { country in
                            Button(action: {
                                selectedCountry = country
                                onDone()
                            }) {
                                HStack(spacing: 16) {
                                    Text(country.flagEmoji ?? "🏳️").font(.system(size: 28))
                                    VStack(alignment: .leading) {
                                        Text(country.name).foregroundColor(.white)
                                        Text(country.dialCode).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    if selectedCountry.iso2Code == country.iso2Code {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color.customBitterSweet)
                                            .font(.system(size: 24))
                                    }
                                }
                                .padding()
                                .frame(height: 72)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.customFieldColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(selectedCountry.iso2Code == country.iso2Code ? Color.customBitterSweet : Color.clear, lineWidth: 2)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}

struct EmailVerificationSheet: View {
    let email: String

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color(hex: "#D9D9D9"))
                .frame(width: 88, height: 4)
                .padding(.bottom)

            VStack (spacing: 12){
                Text("Please Verify Your Email")
                    .font(.customFont(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("We just sent an email to \(email).\nClick the link in the email to verify your account.")
                    .multilineTextAlignment(.center)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.customBackgroundColor)
        .cornerRadius(20)
        .presentationDetents([.height(200)])
    }
}

// SwiftUI preview
struct SignUpScreen_Previews: PreviewProvider {
    static var previews: some View {
        SignUpScreen()
            .preferredColorScheme(.dark)
    }
}
