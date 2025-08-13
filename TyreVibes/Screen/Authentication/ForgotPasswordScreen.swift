import SwiftUI

struct ForgotPasswordScreen: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    
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
                        VStack(alignment: .leading, spacing: 4) {
                            // Title and Description Section
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Forgot Password")
                                    .font(.customFont(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.top, 30)
                                
                                Text("Enter the email associated with your account and we'll send an OTP to reset your password.")
                                    .font(.customFont(size: 16, weight: .regular))
                                    .foregroundColor(.gray)
                                    .lineSpacing(4)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.bottom, 60)
                            
                            // Email Field
                            HStack {
                                Image("EmailIcon")
                                    .foregroundColor(.gray)
                                    .frame(height: 24)
                                
                                TextField("Enter Email", text: $email)
                                    .frame(maxHeight: .infinity)
                                    .font(.customFont(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding()
                            .background(Color.customFieldColor)
                            .cornerRadius(18)
                            .frame(height: 62)
                            

                            
                            // Send Button
                            Button(action: {
                                // Send OTP action
                                print("Send OTP to email: \(email)")
                                // Qui puoi aggiungere la logica per inviare l'OTP
                            }) {
                                Text("Send")
                                    .font(.customFont(size: buttonFontSize, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: buttonHeight)
                                    .background(
                                        email.isEmpty ?
                                        Color.customBitterSweet.opacity(0.6) :
                                        Color.customBitterSweet
                                    )
                                    .cornerRadius(screenWidth * 0.133)
                            }
                            .disabled(email.isEmpty)
                            .animation(.easeInOut(duration: 0.2), value: email.isEmpty)
                            .padding(.top, 20)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        //.padding(.bottom, 50)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
    }
}

struct ForgotPasswordScreen_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordScreen()
    }
}
