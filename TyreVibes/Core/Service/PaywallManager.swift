import Foundation
import SwiftUI

/// Manager che gestisce le funzionalità premium e i limiti per gli utenti free
@MainActor
public final class PaywallManager: ObservableObject {
    public static let shared = PaywallManager()

    // Published properties
    @Published public private(set) var isPremium: Bool = false
    @Published public var showPaywall: Bool = false
    @Published public var paywallFeature: PremiumFeature?

    private let subscriptionManager = FullSubscriptionManager.shared
    private let featureFlags = FeatureFlags.shared

    // Limiti per utenti free
    public enum FreeLimits {
        static let maxVehicles = 2
        static let maxTiresPerVehicle = 4
        static let maxMonthlyScans = 10
    }

    private init() {
        // Osserva lo stato dell'abbonamento
        Task {
            await subscriptionManager.refreshProductsAndStatus()
            updatePremiumStatus()
        }
    }

    /// Aggiorna lo stato premium in base all'abbonamento
    public func updatePremiumStatus() {
        isPremium = subscriptionManager.status.isActive
    }

    /// Verifica se una funzionalità premium è disponibile
    public func canUseFeature(_ feature: PremiumFeature) -> Bool {
        if isPremium {
            return true
        }
        return false
    }

    /// Mostra il paywall per una specifica funzionalità
    public func showPaywall(for feature: PremiumFeature) {
        // Se il paywall è disabilitato, non mostrarlo
        guard featureFlags.isPaywallEnabled else { return }

        paywallFeature = feature
        showPaywall = true
    }

    /// Verifica se l'utente può aggiungere un altro veicolo
    public func canAddVehicle(currentCount: Int) -> Bool {
        // Se il paywall è disabilitato, permetti tutto
        guard featureFlags.isPaywallEnabled else { return true }

        if isPremium {
            return true
        }
        return currentCount < FreeLimits.maxVehicles
    }

    /// Verifica se l'utente può aggiungere un altro pneumatico
    public func canAddTire(currentCount: Int) -> Bool {
        // Se il paywall è disabilitato, permetti tutto
        guard featureFlags.isPaywallEnabled else { return true }

        if isPremium {
            return true
        }
        return currentCount < FreeLimits.maxTiresPerVehicle
    }

    /// Ottiene il messaggio di limite per una funzionalità
    public func getLimitMessage(for feature: PremiumFeature) -> String {
        switch feature {
        case .unlimitedVehicles:
            return "Free users can add up to \(FreeLimits.maxVehicles) vehicles. Upgrade to Premium for unlimited vehicles."
        case .unlimitedTires:
            return "Free users can add up to \(FreeLimits.maxTiresPerVehicle) tires per vehicle. Upgrade to Premium for unlimited tires."
        case .advancedOCR:
            return "Advanced OCR scanning is a Premium feature. Upgrade to unlock AI-powered tire recognition."
        case .smartNotifications:
            return "Smart notifications are a Premium feature. Upgrade to get timely reminders for maintenance and tire changes."
        case .detailedAnalytics:
            return "Detailed analytics are a Premium feature. Upgrade to track maintenance costs and vehicle history."
        case .cloudSync:
            return "Cloud sync is a Premium feature. Upgrade to access your data across all devices."
        case .prioritySupport:
            return "Priority support is a Premium feature. Upgrade to get help from our team whenever you need it."
        case .adFree:
            return "Remove ads with Premium. Upgrade for an ad-free experience."
        }
    }
}

/// Enum che rappresenta le funzionalità premium
public enum PremiumFeature: String, Identifiable {
    case unlimitedVehicles = "unlimited_vehicles"
    case unlimitedTires = "unlimited_tires"
    case advancedOCR = "advanced_ocr"
    case smartNotifications = "smart_notifications"
    case detailedAnalytics = "detailed_analytics"
    case cloudSync = "cloud_sync"
    case prioritySupport = "priority_support"
    case adFree = "ad_free"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .unlimitedVehicles:
            return "Unlimited Vehicles"
        case .unlimitedTires:
            return "Unlimited Tires"
        case .advancedOCR:
            return "Advanced OCR Scanning"
        case .smartNotifications:
            return "Smart Notifications"
        case .detailedAnalytics:
            return "Detailed Analytics"
        case .cloudSync:
            return "Cloud Sync"
        case .prioritySupport:
            return "Priority Support"
        case .adFree:
            return "Ad-Free Experience"
        }
    }

    public var icon: String {
        switch self {
        case .unlimitedVehicles:
            return "car.2.fill"
        case .unlimitedTires:
            return "circle.grid.3x3.fill"
        case .advancedOCR:
            return "camera.fill"
        case .smartNotifications:
            return "bell.badge.fill"
        case .detailedAnalytics:
            return "chart.line.uptrend.xyaxis"
        case .cloudSync:
            return "cloud.fill"
        case .prioritySupport:
            return "headphones"
        case .adFree:
            return "sparkles"
        }
    }
}
