import SwiftUI
import LocalAuthentication
import CoreLocation
import AVFoundation
import UIKit

@MainActor
final class SettingsViewModel: NSObject, ObservableObject {
    struct SettingsStats: Equatable {
        var appSize: String
        var cacheSize: String
        var batteryUsage: String
        var imageCacheSize: String
        var vehicleCacheSize: String
        var tempFilesSize: String

        static let placeholder = SettingsStats(
            appSize: "—",
            cacheSize: "—",
            batteryUsage: "—",
            imageCacheSize: "—",
            vehicleCacheSize: "—",
            tempFilesSize: "—"
        )
    }

    struct SettingsAlert: Identifiable {
        enum Style {
            case info
            case openSettings
        }

        let id = UUID()
        let title: String
        let message: String
        let style: Style
    }

    @Published var backgroundSync: Bool
    @Published var batteryOptimization: Bool
    @Published var imageQuality: Double
    @Published var cacheManagement: Bool
    @Published var biometricAuth: Bool
    @Published var locationPermission: Bool
    @Published var cameraPermission: Bool
    @Published var privacyLevel: PrivacyLevel
    @Published var selectedLanguage: Language
    @Published private(set) var stats: SettingsStats = .placeholder
    @Published var isPresentingDataProtection = false
    @Published var alert: SettingsAlert?
    @Published var isPresentingShareSheet = false

    // Notification Settings
    @Published var notificationsEnabled: Bool
    @Published var promotionNotifications: Bool
    @Published var updateNotifications: Bool
    @Published var analysisNotifications: Bool

    // Appearance Settings
    @Published var selectedTheme: AppTheme

    // Account Settings
    @Published var isPresentingLogoutConfirmation = false

    private(set) var shareItems: [Any] = []

    private let featureFlags = FeatureFlags.shared
    private let defaults = UserDefaults.standard
    private let locationManager = CLLocationManager()
    private let languageManager = LanguageManager.shared
    private let notificationManager = NotificationManager.shared
    private let passkeyService = PasskeyAuthService.shared
    private var isSyncingFromStore = false

    private struct ExportPayload: Codable {
        let generatedAt: String
        let backgroundSync: Bool
        let batteryOptimization: Bool
        let imageQuality: Double
        let cacheManagement: Bool
        let biometricAuth: Bool
        let locationPermission: Bool
        let cameraPermission: Bool
        let privacyLevel: String
        let language: String
    }

    private struct Keys {
        static let batteryOptimization = "settings_battery_optimization_enabled"
        static let imageQuality = "settings_image_quality"
        static let cacheManagement = "settings_cache_management"
        static let privacyLevel = "settings_privacy_level"
        static let notificationsEnabled = "settings_notifications_enabled"
        static let promotionNotifications = "settings_promotion_notifications"
        static let updateNotifications = "settings_update_notifications"
        static let analysisNotifications = "settings_analysis_notifications"
        static let selectedTheme = "settings_selected_theme"
    }

    override init() {
        let storedImageQuality = UserDefaults.standard.object(forKey: Keys.imageQuality) as? Double ?? 0.8
        backgroundSync = featureFlags.isCloudSyncEnabled
        batteryOptimization = UserDefaults.standard.object(forKey: Keys.batteryOptimization) as? Bool ?? true
        imageQuality = storedImageQuality
        cacheManagement = UserDefaults.standard.object(forKey: Keys.cacheManagement) as? Bool ?? true
        biometricAuth = UserDefaults.standard.bool(forKey: "useFaceID")
        privacyLevel = PrivacyLevel(rawValue: UserDefaults.standard.string(forKey: Keys.privacyLevel) ?? PrivacyLevel.strict.rawValue) ?? .strict
        selectedLanguage = languageManager.currentLanguage
        locationPermission = false
        cameraPermission = false

        // Load notification settings
        notificationsEnabled = UserDefaults.standard.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        promotionNotifications = UserDefaults.standard.object(forKey: Keys.promotionNotifications) as? Bool ?? true
        updateNotifications = UserDefaults.standard.object(forKey: Keys.updateNotifications) as? Bool ?? false
        analysisNotifications = UserDefaults.standard.object(forKey: Keys.analysisNotifications) as? Bool ?? true

        // Load theme settings
        let themeRawValue = UserDefaults.standard.string(forKey: Keys.selectedTheme) ?? AppTheme.system.rawValue
        selectedTheme = AppTheme(rawValue: themeRawValue) ?? .system

        super.init()

        locationManager.delegate = self
        UIDevice.current.isBatteryMonitoringEnabled = true
        refreshPermissionStates()
        refreshStats()
    }

