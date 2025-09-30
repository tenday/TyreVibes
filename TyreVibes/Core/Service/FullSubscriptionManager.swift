import Foundation
import StoreKit

/// Represents the current state of the user's full subscription within the app.
/// - Note: `expirationDate` is only available for renewable subscriptions.
public enum FullSubscriptionStatus: Equatable {
    case unknown
    case notPurchased
    case active(expirationDate: Date?)
    case expired(latestExpirationDate: Date?)

    /// Convenience flag to check if the subscription is currently active.
    public var isActive: Bool {
        if case .active = self { return true }
        return false
    }
}

/// Centralised manager that encapsulates StoreKit 2 interactions for the "full" subscription tier.
///
/// The class exposes a published `status` property that view models can observe to
/// react to subscription changes. All StoreKit calls occur on the main actor to keep
/// UI updates consistent.
@MainActor
public final class FullSubscriptionManager: ObservableObject {
    public static let shared = FullSubscriptionManager()

    /// The identifiers that map to the "full" subscription products configured in App Store Connect.
    /// You can override them at runtime by calling `configure(with:)`.
    private(set) var productIdentifiers: Set<String>

    /// Published StoreKit products that can be surfaced in the paywall UI.
    @Published public private(set) var availableProducts: [Product] = []

    /// Real-time status for consumers; defaults to `.unknown` until the first refresh completes.
    @Published public private(set) var status: FullSubscriptionStatus = .unknown

    /// Indicates whether the manager is currently performing a long running StoreKit task.
    @Published public private(set) var isLoading: Bool = false

    /// Holds the most recent error surfaced by the manager so callers can present an alert if needed.
    @Published public private(set) var lastError: Error?

    private init(productIdentifiers: Set<String> = [
        "full_subscription_monthly",
        "full_subscription_yearly"
    ]) {
        self.productIdentifiers = productIdentifiers
    }

    /// Reconfigures the manager with the product identifiers that represent the "full" subscription tier.
    /// Typically invoked during app start if the identifiers are loaded from a remote config.
    public func configure(with productIdentifiers: Set<String>) {
        guard self.productIdentifiers != productIdentifiers else { return }
        self.productIdentifiers = productIdentifiers
        Task { await refreshProductsAndStatus() }
    }

    /// Loads the configured subscription products and resolves the current entitlement status.
    public func refreshProductsAndStatus() async {
        isLoading = true
        defer { isLoading = false }

        do {
            availableProducts = try await Product.products(for: Array(productIdentifiers))
            try await updateCurrentStatus()
            lastError = nil
        } catch {
            lastError = error
            status = .unknown
        }
    }

    /// Initiates the purchase flow for the selected subscription product.
    /// Returns `true` when the transaction succeeds, otherwise `false`.
    @discardableResult
    public func purchase(product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase(options: [.simulatesAskToBuyInSandbox(false)])
            switch result {
            case .success(let verification):
                if let transaction = try await verificationPayload(from: verification) {
                    await transaction.finish()
                    try await updateCurrentStatus()
                    lastError = nil
                    return true
                }
            case .pending:
                status = .unknown
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error
        }

        return false
    }

    /// Triggers a restoration of the user's App Store purchases.
    public func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            try await updateCurrentStatus()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    /// Evaluates the latest entitlements and updates the public `status` property.
    private func updateCurrentStatus() async throws {
        var latestExpirationDate: Date?
        var hasActiveEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  productIdentifiers.contains(transaction.productID) else { continue }

            if transaction.revocationDate != nil {
                continue
            }

            if let expiration = transaction.expirationDate {
                if expiration > Date() {
                    hasActiveEntitlement = true
                    latestExpirationDate = expiration
                    break
                } else {
                    latestExpirationDate = max(latestExpirationDate ?? expiration, expiration)
                }
            } else {
                // Non-renewing subscription or lifetime unlock.
                hasActiveEntitlement = true
                latestExpirationDate = nil
                break
            }
        }

        if hasActiveEntitlement {
            status = .active(expirationDate: latestExpirationDate)
        } else if let expiredDate = latestExpirationDate {
            status = .expired(latestExpirationDate: expiredDate)
        } else {
            status = .notPurchased
        }
    }

    /// Extracts a verified transaction from the `VerificationResult` helper.
    private func verificationPayload(from verification: VerificationResult<Transaction>) async throws -> Transaction? {
        switch verification {
        case .unverified:
            throw FullSubscriptionError.transactionUnverified
        case .verified(let transaction):
            return transaction
        }
    }
}

/// Custom error namespace used by `FullSubscriptionManager`.
public enum FullSubscriptionError: LocalizedError {
    case transactionUnverified

    public var errorDescription: String? {
        switch self {
        case .transactionUnverified:
            return "Impossibile verificare l'acquisto dell'abbonamento. Riprova più tardi."
        }
    }
}
