import SwiftUI

struct ResetPasswordScreen: View {
    
    @StateObject private var viewModel = ResetPasswordViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
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
                                Image(systemName: "chevron.left")
                                    .resizable()
                                    .frame(width: 15, height: 24)
                                    .foregroundColor(.white)
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
                                        TextField("Enter Password", text: $viewModel.password)
                                            .frame(maxHeight: .infinity)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .onChange(of: viewModel.password) {
                                                viewModel.validatePassword()
                                            }
                                    } else {
                                        SecureField("Enter Password", text: $viewModel.password)
                                            .frame(maxHeight: .infinity)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .onChange(of: viewModel.password) {
                                                viewModel.validatePassword()
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
                                    ForEach(viewModel.passwordRequirements) { requirement in
                                        PasswordRequirementRow(requirement: requirement)
                                    }
                                }
                                .padding(.top, 0)
                                
                                // Confirm Password Field
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.gray)
                                        .frame(height: 24)
                                    
                                    if showConfirmPassword {
                                        TextField("Confirm Password", text: $viewModel.confirmPassword)
                                            .frame(maxHeight: .infinity)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    } else {
                                        SecureField("Confirm Password", text: $viewModel.confirmPassword)
                                            .frame(maxHeight: .infinity)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    if !viewModel.confirmPassword.isEmpty {
                                        Image(systemName: viewModel.password == viewModel.confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(viewModel.password == viewModel.confirmPassword ? .green : .red)
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
                                viewModel.resetPassword()
                            }) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Reset Password")
                                        .font(.customFont(size: buttonFontSize, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: buttonHeight)
                            .background(
                                viewModel.isResetButtonEnabled ?
                                Color.customBitterSweet :
                                Color.customBitterSweet.opacity(0.6)
                            )
                            .cornerRadius(screenWidth * 0.133)
                            .disabled(!viewModel.isResetButtonEnabled)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isResetButtonEnabled)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .alert(item: $viewModel.alertItem) { alertItem in
            Alert(title: Text(alertItem.title), message: Text(alertItem.message), dismissButton: .default(Text("OK"), action: {
                if viewModel.didResetPassword {
                    // Navigate to login screen or dismiss
                    // For now, just dismiss
                    dismiss()
                }
            }))
        }
    }
}

struct ResetPasswordScreen_Previews: PreviewProvider {
    static var previews: some View {
        ResetPasswordScreen()
    }
}
