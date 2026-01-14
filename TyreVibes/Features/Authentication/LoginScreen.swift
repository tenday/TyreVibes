import AuthenticationServices
import SwiftUI
import LocalAuthentication

struct LoginScreen: View {

    @StateObject private var viewModel = LoginViewModel()

    @Environment(\.dismiss) private var dismiss

    @State private var showPassword = false
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var showAlert = false
    @State private var baseLayoutHeight: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let screenHeight = geometry.size.height
                let layoutHeight = baseLayoutHeight == 0 ? screenHeight : baseLayoutHeight
                
                // Calcola le dimensioni dinamiche basate sullo schermo
                
                let buttonHeight = layoutHeight * 0.075 // ~60pt
                let buttonFontSize = screenWidth * 0.045 // ~18pt
                let socialButtonHeight = layoutHeight * 0.067 // ~56pt
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
                                Image(systemName: "chevron.left")
                                    .resizable()
                                    .frame(width: 15, height: 24)
                                    .foregroundColor(.white)
                            }
                            .accessibilityLabel("Indietro")
                            .accessibilityHint("Torna alla schermata precedente")
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
                            .padding(.bottom, layoutHeight * 0.045)
                            
                            
                            // Form Fields
                            VStack(spacing: 16) {
                                // Email Field
                                HStack {
                                    Image("EmailIcon")
                                        .foregroundColor(.white)
                                        .frame(height: 24)
                                        .accessibilityHidden(true)
                                    TextField("Enter Email", text: $viewModel.email)
                                        .frame(maxHeight: .infinity)
                                        .font(.customFont(size: 16, weight: .semibold))
                                        .disableAutocorrection(true)
                                        .foregroundColor(.white)
                                        .autocapitalization(.none)
                                        .accessibilityLabel("Email")
                                        .accessibilityHint("Inserisci il tuo indirizzo email")


                                }
                                .padding()
                                .background(Color.customFieldColor)
                                .cornerRadius(18)
                                .frame(height: 62)
                                
                                // Password Field
                                HStack {
                                    Image("PasswordIcon")
                                        .frame(height: 24)
                                        .accessibilityHidden(true)
                                    if showPassword {
                                        TextField("Enter Password", text: $viewModel.password)
                                            .frame(maxHeight: .infinity)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .autocapitalization(.none)
                                            .autocorrectionDisabled()
                                            .accessibilityLabel("Password")
                                            .accessibilityHint("Inserisci la tua password")
                                    }
                                    else{
                                        SecureField("Enter Password", text: $viewModel.password)
                                            .frame(maxHeight: .infinity)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .autocapitalization(.none)
                                            .autocorrectionDisabled()
                                            .accessibilityLabel("Password")
                                            .accessibilityHint("Inserisci la tua password")
                                    }

                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(.white)
                                    }
                                    .accessibilityLabel(showPassword ? "Nascondi password" : "Mostra password")
                                    .accessibilityHint("Attiva per " + (showPassword ? "nascondere" : "mostrare") + " la password")

                                }
                                .padding()
                                .background(Color.customFieldColor)
                                .cornerRadius(18)
                                .frame(height: 62)
                            }
                            
                            // Remember Me & Face ID
                            VStack(spacing: 8) {
                                HStack {
                                    HStack(spacing: 0) {
                                        Toggle("", isOn: $viewModel.rememberMe)
                                            .labelsHidden()
                                            .toggleStyle(CheckboxToggleStyle())
                                            .accessibilityLabel("Ricordami")
                                            .accessibilityHint("Mantieni l'accesso per le prossime sessioni")

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
                                    .accessibilityLabel("Password dimenticata")
                                    .accessibilityHint("Vai alla schermata per recuperare la password")
                                }

                            }
                            .padding(.top, -16)
                            
                            
                            // Login Button
                            Button(action: {
                                viewModel.signIn()
                                if viewModel.alertItem == nil && !viewModel.isLoading {
                                    viewModel.email = ""
                                    viewModel.password = ""
                                }
                            }) {
                                if viewModel.isLoading {
                                    Text("")
                                        .foregroundColor(Color.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: buttonHeight)
                                        .background(Color.customBitterSweet)
                                        .cornerRadius(screenWidth * 0.133)
                                        .overlay(ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.2)
                                            .frame(maxWidth: .infinity))
                                        .disabled(true)
                                }
                                else {
                                    Text("Log in")
                                        .font(.customFont(size: buttonFontSize, weight: .semibold))
                                        .foregroundColor(Color.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: buttonHeight)
                                        .background(Color.customBitterSweet)
                                        .cornerRadius(screenWidth * 0.133)
                                        .opacity(viewModel.isLoading ? 0 : 1)
                                }
                                
                                
                            }
                            .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty || viewModel.isLoading)
                            .opacity(viewModel.email.isEmpty || viewModel.password.isEmpty ? 0.6 : 1.0)
                            .padding(.bottom, layoutHeight * -0.03)
                            .padding(.top, layoutHeight * 0.25)
                            
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
                            .padding(.vertical, layoutHeight * 0.02)
                            .padding(.bottom, layoutHeight * -0.03)
                            
                            
                            // Social Login Buttons
                            VStack(spacing: screenWidth * 0.04) {
                                HStack(spacing: screenWidth * 0.04) {
                                    Button(action: {
                                        viewModel.signInWithGoogle()
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
                                    .accessibilityLabel("Accedi con Google")
                                    .accessibilityHint("Usa il tuo account Google per accedere")

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
                                    .accessibilityLabel("Accedi con Apple")
                                    .accessibilityHint("Usa il tuo Apple ID per accedere")
                                }

                                Button(action: {
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first {
                                        viewModel.signInWithPasskey(presentationAnchor: window)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .font(.system(size: iconSize))
                                            .foregroundColor(.white)

                                        Text("Passkey")
                                            .font(.customFont(size: socialButtonFontSize, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(SocialLoginButtonStyle(height: socialButtonHeight, cornerRadius: screenWidth * 0.075))
                                .accessibilityLabel("Accedi con passkey")
                                .accessibilityHint("Usa una passkey per accedere più velocemente")
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .onAppear {
                    if baseLayoutHeight == 0 {
                        baseLayoutHeight = screenHeight
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onReceive(viewModel.$alertItem) { newValue in
                showAlert = newValue != nil
            }
            .onAppear {
                viewModel.attemptAutoLogin()
            }
            .customAlert(
                isPresented: $showAlert,
                title: viewModel.alertItem?.title ?? "Error",
                message: viewModel.alertItem?.message ?? "An unknown error occurred.",
                showprogress: false,
                primaryButtonTitle: "OK",
                primaryButtonAction: {
                    viewModel.alertItem = nil
                    showAlert = false
                }
            )
            .navigationDestination(isPresented: $viewModel.showHomeScreen) {
                BottomNavigationView()
                    .navigationBarBackButtonHidden(true)
            }
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
        }
        .background(InteractivePopGestureEnabler())
        .preferredColorScheme(.dark)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
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
