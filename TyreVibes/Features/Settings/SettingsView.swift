import SwiftUI
import UIKit
import StoreKit

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var notificationStore: NotificationStore
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

                        CacheManagementSection(
                            stats: viewModel.stats,
                            onClearImageCache: { viewModel.clearImageCache() },
                            onClearVehicleCache: { viewModel.clearVehicleCache() },
                            onClearTyreCache: { viewModel.clearTyreCache() },
                            onClearTempFiles: { viewModel.clearTempFiles() },
                            onClearAllCaches: { viewModel.clearCaches() }
                        )
                        .padding(.top, 24)

                        SecuritySection(
                            biometricAuth: $viewModel.biometricAuth,
                            locationPermission: $viewModel.locationPermission,
                            cameraPermission: $viewModel.cameraPermission,
                            privacyLevel: $viewModel.privacyLevel,
                            onDataProtection: { viewModel.isPresentingDataProtection = true },
                            onPasskey: { viewModel.registerPasskey() },
                            onExportData: { viewModel.exportMyData() }
                        )
                        .padding(.top, 24)

                        LanguageSection(selectedLanguage: $viewModel.selectedLanguage)
                            .padding(.top, 24)

                        NotificationsSection(
                            notificationsEnabled: $viewModel.notificationsEnabled,
                            promotionNotifications: $viewModel.promotionNotifications,
                            updateNotifications: $viewModel.updateNotifications,
                            analysisNotifications: $viewModel.analysisNotifications
                        )
                        .padding(.top, 24)

                        AppearanceSection(selectedTheme: $viewModel.selectedTheme)
                            .padding(.top, 24)

                        AccountSection(
                            onLogout: { viewModel.isPresentingLogoutConfirmation = true },
                            onExportData: { viewModel.exportMyData() },
                            onDeleteAccount: { viewModel.requestDataDeletion() }
                        )
                        .padding(.top, 24)

                        AboutSection()
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
            .confirmationDialog(
                "Conferma Logout".localized,
                isPresented: $viewModel.isPresentingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Logout".localized, role: .destructive) {
                    viewModel.logout()
                }
                Button("Annulla".localized, role: .cancel) {}
            } message: {
                Text("Sei sicuro di voler effettuare il logout? Dovrai accedere nuovamente per utilizzare l'app.".localized)
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
            .onChange(of: viewModel.notificationsEnabled) { oldValue, newValue in viewModel.handleNotificationsEnabledChange() }
            .onChange(of: viewModel.promotionNotifications) { oldValue, newValue in viewModel.handlePromotionNotificationsChange() }
            .onChange(of: viewModel.updateNotifications) { oldValue, newValue in viewModel.handleUpdateNotificationsChange() }
            .onChange(of: viewModel.analysisNotifications) { oldValue, newValue in viewModel.handleAnalysisNotificationsChange() }
            .onChange(of: viewModel.selectedTheme) { oldValue, newValue in viewModel.handleThemeChange() }
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
            Text("Settings".localized)
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
                .accessibilityLabel("Aggiorna statistiche".localized)
                .accessibilityHint("Ricarica le statistiche dell'app".localized)

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
                .accessibilityLabel(notificationsAccessibilityLabel)
                .accessibilityHint("Apri il centro notifiche".localized)
            }
        }
    }

    private var notificationsAccessibilityLabel: String {
        if notificationCount > 0 {
            return String(format: "Notifiche, %d non lette".localized, notificationCount)
        }
        return "Notifiche".localized
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
            Text("Performance & Optimization".localized)
                .font(.custom("Sora-SemiBold", size: 22))
                .foregroundColor(.white)

            ToggleCard(
                title: "Background Synchronization".localized,
                subtitle: "Keep data up to date when app is closed".localized,
                isOn: $backgroundSync
            )

            ToggleCard(
                title: "Battery Optimization".localized,
                subtitle: "Reduce background activities when battery is low".localized,
                isOn: $batteryOptimization
            )

            GlassCard(height: 72) {
                HStack {
                    Text("Image Quality".localized)
                        .font(.custom("Sora-SemiBold", size: 16))
                        .foregroundColor(.white)

                    Spacer()

                    Slider(value: $imageQuality, in: 0...1)
                        .frame(width: 130)
                        .tint(Color(hex: "5CEBFF"))

                    Text(imageQualityLabel.localized)
                        .font(.custom("Sora-Regular", size: 14))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 18)
            }

            ToggleCard(
                title: "Image Cache Management".localized,
                subtitle: "Automatically clear cached images to save space".localized,
                isOn: $cacheManagement
            )

            HStack(spacing: 16) {
                StatCard(value: stats.appSize, label: "App Size".localized)
                StatCard(value: stats.cacheSize, label: "Cache Size".localized)
                StatCard(value: stats.batteryUsage, label: "Battery".localized)
            }
        }
    }
}