    // MARK: - Public API

    func onAppear() {
        refreshPermissionStates()
        refreshStats()
        loadSettingsFromCloud()
    }

    func refreshStats() {
        Task { [weak self] in
            guard let self else { return }
            let appSize = await self.computeAppSizeString()
            let cacheSize = await self.computeCacheSizeString()
            let batteryUsage = self.currentBatteryUsageString()
            let imageCacheSize = await self.computeImageCacheSizeString()
            let vehicleCacheSize = await self.computeVehicleCacheSizeString()
            let tempFilesSize = await self.computeTempFilesSizeString()

            await MainActor.run {
                stats = SettingsStats(
                    appSize: appSize,
                    cacheSize: cacheSize,
                    batteryUsage: batteryUsage,
                    imageCacheSize: imageCacheSize,
                    vehicleCacheSize: vehicleCacheSize,
                    tempFilesSize: tempFilesSize
                )
            }
        }
    }

    func clearCaches() {
        TyreCacheManager.shared.clearAllCache()
        PlateDataCache.clear()
        VehicleImageService.clearCache()
        URLCache.shared.removeAllCachedResponses()
        defaults.removeObject(forKey: "cachedVehicles")
        refreshStats()
        alert = SettingsAlert(title: "Cache Cancellata", message: "Tutti i file temporanei sono stati rimossi.", style: .info)
    }

    func clearImageCache() {
        VehicleImageService.clearCache()
        URLCache.shared.removeAllCachedResponses()
        refreshStats()
        alert = SettingsAlert(title: "Cache Immagini Cancellata", message: "Le immagini in cache sono state rimosse.", style: .info)
    }

    func clearVehicleCache() {
        defaults.removeObject(forKey: "cachedVehicles")
        PlateDataCache.clear()
        refreshStats()
        alert = SettingsAlert(title: "Cache Veicoli Cancellata", message: "I dati dei veicoli in cache sono stati rimossi.", style: .info)
    }

    func clearTyreCache() {
        TyreCacheManager.shared.clearAllCache()
        refreshStats()
        alert = SettingsAlert(title: "Cache Pneumatici Cancellata", message: "I dati dei pneumatici in cache sono stati rimossi.", style: .info)
    }

