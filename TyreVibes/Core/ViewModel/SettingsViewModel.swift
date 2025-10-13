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

        static let placeholder = SettingsStats(appSize: "—", cacheSize: "—", batteryUsage: "—")
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

    private(set) var shareItems: [Any] = []

    private let featureFlags = FeatureFlags.shared
    private let defaults = UserDefaults.standard
    private let locationManager = CLLocationManager()
    private let languageManager = LanguageManager.shared
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
    }

    func refreshStats() {
        Task { [weak self] in
            guard let self else { return }
            let appSize = await self.computeAppSizeString()
            let cacheSize = await self.computeCacheSizeString()
            let batteryUsage = self.currentBatteryUsageString()

            await MainActor.run {
                stats = SettingsStats(appSize: appSize, cacheSize: cacheSize, batteryUsage: batteryUsage)
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
        alert = SettingsAlert(title: "Cache Cleared", message: "Temporary files have been removed.", style: .info)
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
    }

    private func applyBatteryOptimization() {
        defaults.set(batteryOptimization, forKey: Keys.batteryOptimization)
    }

    private func applyImageQuality() {
        defaults.set(imageQuality, forKey: Keys.imageQuality)
    }

    private func applyCacheManagement() {
        defaults.set(cacheManagement, forKey: Keys.cacheManagement)
        if cacheManagement {
            clearCaches()
        }
    }

    private func applyBiometricPreference() {
        guard !isSyncingFromStore else { return }

        if biometricAuth {
            var error: NSError?
            let context = LAContext()
            let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            if canEvaluate {
                defaults.set(true, forKey: "useFaceID")
            } else {
                isSyncingFromStore = true
                biometricAuth = false
                isSyncingFromStore = false
                defaults.set(false, forKey: "useFaceID")
                alert = SettingsAlert(title: "Biometrics Unavailable", message: error?.localizedDescription ?? "Your device does not support Face ID / Touch ID.", style: .info)
            }
        } else {
            defaults.set(false, forKey: "useFaceID")
        }
    }

    private func applyPrivacyLevel() {
        defaults.set(privacyLevel.rawValue, forKey: Keys.privacyLevel)
        featureFlags.isAnalyticsEnabled = privacyLevel != .strict
    }

    private func applyLanguageChange() {
        languageManager.setLanguage(selectedLanguage)
        alert = SettingsAlert(
            title: "Language Updated",
            message: "The interface language has been updated.",
            style: .info
        )
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
            components.append("Level: \(levelPercentage)%")
        }
        components.append(processInfo.isLowPowerModeEnabled ? "Low Power" : "Normal")
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

@MainActor
extension SettingsViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        isSyncingFromStore = true
        locationPermission = isLocationAuthorized
        isSyncingFromStore = false
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
}