// MARK: - Cache Management Section
struct CacheManagementSection: View {
    let stats: SettingsViewModel.SettingsStats
    let onClearImageCache: () -> Void
    let onClearVehicleCache: () -> Void
    let onClearTyreCache: () -> Void
    let onClearTempFiles: () -> Void
    let onClearAllCaches: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Gestione Cache".localized)
                .font(.custom("Sora-SemiBold", size: 22))
                .foregroundColor(.white)

            // Cache Statistics
            VStack(spacing: 12) {
                CacheStatRow(label: "Cache Immagini".localized, size: stats.imageCacheSize, icon: "photo.fill")
                CacheStatRow(label: "Cache Veicoli".localized, size: stats.vehicleCacheSize, icon: "car.fill")
                CacheStatRow(label: "File Temporanei".localized, size: stats.tempFilesSize, icon: "doc.fill")
            }

            // Individual Clear Buttons
            VStack(spacing: 12) {
                CacheButton(
                    title: "Pulisci Cache Immagini".localized,
                    icon: "photo.on.rectangle.angled",
                    size: stats.imageCacheSize,
                    action: onClearImageCache
                )

                CacheButton(
                    title: "Pulisci Cache Veicoli".localized,
                    icon: "car.2",
                    size: stats.vehicleCacheSize,
                    action: onClearVehicleCache
                )

                CacheButton(
                    title: "Pulisci Cache Pneumatici".localized,
                    icon: "circle.hexagongrid.fill",
                    size: "—",
                    action: onClearTyreCache
                )

                CacheButton(
                    title: "Pulisci File Temporanei".localized,
                    icon: "doc.badge.gearshape",
                    size: stats.tempFilesSize,
                    action: onClearTempFiles
                )
            }

            // Clear All Button
            Button(action: onClearAllCaches) {
                GlassCard(height: 62, borderColor: Color.red.opacity(0.5)) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 20))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pulisci Tutta la Cache".localized)
                                .font(.custom("Sora-Bold", size: 16))
                                .foregroundColor(.white)

                            Text(String(format: "Dimensione totale: %@".localized, stats.cacheSize))
                                .font(.custom("Sora-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }
}

struct CacheStatRow: View {
    let label: String
    let size: String
    let icon: String

    var body: some View {
        GlassCard(height: 56) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: "5CEBFF"))
                    .font(.system(size: 18))
                    .frame(width: 24)

                Text(label)
                    .font(.custom("Sora-SemiBold", size: 14))
                    .foregroundColor(.white)

                Spacer()

                Text(size)
                    .font(.custom("Sora-Bold", size: 14))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 18)
        }
    }
}

