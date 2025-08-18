import SwiftUI

struct ResetPasswordScreen: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    // Password validation states
    @State private var hasUpperCase = false
    @State private var hasNumber = false
    @State private var hasMinLength = false
    @State private var hasSpecialChar = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let screenHeight = geometry.size.height
                
                // Calcola le dimensioni dinamiche basate sullo schermo
                let buttonHeight = screenHeight * 0.075 // ~60pt
                let buttonFontSize = screenWidth * 0.045 // ~18pt
                
                ZStack {
                    // Background
                    Color.customBackgroundColor
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Button(action: {
                                dismiss()
                            }) {
                                Image("ArrowIcon")
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Main Content
                        VStack(alignment: .leading, spacing: 30) {
                            // Title and Description Section
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Reset Password")
                                    .font(.customFont(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.top, 20)
                                
                                Text("Your new password must be different from previous used passwords.")
                                    .font(.customFont(size: 16, weight: .regular))
                                    .foregroundColor(.gray)
                                    .lineSpacing(4)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.bottom, 30)
                            
                            // Form Fields
                            VStack(spacing: 6) {
                                // Password Field
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.gray)
                                        .frame(height: 24)
                                    
                                    if showPassword {
                                        TextField("Enter Password", text: $password)
                                            .frame(maxHeight: .infinity)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .onChange(of: password) {
                                                validatePassword(password)
                                            }
                                    } else {
                                        SecureField("Enter Password", text: $password)
                                            .frame(maxHeight: .infinity)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .onChange(of: password) {
                                                validatePassword(password)
                                            }
                                    }
                                    
                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                            .foregroundColor(.gray)
                                            .frame(width: 24, height: 24)
                                    }
                                }
                                .padding()
                                .background(Color.customFieldColor)
                                .cornerRadius(18)
                                .frame(height: 62)
                                
                                // Password Requirements
                                VStack(alignment: .leading, spacing: 12) {
                                 //   PasswordRequirementRow(
                                 //       requirement: Pass, text: "At least one upper case letter",
                                 //       isValid: hasUpperCase
                                 //   )
                                    
                                 //   PasswordRequirement(
                                 //       text: "At least one numeral (0-9)",
                                 //       isValid: hasNumber
                                 //   )
                                 
                                 //   PasswordRequirement(
                                 //       text: "Minimum 6 characters",
                                 //       isValid: hasMinLength
                                 //   )
                                    
                                  //  PasswordRequirement(
                                  //      text: "At least one special symbol (!@#$%^&*<>()-)",
                                  //      isValid: hasSpecialChar
                                  //  )
                                }
                                .padding(.top, 0)
                                
                                // Confirm Password Field
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.gray)
                                        .frame(height: 24)
                                    
                                    if showConfirmPassword {
                                        TextField("Confirm Password", text: $confirmPassword)
                                            .frame(maxHeight: .infinity)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    } else {
                                        SecureField("Confirm Password", text: $confirmPassword)
                                            .frame(maxHeight: .infinity)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    if !confirmPassword.isEmpty {
                                        Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(password == confirmPassword ? .green : .red)
                                            .frame(width: 24, height: 24)
                                    }
                                }
                                .padding()
                                .background(Color.customFieldColor)
                                .cornerRadius(18)
                                .frame(height: 62)
                            }
                            
                            
                            // Reset Password Button
                            Button(action: {
                                // Reset password action
                                print("Reset password")
                                // Qui puoi aggiungere la logica per il reset della password
                            }) {
                                Text("Reset Password")
                                    .font(.customFont(size: buttonFontSize, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: buttonHeight)
                                    .background(
                                        isFormValid() ?
                                        Color.customBitterSweet :
                                        Color.customBitterSweet.opacity(0.6)
                                    )
                                    .cornerRadius(screenWidth * 0.133)
                            }
                            .disabled(!isFormValid())
                            .animation(.easeInOut(duration: 0.2), value: isFormValid())
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Helper Functions
    
    private func validatePassword(_ password: String) {
        hasUpperCase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        hasMinLength = password.count >= 6
        hasSpecialChar = password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*<>()-")) != nil
    }
    
    private func isFormValid() -> Bool {
        return hasUpperCase && hasNumber && hasMinLength && hasSpecialChar &&
               !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }
}

struct ResetPasswordScreen_Previews: PreviewProvider {
    static var previews: some View {
        ResetPasswordScreen()
    }
}
