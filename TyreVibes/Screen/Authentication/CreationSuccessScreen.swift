import SwiftUI

struct CreationSuccessScreen: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background scuro
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack {
                // Top bar con freccia indietro
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Animazione di successo nativa SwiftUI
                SuccessAnimationView()
                    .frame(width: 100, height: 100)
                    .padding(.top, 60)
                
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
                    // Azione per iniziare
                    print("Get Started tapped")
                }) {
                    Text("Get Started")
                        .font(.customFont(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(Color.customBitterSweet)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
            }
        }
        .navigationBarHidden(true)
    }
}

// Animazione pneumatico per TyreVibes
struct SuccessAnimationView: View {
    @State private var showTyre = false
    @State private var tyreRotation: Double = 0
    @State private var showCheckmark = false
    @State private var showSparks = false
    @State private var bounceEffect = false
    
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
            
            // Checkmark di successo al centro
            Image(systemName: "checkmark")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.green)
                .scaleEffect(showCheckmark ? (bounceEffect ? 1.2 : 1.0) : 0.1)
                .opacity(showCheckmark ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0), value: showCheckmark)
                .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: bounceEffect)
            
            // Scintille/particelle intorno al pneumatico
            ForEach(0..<6, id: \.self) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.yellow)
                    .offset(
                        x: cos(Double(index) * .pi / 3) * (showSparks ? 90 : 60),
                        y: sin(Double(index) * .pi / 3) * (showSparks ? 90 : 60)
                    )
                    .opacity(showSparks ? 0.0 : 1.0)
                    .scaleEffect(showSparks ? 1.5 : 1.0)
                    .animation(.easeOut(duration: 1.2).delay(0.7), value: showSparks)
            }
        }
        .onAppear {
            // Sequenza di animazioni a tema pneumatico
            withAnimation(.easeOut(duration: 0.6)) {
                showTyre = true
            }
            
            // Rotazione continua del pneumatico
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false).delay(0.6)) {
                tyreRotation = 360
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(1.0)) {
                showCheckmark = true
            }
            
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true).delay(1.2)) {
                bounceEffect = true
            }
            
            withAnimation(.easeOut(duration: 1.2).delay(1.3)) {
                showSparks = true
            }
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
        CreationSuccessScreen()
    }
}
