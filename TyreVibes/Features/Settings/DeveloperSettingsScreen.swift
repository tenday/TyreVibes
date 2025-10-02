import SwiftUI

/// Schermata impostazioni sviluppatore con feature flags
struct DeveloperSettingsScreen: View {
    @StateObject private var featureFlags = FeatureFlags.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView

                        // Feature Flags Section
                        featureFlagsSection

                        // Actions Section
                        actionsSection

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 60))
                .foregroundColor(.cyan)
                .padding(.top, 20)

            Text(L10n.developerSettings.localized)
                .font(.customFont(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text(L10n.configureFeatureFlags.localized)
                .font(.customFont(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Feature Flags
    private var featureFlagsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.featureFlags.localized)
                    .font(.customFont(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            VStack(spacing: 12) {
                // Paywall Toggle
                FeatureToggleRow(
                    icon: "crown.fill",
                    title: "Paywall System",
                    description: "Enable premium features paywall",
                    isEnabled: $featureFlags.isPaywallEnabled,
                    color: .yellow
                )

                // Notifications Toggle
                FeatureToggleRow(
                    icon: "bell.fill",
                    title: "Push Notifications",
                    description: "Enable push notifications",
                    isEnabled: $featureFlags.isNotificationsEnabled,
                    color: .orange
                )

                // Cloud Sync Toggle
                FeatureToggleRow(
                    icon: "cloud.fill",
                    title: "Cloud Sync",
                    description: "Enable cloud synchronization",
                    isEnabled: $featureFlags.isCloudSyncEnabled,
                    color: .blue
                )

                // Analytics Toggle
                FeatureToggleRow(
                    icon: "chart.bar.fill",
                    title: "Analytics",
                    description: "Enable usage analytics",
                    isEnabled: $featureFlags.isAnalyticsEnabled,
                    color: .green
                )

                // Debug Mode Toggle
                FeatureToggleRow(
                    icon: "ladybug.fill",
                    title: "Debug Mode",
                    description: "Show debug information",
                    isEnabled: $featureFlags.isDebugMode,
                    color: .red
                )
            }
        }
    }

    // MARK: - Actions
    private var actionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.actions.localized)
                    .font(.customFont(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            VStack(spacing: 12) {
                // Reset to defaults
                Button(action: {
                    featureFlags.resetToDefaults()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.resetToDefaults.localized)
                                .font(.customFont(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Text(L10n.resetAllFeatureFlags.localized)
                                .font(.customFont(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Clear Cache
                Button(action: {
                    clearAppCache()
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.clearCache.localized)
                                .font(.customFont(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Text(L10n.clearAllCachedData.localized)
                                .font(.customFont(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Actions
    private func clearAppCache() {
        UserDefaults.standard.removeObject(forKey: "cachedVehicles")
        // Aggiungi altre operazioni di pulizia cache
    }
}

// MARK: - Feature Toggle Row
struct FeatureToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(color)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEnabled ? color.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

#Preview {
    DeveloperSettingsScreen()
}
