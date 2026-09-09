//  Purchases.swift — Voice Journal
//  RevenueCat-backed entitlement observer + config.

import Foundation
import Combine

#if canImport(RevenueCat)
import RevenueCat
#endif

/// Central place for RevenueCat identifiers used across the app.
enum Pro {
    /// RevenueCat entitlement that unlocks Pro features. Must match the identifier in the RevenueCat dashboard.
    static let entitlement = "pro"
    /// Which offering the paywall loads. `nil` → RevenueCat's currently-marked "Current" offering.
    static let offering: String? = nil
}

/// Public iOS API key from RevenueCat → Project settings → API keys → Apple app (starts with `appl_`).
/// Replace this before shipping; while it's empty the SDK compiles but returns no offerings.
private let revenueCatAPIKey = "appl_sclIewBCBKtTaeTvgtRftnuyIaM"

@MainActor
final class PurchaseManager: ObservableObject {
    @Published var isPro = false
    @Published var activePlan: String?
    @Published var hasLoaded = false
    /// True when the last entitlement check couldn't reach RevenueCat (offline / transient error),
    /// so the UI can distinguish "confirmed not Pro" from "couldn't verify" and avoid locking out
    /// an entitled user on a close-button-less paywall.
    @Published var fetchFailed = false

    #if canImport(RevenueCat)
    private final class Delegate: NSObject, PurchasesDelegate {
        weak var owner: PurchaseManager?
        func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
            Task { @MainActor in self.owner?.apply(customerInfo) }
        }
    }
    private let delegate = Delegate()
    #endif

    init() {
        #if DEBUG
        isPro = true
        activePlan = "Local Debug"
        hasLoaded = true
        #else
        #if canImport(RevenueCat)
        // Configure once. Safe to call from init because RevenueCat guards against double-configuration.
        if !Purchases.isConfigured {
            if revenueCatAPIKey.isEmpty {
                // Loud (but non-fatal) reminder to paste the key.
                NSLog("⚠️ Voice Journal: RevenueCat API key is missing — paste it into Purchases.swift.")
            }
            Purchases.logLevel = .warn
            Purchases.configure(withAPIKey: revenueCatAPIKey)
        }
        delegate.owner = self
        Purchases.shared.delegate = delegate

        // RevenueCat persists the last entitlement snapshot. Apply it synchronously so returning
        // users do not sit behind a network spinner every time the app launches; the refresh below
        // still reconciles it with the server immediately.
        if let cachedInfo = Purchases.shared.cachedCustomerInfo {
            apply(cachedInfo)
        }

        // Warm the offering cache alongside the entitlement refresh. RevenueCatUI then has the
        // packages ready when the hard paywall is presented instead of starting a second request.
        Task {
            async let entitlementRefresh: Void = refresh()
            async let paywallWarmup: Void = prefetchOfferings()
            _ = await (entitlementRefresh, paywallWarmup)
        }
        #else
        hasLoaded = true
        #endif
        #endif
    }

    /// Fetch the latest entitlement snapshot (call after purchases, on foreground, etc.).
    func refresh() async {
        #if DEBUG
        isPro = true
        activePlan = "Local Debug"
        hasLoaded = true
        #else
        #if canImport(RevenueCat)
        if let info = try? await Purchases.shared.customerInfo() {
            fetchFailed = false
            apply(info)
        } else {
            fetchFailed = true
            hasLoaded = true
        }
        #else
        hasLoaded = true
        #endif
        #endif
    }

    /// Restore any previously completed purchases, then refresh entitlements.
    func restore() async {
        #if DEBUG
        isPro = true
        activePlan = "Local Debug"
        hasLoaded = true
        #else
        #if canImport(RevenueCat)
        if let info = try? await Purchases.shared.restorePurchases() {
            fetchFailed = false
            apply(info)
        } else {
            fetchFailed = true
            hasLoaded = true
        }
        #else
        hasLoaded = true
        #endif
        #endif
    }

    #if canImport(RevenueCat)
    private func prefetchOfferings() async {
        _ = try? await Purchases.shared.offerings()
    }

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[Pro.entitlement]
        let active = entitlement?.isActive == true
        isPro = active
        hasLoaded = true
        fetchFailed = false
        if active {
            // Best-effort human label: prefer product id → title (Monthly/Annual/Lifetime), fall back to raw id.
            activePlan = Self.label(for: entitlement?.productIdentifier)
        } else {
            activePlan = nil
        }
    }

    private static func label(for productID: String?) -> String? {
        guard let id = productID?.lowercased() else { return nil }
        if id.contains("lifetime") { return "Lifetime" }
        if id.contains("annual") || id.contains("year") { return "Annual" }
        if id.contains("month") { return "Monthly" }
        return productID
    }
    #endif
}