    func clearTempFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for file in tempFiles {
                try? FileManager.default.removeItem(at: file)
            }
            refreshStats()
            alert = SettingsAlert(title: "File Temporanei Cancellati", message: "I file temporanei sono stati rimossi.", style: .info)
        } catch {
            alert = SettingsAlert(title: "Errore", message: "Impossibile cancellare i file temporanei.", style: .info)
        }
    }

    func requestDataDeletion() {
        Task {
            do {
                let authService = AuthService()
                try await authService.deleteCurrentUser()

                // Clear all user-related data
                clearCaches()
                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                UserDefaults.standard.synchronize()

                // Navigate to the login screen
                await MainActor.run {
                    // This assumes you have a way to reset the app's root view controller
                    // For example, by posting a notification that the app delegate observes
                    NotificationCenter.default.post(name: .didRequestLogout, object: nil)
                }
            } catch {
                await MainActor.run {
                    alert = SettingsAlert(title: "Deletion Failed", message: "We couldn't delete your account. Please try again.", style: .info)
                }
            }
        }
    }

    func exportMyData() {
        do {
            let exportedData = makeExportPayload()
            let data = try JSONEncoder().encode(exportedData)
            let url = try persistExportFile(data: data)
            shareItems = [url]
            isPresentingShareSheet = true
        } catch {
            alert = SettingsAlert(title: "Export Failed", message: "We couldn't prepare your data export. Please try again.", style: .info)
        }
    }

    func dismissShareSheet() {
        shareItems = []
        isPresentingShareSheet = false
    }

    var imageQualityLabel: String {
        switch imageQuality {
        case let value where value > 0.66:
            return "High"
        case let value where value > 0.33:
            return "Medium"
        default:
            return "Low"
        }
    }

    // MARK: - Private Helpers

    private func applyBackgroundSync() {
        featureFlags.isCloudSyncEnabled = backgroundSync
        syncSettingsToCloud()
    }

    private func applyBatteryOptimization() {
        defaults.set(batteryOptimization, forKey: Keys.batteryOptimization)
        syncSettingsToCloud()
    }

    private func applyImageQuality() {
        defaults.set(imageQuality, forKey: Keys.imageQuality)
        syncSettingsToCloud()
    }

    private func applyCacheManagement() {
        defaults.set(cacheManagement, forKey: Keys.cacheManagement)
        if cacheManagement {
            clearCaches()
        }
        syncSettingsToCloud()
    }

    private func applyBiometricPreference() {
        guard !isSyncingFromStore else { return }

        if biometricAuth {
            var error: NSError?
            let context = LAContext()
            let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            if canEvaluate {
                let reason = "Attiva l'accesso biometrico"
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, evalError in
                    Task { @MainActor in
                        guard let self else { return }
                        if success {
                            self.defaults.set(true, forKey: "useFaceID")
                            self.syncSettingsToCloud()
                        } else {
                            self.isSyncingFromStore = true
                            self.biometricAuth = false
                            self.isSyncingFromStore = false
                            self.defaults.set(false, forKey: "useFaceID")
                            let message = evalError?.localizedDescription ?? "Autenticazione biometrica non riuscita."
                            self.alert = SettingsAlert(title: "Biometrics Unavailable", message: message, style: .info)
                            self.syncSettingsToCloud()
                        }
                    }
                }
            } else {
                isSyncingFromStore = true
                biometricAuth = false
                isSyncingFromStore = false
                defaults.set(false, forKey: "useFaceID")
                let laError = error as? LAError
                let style: SettingsAlert.Style = (laError?.code == .biometryNotEnrolled || laError?.code == .biometryNotAvailable) ? .openSettings : .info
                let message = error?.localizedDescription ?? "Your device does not support Face ID / Touch ID."
                alert = SettingsAlert(title: "Biometrics Unavailable", message: message, style: style)
                syncSettingsToCloud()
            }
        } else {
            defaults.set(false, forKey: "useFaceID")
            syncSettingsToCloud()
        }
    }

    private func applyPrivacyLevel() {
        defaults.set(privacyLevel.rawValue, forKey: Keys.privacyLevel)
        featureFlags.isAnalyticsEnabled = privacyLevel != .strict
        syncSettingsToCloud()
    }

    private func applyLanguageChange() {
        languageManager.setLanguage(selectedLanguage)
        alert = SettingsAlert(
            title: "Language Updated",
            message: "The interface language has been updated.",
            style: .info
        )
        syncSettingsToCloud()
    }

    private func applyLocationPreference() {
        guard !isSyncingFromStore else { return }

        if locationPermission {
            requestLocationPermission()
        } else {
            revertLocationStateWithSettingsPrompt()
        }
    }

    private func applyCameraPreference() {
        guard !isSyncingFromStore else { return }

        if cameraPermission {
            requestCameraPermission()
        } else {
            revertCameraStateWithSettingsPrompt()
        }
    }

    private func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            revertLocationStateWithSettingsPrompt()
        }
    }

    private func requestCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                Task { @MainActor in
                    self.isSyncingFromStore = true
                    self.cameraPermission = granted
                    self.isSyncingFromStore = false
                    if !granted {
                        self.alert = SettingsAlert(title: "Camera Permission Denied", message: "Enable camera access from iOS Settings to use scanning features.", style: .openSettings)
                    }
                }
            }
        default:
            revertCameraStateWithSettingsPrompt()
        }
    }

    private func revertLocationStateWithSettingsPrompt() {
        isSyncingFromStore = true
        locationPermission = isLocationAuthorized
        isSyncingFromStore = false
        alert = SettingsAlert(title: "Location Access", message: "Manage location permissions from Settings > Privacy > Location Services.", style: .openSettings)
    }

    private func revertCameraStateWithSettingsPrompt() {
        isSyncingFromStore = true
        cameraPermission = isCameraAuthorized
        isSyncingFromStore = false
        alert = SettingsAlert(title: "Camera Access", message: "Camera permissions can be changed from Settings > Privacy > Camera.", style: .openSettings)
    }

    private var isLocationAuthorized: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    private var isCameraAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    private func refreshPermissionStates() {
        isSyncingFromStore = true
        locationPermission = isLocationAuthorized
        cameraPermission = isCameraAuthorized
        biometricAuth = defaults.bool(forKey: "useFaceID")
        backgroundSync = featureFlags.isCloudSyncEnabled
        batteryOptimization = defaults.object(forKey: Keys.batteryOptimization) as? Bool ?? batteryOptimization
        imageQuality = defaults.object(forKey: Keys.imageQuality) as? Double ?? imageQuality
        cacheManagement = defaults.object(forKey: Keys.cacheManagement) as? Bool ?? cacheManagement
        privacyLevel = PrivacyLevel(rawValue: defaults.string(forKey: Keys.privacyLevel) ?? privacyLevel.rawValue) ?? privacyLevel
        selectedLanguage = languageManager.currentLanguage
        isSyncingFromStore = false
    }

    private func computeAppSizeString() async -> String {
        let bundleURL = Bundle.main.bundleURL
        let size = await directorySize(at: bundleURL)
        return formattedSize(bytes: size)
    }

    private func computeCacheSizeString() async -> String {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let tempURL = FileManager.default.temporaryDirectory
        let cacheSize = await directorySize(at: cacheURL)
        let tempSize = await directorySize(at: tempURL)
        return formattedSize(bytes: cacheSize + tempSize)
    }

    private func computeImageCacheSizeString() async -> String {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        var size: UInt64 = 0

        if let cacheURL = cacheURL {
            // Calculate URLCache size (images and network responses)
            let urlCacheSize = URLCache.shared.currentDiskUsage
            size += UInt64(urlCacheSize)

            // Also check for any image-specific cache directories
            let imageCacheURL = cacheURL.appendingPathComponent("Images")
            size += await directorySize(at: imageCacheURL)
        }

        return formattedSize(bytes: size)
    }

    private func computeVehicleCacheSizeString() async -> String {
        // Calculate size of cached vehicles data
        if let data = defaults.data(forKey: "cachedVehicles") {
            return formattedSize(bytes: UInt64(data.count))
        }
        return formattedSize(bytes: 0)
    }

    private func computeTempFilesSizeString() async -> String {
        let tempURL = FileManager.default.temporaryDirectory
        let size = await directorySize(at: tempURL)
        return formattedSize(bytes: size)
    }

    private func directorySize(at url: URL?) async -> UInt64 {
        guard let url else { return 0 }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let size = self.recursiveSize(at: url)
                continuation.resume(returning: size)
            }
        }
    }

    private func recursiveSize(at url: URL) -> UInt64 {
        let fileManager = FileManager.default
        var size: UInt64 = 0
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    if resourceValues.isRegularFile == true {
                        size += UInt64(resourceValues.fileSize ?? 0)
                    }
                } catch {
                    continue
                }
            }
        }
        return size
    }

    private func formattedSize(bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func currentBatteryUsageString() -> String {
        let processInfo = ProcessInfo.processInfo
        let batteryLevel = UIDevice.current.batteryLevel
        let levelPercentage = batteryLevel >= 0 ? Int(round(batteryLevel * 100)) : -1

        var components: [String] = []
        if levelPercentage >= 0 {
            components.append(String(format: "Level: %d%%".localized, levelPercentage))
        }
        components.append(processInfo.isLowPowerModeEnabled ? "Low Power".localized : "Normal".localized)
        return components.joined(separator: " · ")
    }

    private func makeExportPayload() -> ExportPayload {
        ExportPayload(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            backgroundSync: backgroundSync,
            batteryOptimization: batteryOptimization,
            imageQuality: imageQuality,
            cacheManagement: cacheManagement,
            biometricAuth: biometricAuth,
            locationPermission: locationPermission,
            cameraPermission: cameraPermission,
            privacyLevel: privacyLevel.rawValue,
            language: selectedLanguage.rawValue
        )
    }

    private func persistExportFile(data: Data) throws -> URL {
        let filename = "TyreVibes-Export-\(ISO8601DateFormatter().string(from: Date())).json"
        let directory = FileManager.default.temporaryDirectory
        let fileURL = directory.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}

extension SettingsViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            isSyncingFromStore = true
            locationPermission = isLocationAuthorized
            isSyncingFromStore = false
        }
    }
}

