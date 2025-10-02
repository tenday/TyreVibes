import SwiftUI
import StoreKit

struct PremiumSubscriptionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = FullSubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.customBackgroundColor,
                    Color(hex: "#1a1a2e"),
                    Color(hex: "#16213e")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Premium Features
                    premiumFeaturesView
                        .padding(.top, 40)

                    // Subscription Plans
                    subscriptionPlansView
                        .padding(.top, 40)

                    // CTA Button
                    ctaButtonView
                        .padding(.top, 40)

                    // Restore Purchases
                    restorePurchasesButton
                        .padding(.top, 20)

                    // Terms and Privacy
                    legalLinksView
                        .padding(.top, 30)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)

            // Loading Overlay
            if subscriptionManager.isLoading {
                loadingOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
        }
        .task {
            await subscriptionManager.refreshProductsAndStatus()
        }
        .alert("Success!", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(L10n.welcomeToPremium.localized)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            // Premium Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: .yellow.opacity(0.5), radius: 20, x: 0, y: 10)

                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            .padding(.top, 60)

            Text(L10n.tyreVibesPremium.localized)
                .font(.customFont(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text(L10n.unlockFullPotential.localized)
                .font(.customFont(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Premium Features
    private var premiumFeaturesView: some View {
        VStack(spacing: 20) {
            Text(L10n.premiumFeatures.localized)
                .font(.customFont(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                FeatureRow(
                    icon: "car.2.fill",
                    title: "Unlimited Vehicles",
                    description: "Add as many vehicles as you want to your garage"
                )

                FeatureRow(
                    icon: "camera.fill",
                    title: "Advanced OCR Scanning",
                    description: "Automatically extract tire data with AI-powered recognition"
                )

                FeatureRow(
                    icon: "bell.badge.fill",
                    title: "Smart Notifications",
                    description: "Get timely reminders for maintenance, insurance, and tire changes"
                )

                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Detailed Analytics",
                    description: "Track maintenance costs, tire wear, and vehicle history"
                )

                FeatureRow(
                    icon: "cloud.fill",
                    title: "Cloud Sync",
                    description: "Access your data seamlessly across all your devices"
                )

                FeatureRow(
                    icon: "sparkles",
                    title: "Priority Support",
                    description: "Get help from our support team whenever you need it"
                )
            }
        }
    }

    // MARK: - Subscription Plans
    private var subscriptionPlansView: some View {
        VStack(spacing: 16) {
            Text(L10n.chooseYourPlan.localized)
                .font(.customFont(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            if subscriptionManager.availableProducts.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text(L10n.loadingPlans.localized)
                        .font(.customFont(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(subscriptionManager.availableProducts.sorted(by: { $0.price < $1.price }), id: \.id) { product in
                        SubscriptionPlanCard(
                            product: product,
                            isSelected: selectedProduct?.id == product.id,
                            isPopular: product.id.contains("yearly")
                        ) {
                            selectedProduct = product
                        }
                    }
                }
            }
        }
    }

    // MARK: - CTA Button
    private var ctaButtonView: some View {
        Button(action: {
            Task {
                await purchaseSubscription()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))

                Text(selectedProduct != nil ? "Subscribe Now" : "Select a Plan")
                    .font(.customFont(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: selectedProduct != nil ? [Color.yellow, Color.orange] : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: selectedProduct != nil ? Color.yellow.opacity(0.4) : Color.clear, radius: 15, x: 0, y: 8)
        }
        .disabled(selectedProduct == nil || subscriptionManager.isLoading)
    }

    // MARK: - Restore Purchases
    private var restorePurchasesButton: some View {
        Button(action: {
            Task {
                await subscriptionManager.restorePurchases()
                if subscriptionManager.status.isActive {
                    showSuccessAlert = true
                } else if subscriptionManager.lastError != nil {
                    errorMessage = subscriptionManager.lastError?.localizedDescription ?? "Failed to restore purchases"
                    showErrorAlert = true
                }
            }
        }) {
            Text(L10n.restorePurchases.localized)
                .font(.customFont(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .underline()
        }
        .disabled(subscriptionManager.isLoading)
    }

    // MARK: - Legal Links
    private var legalLinksView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("By subscribing, you agree to our")
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))

                Button(action: {
                    // Open Terms of Service
                }) {
                    Text("Terms")
                        .font(.customFont(size: 12, weight: .regular))
                        .foregroundColor(.cyan)
                        .underline()
                }
            }

            HStack(spacing: 4) {
                Text("and")
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))

                Button(action: {
                    // Open Privacy Policy
                }) {
                    Text("Privacy Policy")
                        .font(.customFont(size: 12, weight: .regular))
                        .foregroundColor(.cyan)
                        .underline()
                }
            }

            Text("Subscription auto-renews until cancelled")
                .font(.customFont(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(L10n.processing.localized)
                    .font(.customFont(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.customBackgroundColor)
            )
        }
    }

    // MARK: - Purchase Function
    private func purchaseSubscription() async {
        guard let product = selectedProduct else { return }

        let success = await subscriptionManager.purchase(product: product)

        if success {
            showSuccessAlert = true
        } else if let error = subscriptionManager.lastError {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - Feature Row Component
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.cyan)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.customFont(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Subscription Plan Card Component
struct SubscriptionPlanCard: View {
    let product: Product
    let isSelected: Bool
    let isPopular: Bool
    let onTap: () -> Void

    private var periodText: String {
        if product.id.contains("yearly") {
            return "per year"
        } else if product.id.contains("monthly") {
            return "per month"
        }
        return ""
    }

    private var savingsText: String? {
        if product.id.contains("yearly") {
            return "Save 20%"
        }
        return nil
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Popular Badge
                if isPopular {
                    HStack {
                        Spacer()
                        Text("MOST POPULAR")
                            .font(.customFont(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [Color.yellow, Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8, corners: [.topRight])
                        Spacer()
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(product.displayName)
                            .font(.customFont(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(product.displayPrice)
                                .font(.customFont(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            Text(periodText)
                                .font(.customFont(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        if let savings = savingsText {
                            Text(savings)
                                .font(.customFont(size: 12, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }

                    Spacer()

                    // Selection Indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.cyan : Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 28, height: 28)

                        if isSelected {
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 20, height: 20)

                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(20)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.cyan.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.cyan : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationStack {
        PremiumSubscriptionScreen()
    }
}
