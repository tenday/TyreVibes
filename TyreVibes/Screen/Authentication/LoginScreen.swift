import AuthenticationServices
import SwiftUI

struct LoginScreen: View {
    
    @StateObject private var viewModel = LoginViewModel()
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var showPassword = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let screenHeight = geometry.size.height
                
                // Calcola le dimensioni dinamiche basate sullo schermo
                
                let buttonHeight = screenHeight * 0.075 // ~60pt
                let buttonFontSize = screenWidth * 0.045 // ~18pt
                let socialButtonHeight = screenHeight * 0.067 // ~56pt
                let socialButtonFontSize = screenWidth * 0.04 // ~16pt
                let iconSize = screenWidth * 0.05 // ~20pt
                
                ZStack {
                    // Background
                    Color.customBackgroundColor
                        .ignoresSafeArea()
                    
                    
                    VStack(spacing: 26) {
                        // Header
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
                        .padding(.bottom, 21)
                        
                        // Main Content
                        VStack(alignment: .leading, spacing: 30) {
                            //r Title Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack (spacing: 3){
                                    Text("Log In")
                                        .font(.customFont(size: 36, weight: .bold))
                                        .foregroundColor(.white)
                                        .font(.customFont(size: 12, weight: .bold))
                                    Circle()
                                        .fill(Color.customSandyBrown)
                                        .frame(width: 10, height: 10)
                                        .offset(y: 7)
                                }
                                
                                Text("Welcome back to TyreVibes!")
                                    .font(.customFont(size: 16, weight: .regular))
                                    .foregroundColor(.gray)
                                
                            }
                            .padding(.bottom, screenHeight * 0.045)
                            
                            
                            // Form Fields
                            VStack(spacing: 16) {
                                // Email Field
                                HStack {
                                    Image("EmailIcon")
                                        .foregroundColor(.white)
                                        .frame(height: 24)
                                    TextField("Enter Email", text: $viewModel.email)
                                        .frame(maxHeight: .infinity)
                                        .font(.customFont(size: 16, weight: .semibold))
                                        .disableAutocorrection(true)
                                        .foregroundColor(.white)
                                        .autocapitalization(.none)
                                    
                                    
                                }
                                .padding()
                                .background(Color.customFieldColor)
                                .cornerRadius(18)
                                .frame(height: 62)
                                
                                // Password Field
                                HStack {
                                    Image("PasswordIcon")
                                        .frame(height: 24)
                                    if showPassword {
                                        TextField("Enter Password", text: $viewModel.password)
                                            .frame(maxHeight: .infinity)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .autocapitalization(.none)
                                            .autocorrectionDisabled()
                                    }
                                    else{
                                        SecureField("Enter Password", text: $viewModel.password)
                                            .frame(maxHeight: .infinity)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .autocapitalization(.none)
                                            .autocorrectionDisabled()
                                    }
                                    
                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(.white)
                                    }
                                    
                                }
                                .padding()
                                .background(Color.customFieldColor)
                                .cornerRadius(18)
                                .frame(height: 62)
                            }
                            
                            // Remember Me & Forgot Password
                            HStack {
                                HStack(spacing: 0) {
                                    Toggle("", isOn: $viewModel.rememberMe)
                                        .labelsHidden()
                                        .toggleStyle(CheckboxToggleStyle())

                                    Text("Remember me")
                                        .foregroundColor(.white)
                                        .font(.customFont(size: 12, weight: .regular))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Spacer()
                                
                                NavigationLink(destination: ForgotPasswordScreen()) {
                                    Text("Forgot Password")
                                        .foregroundColor(.customBitterSweet)
                                        .font(.customFont(size: 14, weight: .semibold))
                                        .underline()
                                }
                                
                                
                            }
                            .padding(.top, -16)
                            
                            
                            
                            // Login Button
                            Button(action: {
                                viewModel.signIn()
                            }) {
                                Text("Log in")
                                    .font(.customFont(size: buttonFontSize, weight: .semibold))
                                    .foregroundColor(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: buttonHeight)
                                    .background(Color.customBitterSweet)
                                    .cornerRadius(screenWidth * 0.133)
                                    .opacity(viewModel.isLoading ? 0 : 1)
                                    .overlay {
                                        if viewModel.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                    }
                            }
                            .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty || viewModel.isLoading)
                            .opacity(viewModel.email.isEmpty || viewModel.password.isEmpty ? 0.6 : 1.0)
                            .padding(.bottom,screenHeight * -0.03)
                            .padding(.top, screenHeight * 0.25)
                            
                            // Or Continue With
                            HStack {
                                Rectangle()
                                    .fill(Color.customWhite.opacity(0.5))
                                    .frame(width: screenWidth * 0.25, height: 0.5)
                                
                                Text("Or Continue With")
                                    .font(.customFont(size: screenWidth * 0.032, weight: .regular)) // ~12pt
                                    .foregroundColor(.customWhite)
                                    .padding(.horizontal, screenWidth * 0.025)
                                
                                Rectangle()
                                    .fill(Color.customWhite.opacity(0.5))
                                    .frame(width: screenWidth * 0.25, height: 0.5)
                            }
                            .padding(.vertical, screenHeight * 0.02)
                            .padding(.bottom, screenHeight * -0.03)
                            
                            
                            // Social Login Buttons
                            HStack(spacing: screenWidth * 0.04) {
                                Button(action: {
                                    // Handle Google log in
                                }) {
                                    HStack {
                                        Image("GoogleIcon")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: iconSize, height: iconSize)
                                        
                                        Text("Google")
                                            .font(.customFont(size: socialButtonFontSize, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(SocialLoginButtonStyle(height: socialButtonHeight, cornerRadius: screenWidth * 0.075))
                                
                                Button(action: {
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first {
                                        viewModel.signInWithApple(presentationAnchor: window)
                                    }
                                }) {
                                    HStack {
                                        Image("AppleIcon")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: iconSize, height: iconSize)
                                        
                                        Text("Apple")
                                            .font(.customFont(size: socialButtonFontSize, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(SocialLoginButtonStyle(height: socialButtonHeight, cornerRadius: screenWidth * 0.075))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .alert(item: $viewModel.alertItem) { alertItem in
                Alert(title: Text(alertItem.title), message: Text(alertItem.message), dismissButton: .default(Text("OK")))
                }
            }
            .navigationBarHidden(true)
            
        }
        .preferredColorScheme(.dark)
        
    }
}

// MARK: - Reusable Components

private struct SocialLoginButtonStyle: ButtonStyle {
    let height: CGFloat
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                Color.customSocialButtonBackground.opacity(configuration.isPressed ? 0.5 : 0.3)
            )
            .cornerRadius(cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginScreen()
    }
}