extension SettingsViewModel {
    func handleBackgroundSyncChange() {
        applyBackgroundSync()
    }

    func handleBatteryOptimizationChange() {
        applyBatteryOptimization()
    }

    func handleImageQualityChange() {
        applyImageQuality()
    }

    func handleCacheManagementChange() {
        applyCacheManagement()
    }

    func handleBiometricChange() {
        applyBiometricPreference()
    }

    func registerPasskey() {
        Task {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                await MainActor.run {
                    alert = SettingsAlert(title: "Passkey", message: "Passkey not available.".localized, style: .info)
                }
                return
            }

            do {
                try await passkeyService.registerPasskey(presentationAnchor: window)
                await MainActor.run {
                    alert = SettingsAlert(title: "Passkey", message: "Passkey setup completed.".localized, style: .info)
                }
            } catch {
                await MainActor.run {
                    alert = SettingsAlert(title: "Passkey", message: error.localizedDescription, style: .info)
                }
            }
        }
    }

    func handlePrivacyLevelChange() {
        applyPrivacyLevel()
    }

    func handleLanguageChange() {
        applyLanguageChange()
    }

    func handleLocationChange() {
        applyLocationPreference()
    }

    func handleCameraChange() {
        applyCameraPreference()
    }

    func handleNotificationsEnabledChange() {
        applyNotificationsEnabled()
    }

    func handlePromotionNotificationsChange() {
        applyPromotionNotifications()
    }

    func handleUpdateNotificationsChange() {
        applyUpdateNotifications()
    }

    func handleAnalysisNotificationsChange() {
        applyAnalysisNotifications()
    }

    func handleThemeChange() {
        applyTheme()
    }
}

