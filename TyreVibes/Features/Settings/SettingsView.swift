import SwiftUI
import UIKit

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var notificationStore = NotificationStore()
    @State private var showNotifications = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        AppBarView(
                            notificationCount: notificationStore.unreadCount,
                            onNotifications: { showNotifications = true },
                            onRefreshStats: { viewModel.refreshStats() }
                        )
                        .padding(.top, 10)

                        PerformanceSection(
                            backgroundSync: $viewModel.backgroundSync,
                            batteryOptimization: $viewModel.batteryOptimization,
                            imageQuality: $viewModel.imageQuality,
                            cacheManagement: $viewModel.cacheManagement,
                            stats: viewModel.stats,
                            imageQualityLabel: viewModel.imageQualityLabel
                        )
                        .padding(.top, 21)

                        SecuritySection(
                            biometricAuth: $viewModel.biometricAuth,
                            locationPermission: $viewModel.locationPermission,
                            cameraPermission: $viewModel.cameraPermission,
                            privacyLevel: $viewModel.privacyLevel,
                            onDataProtection: { viewModel.isPresentingDataProtection = true },
                            onExportData: { viewModel.exportMyData() }
                        )
                        .padding(.top, 24)

                        LanguageSection(selectedLanguage: $viewModel.selectedLanguage)
                            .padding(.top, 24)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationDestination(isPresented: $showNotifications) {
                NotificationScreen()
            }
            .sheet(isPresented: $viewModel.isPresentingDataProtection) {
                DataProtectionSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $viewModel.isPresentingShareSheet, onDismiss: { viewModel.dismissShareSheet() }) {
                ShareSheet(items: viewModel.shareItems)
            }
            .alert(item: $viewModel.alert) { alert in
                switch alert.style {
                case .info:
                    return Alert(
                        title: Text(alert.title.localized),
                        message: Text(alert.message.localized),
                        dismissButton: .default(Text("OK".localized))
                    )
                case .openSettings:
                    return Alert(
                        title: Text(alert.title.localized),
                        message: Text(alert.message.localized),
                        primaryButton: .default(Text("Open Settings".localized)) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        },
                        secondaryButton: .cancel(Text("Cancel".localized))
                    )
                }
            }
            .task {
                viewModel.onAppear()
            }
            .onChange(of: viewModel.backgroundSync) { oldValue, newValue in viewModel.handleBackgroundSyncChange() }
            .onChange(of: viewModel.batteryOptimization) { oldValue, newValue in viewModel.handleBatteryOptimizationChange() }
            .onChange(of: viewModel.imageQuality) { oldValue, newValue in viewModel.handleImageQualityChange() }
            .onChange(of: viewModel.cacheManagement) { oldValue, newValue in viewModel.handleCacheManagementChange() }
            .onChange(of: viewModel.biometricAuth) { oldValue, newValue in viewModel.handleBiometricChange() }
            .onChange(of: viewModel.privacyLevel) { oldValue, newValue in viewModel.handlePrivacyLevelChange() }
            .onChange(of: viewModel.selectedLanguage) { oldValue, newValue in viewModel.handleLanguageChange() }
            .onChange(of: viewModel.locationPermission) { oldValue, newValue in viewModel.handleLocationChange() }
            .onChange(of: viewModel.cameraPermission) { oldValue, newValue in viewModel.handleCameraChange() }
        }
    }
}

// MARK: - App Bar
struct AppBarView: View {
    let notificationCount: Int
    let onNotifications: () -> Void
    let onRefreshStats: () -> Void

    var body: some View {
        HStack {
            Text("Settings")
                .font(.customFont(size: 36, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 12) {
                Button(action: onRefreshStats) {
                    Image(systemName: "arrow.clockwise")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(glassCircle)
                }

                Button(action: onNotifications) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(glassCircle)

                        if notificationCount > 0 {
                            Text("\(min(notificationCount, 9))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 5)
                                .background(Capsule().fill(Color.customBitterSweet))
                                .offset(x: 10, y: -6)
                        }
                    }
                }
            }
        }
    }

    private var glassCircle: some View {
        ZStack {
            Circle()
                .fill(Color.customBackgroundColor)
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                .blur(radius: 1)
                .offset(x: 0.3, y: 1)
                .mask(
                    Circle().fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.black, .black]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                .clipShape(Circle())
                .padding(12)
                .blur(radius: 40)
                .opacity(0.8)
        }
    }
}

// MARK: - Performance Section
struct PerformanceSection: View {
    @Binding var backgroundSync: Bool
    @Binding var batteryOptimization: Bool
    @Binding var imageQuality: Double
    @Binding var cacheManagement: Bool

    let stats: SettingsViewModel.SettingsStats
    let imageQualityLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Performance & Optimization")
                .font(.custom("Sora-SemiBold", size: 22))
                .foregroundColor(.white)

            ToggleCard(
                title: "Background Synchronization",
                subtitle: "Keep data up to date when app is closed",
                isOn: $backgroundSync
            )