struct CacheButton: View {
    let title: String
    let icon: String
    let size: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard(height: 62) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(Color(hex: "5CEBFF"))
                        .font(.system(size: 18))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.custom("Sora-SemiBold", size: 15))
                            .foregroundColor(.white)

                        if size != "—" {
                            Text(size)
                                .font(.custom("Sora-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    Spacer()

                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 18)
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
    let onPasskey: () -> Void
    let onExportData: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Security and Privacy".localized)
                .font(.custom("Sora-SemiBold", size: 22))
                .foregroundColor(.white)

            ToggleCard(
                title: "Biometric Authentication".localized,
                subtitle: "Use Face ID or fingerprint to secure the app".localized,
                isOn: $biometricAuth
            )

            Button(action: onPasskey) {
                GlassCard(height: 62, borderColor: Color(hex: "2FB8FF")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Passkey".localized)
                                .font(.custom("Sora-SemiBold", size: 16))
                                .foregroundColor(.white)

                            Text("Create a passkey to sign in faster".localized)
                                .font(.custom("Sora-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        Image(systemName: "key.fill")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 18)
                }
            }

            ToggleCard(
                title: "Location Permission".localized,
                subtitle: "Allow app to access your location".localized,
                isOn: $locationPermission
            )

            ToggleCard(
                title: "Camera Permission".localized,
                subtitle: "Allow app to access your camera for AR features".localized,
                isOn: $cameraPermission
            )

            HStack(spacing: 16) {
                ForEach(PrivacyLevel.allCases, id: \.self) {
                    level in
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
                            Text("Data Protection".localized)
                                .font(.custom("Sora-SemiBold", size: 16))
                                .foregroundColor(.white)

                            Text("View collected data and request deletion".localized)
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
                    Text("Export My Data (GDPR)".localized)
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
            Text("Language".localized)
                .font(.custom("Sora-SemiBold", size: 22))
                .foregroundColor(.white)

            ForEach(Language.allCases, id: \.self) {
                language in
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
    let height: CGFloat?
    let borderColor: Color
    let content: Content

    init(height: CGFloat? = nil, borderColor: Color = Color(hex: "5CEBFF").opacity(0.4), @ViewBuilder content: () -> Content) {
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
                    .accessibilityLabel(title)
                    .accessibilityHint(subtitle)
                    .accessibilityValue(isOn ? "Attivo".localized : "Disattivo".localized)
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
                Text(level.rawValue.localized)
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

                    Text(language.name.localized)
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

// MARK: - Additional Sections & Components

struct NotificationsSection: View {
    @Binding var notificationsEnabled: Bool
    @Binding var promotionNotifications: Bool
    @Binding var updateNotifications: Bool
    @Binding var analysisNotifications: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Notifications".localized)
                .font(.custom("Sora-SemiBold", size: 22))
                .foregroundColor(.white)

            ToggleCard(
                title: "Enable Notifications".localized,
                subtitle: "Receive alerts and updates from the app".localized,
                isOn: $notificationsEnabled
            )

            if notificationsEnabled {
                VStack(spacing: 18) {
                    ToggleCard(
                        title: "Promotions & Offers".localized,
                        subtitle: "Get notified about special deals".localized,
                        isOn: $promotionNotifications
                    )
                    ToggleCard(
                        title: "App Updates".localized,
                        subtitle: "Know when a new version is available".localized,
                        isOn: $updateNotifications
                    )
                    ToggleCard(
                        title: "Analysis Complete".localized,
                        subtitle: "Receive an alert when tyre analysis is done".localized,
                        isOn: $analysisNotifications
                    )
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .move(edge: .bottom))))
                .animation(.default, value: notificationsEnabled)
            }
        }
    }
}

struct AppearanceSection: View {
    @Binding var selectedTheme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Appearance".localized)
                .font(.custom("Sora-SemiBold", size: 22))
                .foregroundColor(.white)

            HStack(spacing: 16) {
                ForEach(AppTheme.allCases, id: \.self) {
                    theme in
                    ThemeButton(
                        theme: theme,
                        isSelected: selectedTheme == theme
                    ) {
                        selectedTheme = theme
                    }
                }
            }
        }
    }
}

struct ThemeButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard(
                height: 62,
                borderColor: isSelected ? Color(hex: "2FB8FF") : Color(hex: "5CEBFF").opacity(0.4)
            ) {
                Text(theme.rawValue.localized)
                    .font(.custom(isSelected ? "Sora-Bold" : "Sora-Regular", size: 16))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Account Section
struct AccountSection: View {
    let onLogout: () -> Void
    let onExportData: () -> Void
    let onDeleteAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Account".localized)
                .font(.custom("Sora-SemiBold", size: 22))
                .foregroundColor(.white)

            Button(action: onExportData) {
                GlassCard(height: 62) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Color(hex: "5CEBFF"))
                            .font(.system(size: 20))
                        Text("Esporta i Miei Dati".localized)
                            .font(.custom("Sora-SemiBold", size: 16))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 18)
                }
            }

            Button(action: onLogout) {
                GlassCard(height: 62, borderColor: Color.orange.opacity(0.4)) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.orange)
                            .font(.system(size: 20))
                        Text("Logout".localized)
                            .font(.custom("Sora-SemiBold", size: 16))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                }
            }

            Button(action: onDeleteAccount) {
                GlassCard(height: 62, borderColor: Color.red.opacity(0.4)) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 20))
                        Text("Elimina Account".localized)
                            .font(.custom("Sora-SemiBold", size: 16))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }
}

