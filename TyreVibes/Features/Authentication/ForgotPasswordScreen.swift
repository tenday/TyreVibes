import SwiftUI

struct ForgotPasswordScreen: View {
    
    @StateObject private var viewModel = ForgotPasswordViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showPhoneSheet = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let screenHeight = geometry.size.height
                
                let buttonHeight = screenHeight * 0.075
                let buttonFontSize = screenWidth * 0.045
                
                ZStack {
                    Color.customBackgroundColor
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        header
                        
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 28) {
                                titleSection
                                phoneSection(buttonHeight: buttonHeight, buttonFontSize: buttonFontSize)
                                
                                if viewModel.isOtpSent {
                                    otpSection(buttonHeight: buttonHeight, buttonFontSize: buttonFontSize)
                                }
                                
                                if viewModel.isOtpVerified {
                                    passwordSection(buttonHeight: buttonHeight, buttonFontSize: buttonFontSize)
                                }
                                
                                Spacer(minLength: 20)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPhoneSheet) {
            if viewModel.isLoadingCountries {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
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
        .alert(item: $viewModel.alertItem) { alertItem in
            Alert(title: Text(alertItem.title),
                  message: Text(alertItem.message),
                  dismissButton: .default(Text("OK"), action: {
                      if viewModel.didResetPassword {
                          dismiss()
                      }
                  }))
        }
        .onChange(of: showPhoneSheet) { _, value in
            if value {
                viewModel.fetchCountries()
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    private var header: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .resizable()
                    .frame(width: 15, height: 24)
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Forgot Password")
                .font(.customFont(size: 32, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            Text("Inserisci il numero di telefono associato al tuo account, verifica l'OTP ricevuto via SMS e imposta una nuova password sicura.")
                .font(.customFont(size: 16, weight: .regular))
                .foregroundColor(.gray)
                .lineSpacing(4)
        }
    }
    
    private func phoneSection(buttonHeight: CGFloat, buttonFontSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Numero di telefono")
                .font(.customFont(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            PhoneNumberField(
                selectedCountry: $viewModel.selectedCountry,
                phoneNumber: $viewModel.phoneNumber,
                onFlagTap: { showPhoneSheet = true }
            )
            
            Button(action: {
                viewModel.sendOtp()
            }) {
                if viewModel.isSendingOtp {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(viewModel.sendOtpButtonTitle)
                        .font(.customFont(size: buttonFontSize, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(viewModel.isSendButtonEnabled ? Color.customBitterSweet : Color.customBitterSweet.opacity(0.6))
            .cornerRadius(30)
            .disabled(!viewModel.isSendButtonEnabled)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isSendButtonEnabled)
            
            if viewModel.countdown > 0 {
                Text("Potrai richiedere un nuovo codice tra \(viewModel.countdown)s")
                    .font(.customFont(size: 14, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func otpSection(buttonHeight: CGFloat, buttonFontSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Codice di verifica")
                .font(.customFont(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Abbiamo inviato un OTP al numero \(maskedPhoneNumber). Inserisci il codice di 6 cifre per continuare.")
                .font(.customFont(size: 15, weight: .regular))
                .foregroundColor(.gray)
                .lineSpacing(4)
            
            HStack {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.gray)
                    .frame(height: 24)
                TextField("Codice OTP", text: Binding(
                    get: { viewModel.otpCode },
                    set: { newValue in
                        let digits = newValue.filter { $0.isNumber }
                        viewModel.otpCode = String(digits.prefix(6))
                    }
                ))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .foregroundColor(.white)
                .font(.customFont(size: 18, weight: .semibold))
            }
            .padding()
            .background(Color.customFieldColor)
            .cornerRadius(18)
            .frame(height: 62)
            
            if viewModel.isOtpVerified {
                Label("OTP verificato", systemImage: "checkmark.seal.fill")
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.green)
            } else {
                Button(action: {
                    viewModel.verifyOtp()
                }) {
                    if viewModel.isVerifyingOtp {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Verifica codice")
                            .font(.customFont(size: buttonFontSize, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: buttonHeight)
                .background(viewModel.isVerifyButtonEnabled ? Color.customElectricBlueColor : Color.customElectricBlueColor.opacity(0.6))
                .cornerRadius(30)
                .disabled(!viewModel.isVerifyButtonEnabled)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isVerifyButtonEnabled)
            }
        }
    }
    
    private func passwordSection(buttonHeight: CGFloat, buttonFontSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nuova password")
                .font(.customFont(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            PasswordField(
                password: $viewModel.password,
                confirmPassword: $viewModel.confirmPassword,
                isPasswordValid: viewModel.isPasswordValid,
                isConfirmPasswordValid: viewModel.isConfirmPasswordValid,
                requirements: viewModel.passwordRequirements
            )
            
            Button(action: {
                viewModel.resetPassword()
            }) {
                if viewModel.isResettingPassword {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Aggiorna password")
                        .font(.customFont(size: buttonFontSize, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(viewModel.isResetButtonEnabled ? Color.customBitterSweet : Color.customBitterSweet.opacity(0.6))
            .cornerRadius(30)
            .disabled(!viewModel.isResetButtonEnabled)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isResetButtonEnabled)
        }
    }
    
    private var maskedPhoneNumber: String {
        guard !viewModel.phoneNumber.isEmpty else {
            return "\(viewModel.selectedCountry.dialCode) ••••"
        }
        let formatted = viewModel.selectedCountry.dialCode + viewModel.phoneNumber
        return Utilities.maskPhoneNumber(formatted)
    }
}

struct ForgotPasswordScreen_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordScreen()
    }
}
