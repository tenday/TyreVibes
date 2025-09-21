import SwiftUI

struct CustomAlertView: View {
    let title: String
    let showProgress: Bool

    @State private var showAlert = false
    @State private var displayedText = ""
    @State private var scale: CGFloat = 1.0
    @State private var showText = false

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                if showText {
                    Text(displayedText)
                        .font(.customFont(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                if showProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }

            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    // Base glass capsule
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: .black.opacity(0.3),
                            radius: 10,
                            x: 0,
                            y: 5
                        )

                    // Subtle inner glow
                    Capsule()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(0.1),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .opacity(0.8)
                }
                .opacity(showText ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: showText)
            )
            .offset(y: showAlert ? 40 : -UIScreen.main.bounds.height)
            .scaleEffect(scale)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showAlert)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            showAlert = true
            scale = 1.0
            displayedText = ""
            showText = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showText = true
                var currentIndex = 0
                Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
                    if currentIndex < title.count {
                        let index = title.index(title.startIndex, offsetBy: currentIndex)
                        displayedText.append(title[index])
                        currentIndex += 1
                    } else {
                        timer.invalidate()
                        if !showProgress {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scale = 0
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showAlert = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct CustomAlertView_Previews: PreviewProvider {
    static var previews: some View {
        CustomAlertView(
            title: "Credenziali non valide",
            showProgress: true
        )

    }
}