struct AboutSection: View {
    @State private var showHelpSheet = false
    @State private var showMailUnavailable = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("About & Support".localized)
                .font(.custom("Sora-SemiBold", size: 22))
                .foregroundColor(.white)

            AboutButton(title: "Centro Assistenza".localized, icon: "questionmark.circle") {
                showHelpSheet = true
            }

            AboutButton(title: "Termini di Servizio".localized, icon: "doc.text") {
                openURL("https://tyrevibes.app/terms")
            }

            AboutButton(title: "Privacy Policy".localized, icon: "hand.raised") {
                openURL("https://tyrevibes.app/privacy")
            }

            AboutButton(title: "Valuta Quest'App".localized, icon: "star") {
                rateApp()
            }

            AboutButton(title: "Contattaci".localized, icon: "envelope") {
                openEmail()
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Versione App".localized)
                        .font(.custom("Sora-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(appVersion)
                        .font(.custom("Sora-SemiBold", size: 14))
                        .foregroundColor(.white)
                }

                HStack {
                    Text("Build Number".localized)
                        .font(.custom("Sora-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(buildNumber)
                        .font(.custom("Sora-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.top, 10)
        }
        .sheet(isPresented: $showHelpSheet) {
            HelpCenterSheet()
        }
        .alert("Mail non disponibile".localized, isPresented: $showMailUnavailable) {
            Button("Copia email".localized) {
                UIPasteboard.general.string = "support@tyrevibes.com"
            }
            Button("OK".localized, role: .cancel) { }
        } message: {
            Text("Configura un account Mail per inviare supporto a support@tyrevibes.com".localized)
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func rateApp() {
        // Try the new SKStoreReviewController first
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if #available(iOS 14.0, *) {
                SKStoreReviewController.requestReview(in: windowScene)
            } else {
                // Fallback for older iOS versions
                if let appID = Bundle.main.infoDictionary?["APP_STORE_ID"] as? String,
                   let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private func openEmail() {
        let email = "support@tyrevibes.com"
        let subject = "TyreVibes Support Request".localized
        let body = String(
            format: "Versione App: %@ (Build %@)\n\nDescrivi il tuo problema o richiesta:\n\n".localized,
            appVersion,
            buildNumber
        )

        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            showMailUnavailable = true
        }
    }
}

struct AboutButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            GlassCard(height: 62) {
                HStack(spacing: 12) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .foregroundColor(Color(hex: "5CEBFF"))
                            .font(.system(size: 20))
                            .frame(width: 24)
                    }
                    Text(title)
                        .font(.custom("Sora-SemiBold", size: 16))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 18)
            }
        }
    }
}

// MARK: - Models

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

enum PrivacyLevel: String, CaseIterable {
    case basic = "Basic"
    case balanced = "Balanced"
    case strict = "Strict"
}

// MARK: - Help Center Sheet

struct HelpCenterSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let supportEmail = "support@tyrevibes.com"
    @State private var showMailUnavailable = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }

