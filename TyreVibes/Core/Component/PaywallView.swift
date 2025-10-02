import SwiftUI

/// Vista del paywall che blocca funzionalità premium
struct PaywallView: View {
    let feature: PremiumFeature
    let onDismiss: () -> Void
    let onUpgrade: () -> Void

    @StateObject private var paywallManager = PaywallManager.shared

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Card content
                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: feature.icon)
                            .font(.system(size: 50))
                            .foregroundColor(.yellow)
                    }
                    .shadow(color: .yellow.opacity(0.3), radius: 20, x: 0, y: 10)

                    // Title
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.yellow)

                            Text("Premium Feature")
                                .font(.customFont(size: 14, weight: .semibold))
                                .foregroundColor(.yellow)
                        }

                        Text(feature.title)
                            .font(.customFont(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }

                    // Description
                    Text(paywallManager.getLimitMessage(for: feature))
                        .font(.customFont(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 8)

                    // Benefits list
                    VStack(spacing: 12) {
                        BenefitRow(text: "Unlimited access to all features")
                        BenefitRow(text: "Priority customer support")
                        BenefitRow(text: "Ad-free experience")
                        BenefitRow(text: "Cloud sync across devices")
                    }
                    .padding(.top, 8)

                    // Buttons
                    VStack(spacing: 12) {
                        // Upgrade button
                        Button(action: onUpgrade) {
                            HStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 18))

                                Text("Upgrade to Premium")
                                    .font(.customFont(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.yellow, Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .yellow.opacity(0.4), radius: 15, x: 0, y: 8)
                        }

                        // Dismiss button
                        Button(action: onDismiss) {
                            Text("Maybe Later")
                                .font(.customFont(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.customBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.yellow.opacity(0.5), Color.orange.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)

                Spacer()
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

/// Riga di beneficio nel paywall
struct BenefitRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.green)

            Text(text)
                .font(.customFont(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Vista compatta del paywall per limiti raggiunti
struct CompactPaywallView: View {
    let feature: PremiumFeature
    let onUpgrade: () -> Void

    @StateObject private var paywallManager = PaywallManager.shared

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Limit Reached")
                        .font(.customFont(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(paywallManager.getLimitMessage(for: feature))
                        .font(.customFont(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }

                Spacer()
            }

            Button(action: onUpgrade) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))

                    Text("Upgrade")
                        .font(.customFont(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.customBackgroundColor.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
    }
}

#Preview("Full Paywall") {
    PaywallView(
        feature: .unlimitedVehicles,
        onDismiss: {},
        onUpgrade: {}
    )
}

#Preview("Compact Paywall") {
    ZStack {
        Color.customBackgroundColor
            .ignoresSafeArea()

        VStack {
            Spacer()
            CompactPaywallView(
                feature: .unlimitedTires,
                onUpgrade: {}
            )
            Spacer()
        }
    }
}