// MARK: - Notification & Theme Handlers

extension SettingsViewModel {
    private func applyNotificationsEnabled() {
        defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled)

        if notificationsEnabled {
            // Request notification authorization
            Task {
                do {
                    let granted = try await notificationManager.requestAuthorization()
                    if !granted {
                        await MainActor.run {
                            isSyncingFromStore = true
                            notificationsEnabled = false
                            isSyncingFromStore = false
                            alert = SettingsAlert(
                                title: "Notifications Disabled",
                                message: "Please enable notifications in Settings to receive alerts.",
                                style: .openSettings
                            )
                        }
                    }
                } catch {
                    await MainActor.run {
                        alert = SettingsAlert(
                            title: "Error",
                            message: "Failed to request notification permissions.",
                            style: .info
                        )
                    }
                }
            }
        } else {
            // Disable all notification types
            promotionNotifications = false
            updateNotifications = false
            analysisNotifications = false
        }
    }

    private func applyPromotionNotifications() {
        defaults.set(promotionNotifications, forKey: Keys.promotionNotifications)
        featureFlags.isNotificationsEnabled = promotionNotifications || updateNotifications || analysisNotifications
        syncSettingsToCloud()
    }

    private func applyUpdateNotifications() {
        defaults.set(updateNotifications, forKey: Keys.updateNotifications)
        featureFlags.isNotificationsEnabled = promotionNotifications || updateNotifications || analysisNotifications
        syncSettingsToCloud()
    }

    private func applyAnalysisNotifications() {
        defaults.set(analysisNotifications, forKey: Keys.analysisNotifications)
        featureFlags.isNotificationsEnabled = promotionNotifications || updateNotifications || analysisNotifications
        syncSettingsToCloud()
    }

    private func applyTheme() {
        defaults.set(selectedTheme.rawValue, forKey: Keys.selectedTheme)

        // Apply theme to the entire app
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        windowScene?.windows.forEach { window in
            switch selectedTheme {
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            }
        }

        syncSettingsToCloud()
    }
}

// MARK: - Cloud Sync