    private let faqs: [(question: String, answer: String)] = [
        (
            "Come funziona l'analisi AR dei pneumatici?",
            "L'app utilizza la realtà aumentata per scansionare i tuoi pneumatici e misurare automaticamente la profondità del battistrada. Basta puntare la fotocamera sul pneumatico e seguire le istruzioni a schermo."
        ),
        (
            "Posso aggiungere più veicoli?",
            "Sì! Puoi aggiungere tutti i veicoli che desideri. Vai nella sezione Garage e clicca sul pulsante '+' per aggiungere un nuovo veicolo."
        ),
        (
            "Come vengono calcolate le notifiche di manutenzione?",
            "Le notifiche sono basate su algoritmi predittivi che considerano il chilometraggio, l'usura dei pneumatici, la stagione e le tue abitudini di guida per suggerirti il momento migliore per la manutenzione."
        ),
        (
            "I miei dati sono al sicuro?",
            "Assolutamente sì. Tutti i dati sono criptati e salvati in modo sicuro. Puoi gestire le tue preferenze sulla privacy nelle impostazioni e richiedere l'esportazione o l'eliminazione dei tuoi dati in qualsiasi momento."
        ),
        (
            "Come posso sincronizzare i dati tra dispositivi?",
            "Abilita la sincronizzazione cloud nelle impostazioni. I tuoi dati verranno automaticamente sincronizzati tra tutti i tuoi dispositivi collegati allo stesso account."
        ),
        (
            "Cosa significa il livello di privacy 'Strict'?",
            "Il livello 'Strict' disabilita completamente la raccolta di dati analitici e limita le funzionalità di tracciamento, garantendo la massima privacy. Solo i dati essenziali per il funzionamento dell'app vengono conservati."
        ),
        (
            "Come posso ottimizzare il consumo della batteria?",
            "Abilita l'opzione 'Battery Optimization' nelle impostazioni. Questo ridurrà le attività in background e la sincronizzazione automatica quando la batteria è scarica."
        ),
        (
            "Non riesco a scansionare il pneumatico",
            "Assicurati di avere una buona illuminazione e che il pneumatico sia pulito. Mantieni la fotocamera stabile a circa 30-40 cm dal pneumatico. Se il problema persiste, contattaci."
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(faqs.enumerated()), id: \.offset) {
                            index, faq in
                            FAQItem(question: faq.question.localized, answer: faq.answer.localized)
                        }

                        // Contact Support Button
                        VStack(spacing: 12) {
                            Text("Non hai trovato quello che cercavi?".localized)
                                .font(.custom("Sora-Regular", size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 24)

                            Button(action: {
                                openSupportEmail()
                            }) {
                                GlassCard(height: 56, borderColor: Color(hex: "2FB8FF")) {
                                    HStack {
                                        Image(systemName: "envelope.fill")
                                            .foregroundColor(Color(hex: "5CEBFF"))
                                        Text("Contatta il Supporto".localized)
                                            .font(.custom("Sora-SemiBold", size: 16))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Centro Assistenza".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi".localized) {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "5CEBFF"))
                }
            }
            .alert("Mail non disponibile".localized, isPresented: $showMailUnavailable) {
                Button("Copia email".localized) {
                    UIPasteboard.general.string = supportEmail
                }
                Button("OK".localized, role: .cancel) { }
            } message: {
                Text(String(format: "Configura un account Mail per inviare supporto a %@".localized, supportEmail))
            }
        }
    }

    private func openSupportEmail() {
        let subject = "TyreVibes Support Request".localized
        let body = String(
            format: "Versione App: %@ (Build %@)\n\nDescrivi il tuo problema o richiesta:\n\n".localized,
            appVersion,
            buildNumber
        )
        let urlString = "mailto:\(supportEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            showMailUnavailable = true
        }
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                GlassCard(height: isExpanded ? .infinity : 70) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(question)
                                .font(.custom("Sora-SemiBold", size: 16))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(Color(hex: "5CEBFF"))
                                .font(.system(size: 14, weight: .semibold))
                        }

                        if isExpanded {
                            Text(answer)
                                .font(.custom("Sora-Regular", size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(NotificationStore())
    }
}
