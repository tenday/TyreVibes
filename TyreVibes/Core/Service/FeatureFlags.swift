import Foundation
import SwiftUI

/// Manager per gestire le feature flags dell'app
@MainActor
public final class FeatureFlags: ObservableObject {
    public static let shared = FeatureFlags()

    // MARK: - Feature Flags

    /// Abilita o disabilita il sistema di paywall
    @AppStorage("feature_paywall_enabled") public var isPaywallEnabled: Bool = false

    /// Abilita o disabilita le notifiche push
    @AppStorage("feature_notifications_enabled") public var isNotificationsEnabled: Bool = true

    /// Abilita o disabilita il cloud sync
    @AppStorage("feature_cloud_sync_enabled") public var isCloudSyncEnabled: Bool = true

    /// Abilita o disabilita analytics
    @AppStorage("feature_analytics_enabled") public var isAnalyticsEnabled: Bool = true

    /// Modalità debug per sviluppatori
    @AppStorage("feature_debug_mode") public var isDebugMode: Bool = false

    private init() {}

    /// Reset di tutte le feature flags ai valori di default
    public func resetToDefaults() {
        isPaywallEnabled = false
        isNotificationsEnabled = true
        isCloudSyncEnabled = true
        isAnalyticsEnabled = true
        isDebugMode = false
    }

    /// Ottieni tutte le feature flags come dizionario
    public var allFlags: [String: Bool] {
        return [
            "Paywall System": isPaywallEnabled,
            "Push Notifications": isNotificationsEnabled,
            "Cloud Sync": isCloudSyncEnabled,
            "Analytics": isAnalyticsEnabled,
            "Debug Mode": isDebugMode
        ]
    }
}