extension SettingsViewModel {
    private struct UserSettings: Codable {
        let userId: String
        let backgroundSync: Bool
        let batteryOptimization: Bool
        let imageQuality: Double
        let cacheManagement: Bool
        let biometricAuth: Bool
        let privacyLevel: String
        let language: String
        let notificationsEnabled: Bool
        let promotionNotifications: Bool
        let updateNotifications: Bool
        let analysisNotifications: Bool
        let selectedTheme: String
        let updatedAt: String
    }

    func syncSettingsToCloud() {
        guard featureFlags.isCloudSyncEnabled else { return }

        Task {
            do {
                let session = try await SupabaseManager.client.auth.session
                let userId = session.user.id.uuidString

                let settings = UserSettings(
                    userId: userId,
                    backgroundSync: backgroundSync,
                    batteryOptimization: batteryOptimization,
                    imageQuality: imageQuality,
                    cacheManagement: cacheManagement,
                    biometricAuth: biometricAuth,
                    privacyLevel: privacyLevel.rawValue,
                    language: selectedLanguage.rawValue,
                    notificationsEnabled: notificationsEnabled,
                    promotionNotifications: promotionNotifications,
                    updateNotifications: updateNotifications,
                    analysisNotifications: analysisNotifications,
                    selectedTheme: selectedTheme.rawValue,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )

                // Upsert settings to Supabase
                try await SupabaseManager.client
                    .from("user_settings")
                    .upsert(settings)
                    .execute()

            } catch {
                print("Failed to sync settings to cloud: \(error)")
            }
        }
    }

    func loadSettingsFromCloud() {
        guard featureFlags.isCloudSyncEnabled else { return }

        Task {
            do {
                let session = try await SupabaseManager.client.auth.session
                let userId = session.user.id.uuidString

                let response: UserSettings = try await SupabaseManager.client
                    .from("user_settings")
                    .select("*")
                    .eq("userId", value: userId)
                    .single()
                    .execute()
                    .value

                // Update local settings with cloud data
                await MainActor.run {
                    isSyncingFromStore = true

                    backgroundSync = response.backgroundSync
                    batteryOptimization = response.batteryOptimization
                    imageQuality = response.imageQuality
                    cacheManagement = response.cacheManagement
                    biometricAuth = response.biometricAuth
                    privacyLevel = PrivacyLevel(rawValue: response.privacyLevel) ?? .strict
                    selectedLanguage = Language(rawValue: response.language) ?? .italian
                    notificationsEnabled = response.notificationsEnabled
                    promotionNotifications = response.promotionNotifications
                    updateNotifications = response.updateNotifications
                    analysisNotifications = response.analysisNotifications
                    selectedTheme = AppTheme(rawValue: response.selectedTheme) ?? .system

                    // Save to UserDefaults
                    defaults.set(batteryOptimization, forKey: Keys.batteryOptimization)
                    defaults.set(imageQuality, forKey: Keys.imageQuality)
                    defaults.set(cacheManagement, forKey: Keys.cacheManagement)
                    defaults.set(privacyLevel.rawValue, forKey: Keys.privacyLevel)
                    defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
                    defaults.set(promotionNotifications, forKey: Keys.promotionNotifications)
                    defaults.set(updateNotifications, forKey: Keys.updateNotifications)
                    defaults.set(analysisNotifications, forKey: Keys.analysisNotifications)
                    defaults.set(selectedTheme.rawValue, forKey: Keys.selectedTheme)

                    isSyncingFromStore = false
                }

            } catch {
                print("Failed to load settings from cloud: \(error)")
            }
        }
    }
}

// MARK: - Account Management

extension SettingsViewModel {
    func logout() {
        Task {
            do {
                // Clear caches and user data
                clearCaches()
                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                UserDefaults.standard.synchronize()

                // Logout from Supabase
                let authService = AuthService()
                try await authService.logout()

                // Post logout notification
                await MainActor.run {
                    NotificationCenter.default.post(name: .didRequestLogout, object: nil)
                }
            } catch {
                await MainActor.run {
                    alert = SettingsAlert(
                        title: "Logout Failed",
                        message: "Unable to logout. Please try again.",
                        style: .info
                    )
                }
            }
        }
    }
}