            ToggleCard(
                title: "Battery Optimization",
                subtitle: "Reduce background activities when battery is low",
                isOn: $batteryOptimization
            )

            GlassCard(height: 72) {
                HStack {
                    Text("Image Quality")
                        .font(.custom("Sora-SemiBold", size: 16))
                        .foregroundColor(.white)

                    Spacer()

                    Slider(value: $imageQuality, in: 0...1)
                        .frame(width: 130)
                        .tint(Color(hex: "5CEBFF"))

                    Text(imageQualityLabel)
                        .font(.custom("Sora-Regular", size: 14))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 18)
            }

            ToggleCard(
                title: "Image Cache Management",
                subtitle: "Automatically clear cached images to save space",
                isOn: $cacheManagement
            )

            HStack(spacing: 16) {
                StatCard(value: stats.appSize, label: "App Size")
                StatCard(value: stats.cacheSize, label: "Cache Size")
                StatCard(value: stats.batteryUsage, label: "Battery")
            }
        }
    }
}

// MARK: - Security Section
struct SecuritySection: View {
    @Binding var biometricAuth: Bool
    @Binding var locationPermission: Bool
    @Binding var cameraPermission: Bool
    @Binding var privacyLevel: PrivacyLevel

    let onDataProtection: () -> Void
    let onExportData: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Security and Privacy")
                .font(.custom("Sora-SemiBold", size: 22))
                .foregroundColor(.white)

            ToggleCard(
                title: "Biometric Authentication",
                subtitle: "Use Face ID or fingerprint to secure the app",
                isOn: $biometricAuth
            )

            ToggleCard(
                title: "Location Permission",
                subtitle: "Allow app to access your location",
                isOn: $locationPermission
            )

            ToggleCard(
                title: "Camera Permission",
                subtitle: "Allow app to access your camera for AR features",
                isOn: $cameraPermission
            )

            HStack(spacing: 16) {
                ForEach(PrivacyLevel.allCases, id: \.self) { level in
                    PrivacyLevelButton(
                        level: level,
                        isSelected: privacyLevel == level
                    ) {
                        privacyLevel = level
                    }
                }
            }

            Button(action: onDataProtection) {
                GlassCard(height: 100) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Data Protection")
                                .font(.custom("Sora-SemiBold", size: 16))
                                .foregroundColor(.white)

                            Text("View collected data and request deletion")
                                .font(.custom("Sora-Regular", size: 16))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 18)
                }
            }

            Button(action: onExportData) {
                GlassCard(height: 62, borderColor: Color(hex: "2FB8FF")) {
                    Text("Export My Data (GDPR)")
                        .font(.custom("Sora-Bold", size: 16))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Language Section
struct LanguageSection: View {
    @Binding var selectedLanguage: Language

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Language")
                .font(.custom("Sora-SemiBold", size: 22))
                .foregroundColor(.white)

            ForEach(Language.allCases, id: \.self) { language in
                LanguageCard(
                    language: language,
                    isSelected: selectedLanguage == language
                ) {
                    selectedLanguage = language
                }
            }
        }
    }
}

// MARK: - Reusable Components
struct GlassCard<Content: View>: View {
    let height: CGFloat
    let borderColor: Color
    let content: Content

    init(height: CGFloat, borderColor: Color = Color(hex: "5CEBFF").opacity(0.4), @ViewBuilder content: () -> Content) {
        self.height = height
        self.borderColor = borderColor
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "5CEBFF").opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(borderColor, lineWidth: 1)
                )

            content
        }
        .frame(height: height)
    }
}

struct ToggleCard: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        GlassCard(height: 100) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.custom("Sora-SemiBold", size: 16))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.custom("Sora-Regular", size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }
                .frame(width: 241)

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "2FB8FF")))
            }
            .padding(.horizontal, 18)
        }
    }
}

struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        GlassCard(height: 88) {
            VStack(spacing: 6) {
                Text(value)
                    .font(.custom("Sora-Bold", size: 16))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(label)
                    .font(.custom("Sora-Regular", size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PrivacyLevelButton: View {
    let level: PrivacyLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard(
                height: 62,
                borderColor: isSelected ? Color(hex: "2FB8FF") : Color(hex: "5CEBFF").opacity(0.4)
            ) {
                Text(level.rawValue)
                    .font(.custom(isSelected ? "Sora-Bold" : "Sora-Regular", size: 16))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct LanguageCard: View {
    let language: Language
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard(height: 62) {
                HStack {
                    Text(language.flag)
                        .font(.system(size: 24))

                    Text(language.name)
                        .font(.custom("Sora-SemiBold", size: 16))
                        .foregroundColor(.white)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "5CEBFF"))
                            .font(.system(size: 24))
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }
}

// MARK: - Models
enum PrivacyLevel: String, CaseIterable {
    case basic = "Basic"
    case balanced = "Balanced"
    case strict = "Strict"
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
