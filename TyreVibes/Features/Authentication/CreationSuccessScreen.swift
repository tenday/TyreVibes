import SwiftUI
import LocalAuthentication

struct CreationSuccessScreen: View {
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var goHome = false
    @State private var showFaceIDPrompt = false
    
    var body: some View {
        ZStack {
            // Background scuro
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack {
                // Animazione di successo nativa SwiftUI
                SuccessAnimationView()
                    .frame(width: 100, height: 100)
                    .padding(.top, 100)
                
                Spacer()
                
                // Contenuto principale
                VStack(spacing: 20) {
                    // Titolo principale
                    Text("Account Created Successfully!")
                        .font(.customFont(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                    
                    // Sottotitolo
                    Text("Congratulations your account has been successfully created.")
                        .font(.customFont(size: 16, weight: .regular))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineLimit(nil)
                }
                
                Spacer()
                
                // Pulsante Get Started
                Button(action: {
                    AppHaptics.impact(.light)
                    authenticateUser()
                }) {
                    Text("Get Started")
                        .font(.customFont(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(Color.customBitterSweet)
                        .cornerRadius(28)
                }
                .pressScaleButtonStyle()
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
            }
        }
        .navigationDestination(isPresented: $goHome) {
            BottomNavigationView()
                .navigationBarBackButtonHidden(true)
        }
        .alert("Enable Face ID?", isPresented: $showFaceIDPrompt) {
            Button("Yes") {
                viewModel.useFaceID = true
                UserDefaults.standard.set(true, forKey: "useFaceID")
                goHome = true
            }
            Button("No", role: .cancel) {
                viewModel.useFaceID = false
                UserDefaults.standard.set(false, forKey: "useFaceID")
                goHome = true
            }
        }
    }
    
    func authenticateUser() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Please authenticate to continue"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        showFaceIDPrompt = true
                    } else {
                        // Mostra un alert di errore
                        print("Authentication failed: \(authenticationError?.localizedDescription ?? "Unknown error")")
                        viewModel.useFaceID = false
                        UserDefaults.standard.set(false, forKey: "useFaceID")
                        goHome = true
                    }
                }
            }
        } else {
            // Nessun Face ID/Touch ID disponibile → fallback
            print("Biometric authentication not available")
            viewModel.useFaceID = false
            UserDefaults.standard.set(false, forKey: "useFaceID")
            goHome = true
        }
    }
    
    // Animazione pneumatico per TyreVibes
    struct SuccessAnimationView: View {
        @State private var showTyre = false
        @State private var tyreRotation: Double = 0
        @State private var showCheckmark = false
        @State private var checkmarkProgress: CGFloat = 0
        @State private var showSparks = false
        @State private var bounceEffect = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        
        var body: some View {
            ZStack (alignment: .center){
                // Pneumatico esterno (cerchio nero)
                Circle()
                    .stroke(Color.black, lineWidth: 25)
                    .frame(width: 140, height: 140)
                    .scaleEffect(showTyre ? 1.0 : 0.3)
                    .rotationEffect(.degrees(tyreRotation))
                    .opacity(showTyre ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6), value: showTyre)
                
                // Cerchio interno del pneumatico (grigio scuro)
                Circle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 100, height: 100)
                    .scaleEffect(showTyre ? 1.0 : 0.3)
                    .opacity(showTyre ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(0.1), value: showTyre)
                
                // Cerchio centrale (cromato/argento)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color.white, Color.gray]),
                            center: .center,
                            startRadius: 10,
                            endRadius: 30
                        )
                    )
                    .frame(width: 60, height: 60)
                    .scaleEffect(showTyre ? 1.0 : 0.3)
                    .opacity(showTyre ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: showTyre)
                
                // Pattern del battistrada (linee decorative)
                ForEach(0..<12, id: \.self) { index in
                    Circle()
                        .frame(width: 5, height: 25)
                        .offset(y: -70)
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(Double(index) * 30 + tyreRotation))
                        .opacity(showTyre ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.6).delay(0.3), value: showTyre)
                }
                
                CheckmarkShape()
                    .trim(from: 0, to: checkmarkProgress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    .frame(width: 36, height: 28)
                    .scaleEffect(showCheckmark ? (bounceEffect ? 1.12 : 1.0) : 0.2)
                    .opacity(showCheckmark ? 1.0 : 0.0)
                    .animation(reduceMotion ? nil : AppMotion.emphasized, value: showCheckmark)
                    .animation(reduceMotion ? nil : AppMotion.quick, value: bounceEffect)
                
                // Scintille/particelle intorno al pneumatico
                ForEach(0..<6, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.yellow)
                        .offset(
                            x: cos(Double(index) * .pi / 3) * (showSparks ? 90 : 60),
                            y: sin(Double(index) * .pi / 3) * (showSparks ? 90 : 60)
                        )
                        .opacity(showSparks ? 0.0 : (showCheckmark ? 1.0 : 0.0))
                        .scaleEffect(showSparks ? 1.5 : 1.0)
                        .animation(reduceMotion ? nil : .easeOut(duration: 1.0).delay(0.2), value: showSparks)
                }
            }
            .onAppear {
                // Sequenza di animazioni a tema pneumatico
                withAnimation(reduceMotion ? nil : AppMotion.emphasized) {
                    showTyre = true
                }
                
                // Rotazione controllata del pneumatico durante il reveal
                withAnimation(reduceMotion ? nil : .easeOut(duration: 1.1).delay(0.2)) {
                    tyreRotation = 540
                }
                
                withAnimation(reduceMotion ? nil : AppMotion.emphasized.delay(0.8)) {
                    showCheckmark = true
                }
                
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35).delay(0.9)) {
                    checkmarkProgress = 1
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                    AppHaptics.success()
                    withAnimation(reduceMotion ? nil : AppMotion.quick) {
                        bounceEffect = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(reduceMotion ? nil : AppMotion.quick) {
                            bounceEffect = false
                        }
                    }
                }

                withAnimation(reduceMotion ? nil : .easeOut(duration: 1.0).delay(1.15)) {
                    showSparks = true
                }
            }
        }

        struct CheckmarkShape: Shape {
            func path(in rect: CGRect) -> Path {
                var path = Path()
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.width * 0.36, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                return path
            }
        }
        
        struct PasswordRequirementRow: View {
            let requirement: PasswordRequirement
            
            var body: some View {
                HStack(spacing: 8) {
                    Image(systemName: requirement.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(requirement.isValid ? .green : .red)
                    
                    Text(requirement.text)
                        .font(.customFont(size: 12, weight: .regular))
                        .foregroundColor(requirement.isValid ? .green : .white)
                        .strikethrough(!requirement.isValid, color: .gray)
                    
                    Spacer()
                }
            }
        }
    }
    
    struct AccountCreatedView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationStack {
                CreationSuccessScreen()
            }
        }
    }
}
