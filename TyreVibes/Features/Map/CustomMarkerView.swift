import SwiftUI

struct CustomMarkerView: View {
    var isSelected: Bool = false
    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.customAzure.opacity(0.85), .customBlue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 56, height: 56)
                    .scaleEffect(pulseAnimation ? 1.25 : 0.95)
                    .opacity(pulseAnimation ? 0.15 : 0.45)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.customBlue.opacity(isSelected ? 0.45 : 0.25),
                            Color.customPurple.opacity(isSelected ? 0.6 : 0.3)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 28
                    )
                )
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 5)
                .overlay(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 42, height: 42)
                )

            Image("garageMenu")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 4)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(
            .spring(response: 0.45, dampingFraction: isSelected ? 0.7 : 0.9),
            value: isSelected
        )
        .onAppear {
            if isSelected {
                startPulseAnimation()
            }
        }
        .onChange(of: isSelected) { newValue in
            if newValue {
                startPulseAnimation()
            }
        }
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
    }
}

struct CustomMarkerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            CustomMarkerView()
            CustomMarkerView(isSelected: true)
        }
        .padding()
        .background(Color.customBackgroundColor)
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}
