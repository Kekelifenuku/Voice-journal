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
}

/// Public iOS API key from RevenueCat → Project settings → API keys → Apple app (starts with `appl_`).
/// Replace this before shipping; while it's empty the SDK compiles but returns no offerings.
private let revenueCatAPIKey = "appl_sclIewBCBKtTaeTvgtRftnuyIaM"

@MainActor
final class PurchaseManager: ObservableObject {
    @Published var isPro = false
    @Published var activePlan: String?
    @Published var hasLoaded = false
    @Published private(set) var hasLoadedOffering = false
    /// True when the last entitlement check couldn't reach RevenueCat (offline / transient error),
    /// so the UI can distinguish "confirmed not Pro" from "couldn't verify" and avoid locking out
    /// an entitled user on a close-button-less paywall.
    @Published var fetchFailed = false

    #if canImport(RevenueCat)
    private var isRefreshingEntitlement = false
    private var entitlementRevision = 0

    private final class Delegate: NSObject, PurchasesDelegate {
        weak var owner: PurchaseManager?
        func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
            Task { @MainActor in self.owner?.apply(customerInfo) }
        }
    }
    private let delegate = Delegate()
    #endif

    #if DEBUG
    /// Debug-only escape hatch for exercising the hard paywall in a development build.
    /// A DEBUG build normally reports Pro immediately (so development doesn't need a sandbox
    /// purchase); enable this to skip that shortcut and run the real RevenueCat entitlement +
    /// offering path, landing a non-subscribed tester on the hard paywall after onboarding.
    ///
    /// Enable it per-run without editing code — Product ▸ Scheme ▸ Edit Scheme… ▸ Run ▸ Arguments,
    /// then add EITHER:
    ///   • Arguments Passed On Launch:  `-vj_debug_force_paywall YES`
    ///   • Environment Variable:        `VJ_FORCE_PAYWALL` = `1`
    /// Remove it to go back to the always-Pro dev shortcut. (Release builds ignore this entirely.)
    static var debugForcesPaywall: Bool {
        if UserDefaults.standard.bool(forKey: "vj_debug_force_paywall") { return true }
        let env = ProcessInfo.processInfo.environment["VJ_FORCE_PAYWALL"]?.lowercased()
        return env == "1" || env == "true" || env == "yes"
    }
    #endif

    init() {
        #if DEBUG
        // Default dev shortcut: report Pro so the app is usable without a sandbox purchase.
        // Opt out (to test the hard paywall) via `debugForcesPaywall` — see above.
        if !Self.debugForcesPaywall {
            isPro = true
            activePlan = "Local Debug"
            hasLoaded = true
            hasLoadedOffering = true
            return
        }
        #endif

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
            let cachedEntitlementIsActive = cachedInfo.entitlements[Pro.entitlement]?.isActive == true
            // An active cached entitlement may open immediately for offline continuity. An inactive
            // snapshot must not present the hard paywall until the initial network refresh confirms it.
            apply(cachedInfo, marksAccessLoaded: cachedEntitlementIsActive)
        }

        // Warm the offering cache alongside the entitlement refresh. RevenueCatUI then has the
        // packages ready when the hard paywall is presented. `PaywallView` still resolves the
        // current offering itself so RevenueCat offering experiments remain effective.
        Task {
            async let entitlementRefresh: Void = refresh()
            async let paywallWarmup: Void = warmPaywallOffering()
            _ = await (entitlementRefresh, paywallWarmup)
        }
        #else
        hasLoaded = true
        hasLoadedOffering = true
        #endif
    }

    /// Fetch the latest entitlement snapshot (call after purchases, on foreground, etc.).
    func refresh() async {
        #if DEBUG
        if !Self.debugForcesPaywall {
            isPro = true
            activePlan = "Local Debug"
            hasLoaded = true
            return
        }
        #endif
        #if canImport(RevenueCat)
        // Scene activation can overlap the startup refresh. Keep this request single-flight so a
        // redundant, later failure cannot replace an authoritative result that already succeeded.
        guard !isRefreshingEntitlement else { return }
        isRefreshingEntitlement = true
        defer { isRefreshingEntitlement = false }

        let startingRevision = entitlementRevision
        let info = try? await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
        // A purchase, restore, or delegate update that landed while this request was suspended is
        // newer than this refresh. Preserve that result instead of letting a stale response replace it.
        guard startingRevision == entitlementRevision else { return }

        if let info {
            fetchFailed = false
            apply(info)
        } else {
            fetchFailed = true
            hasLoaded = true
        }
        #else
        hasLoaded = true
        #endif
    }

    /// Restore any previously completed purchases, then refresh entitlements.
    func restore() async {
        #if DEBUG
        if !Self.debugForcesPaywall {
            isPro = true
            activePlan = "Local Debug"
            hasLoaded = true
            return
        }
        #endif
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
    }

    #if canImport(RevenueCat)
    private func warmPaywallOffering() async {
        defer { hasLoadedOffering = true }

        do {
            _ = try await Purchases.shared.offerings()
        } catch {
            // `PaywallView` retains its own error/retry UI; this log preserves the underlying cause.
            NSLog("⚠️ Voice Journal: RevenueCat offerings failed to load: %@", error.localizedDescription)
        }
    }

    /// Apply the authoritative result returned by RevenueCat purchase, restore, or refresh APIs.
    func apply(_ info: CustomerInfo, marksAccessLoaded: Bool = true) {
        entitlementRevision += 1
        let entitlement = info.entitlements[Pro.entitlement]
        let active = entitlement?.isActive == true
        isPro = active
        if marksAccessLoaded { hasLoaded = true }
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
