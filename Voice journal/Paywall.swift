//  Paywall.swift — Voice Journal
//  RevenueCat Paywalls UI wrapper. The paywall itself is authored in the RevenueCat dashboard.

import SwiftUI

#if canImport(RevenueCatUI)
import RevenueCat
import RevenueCatUI
#endif

// MARK: - App-wide paywall trigger

/// A closure any view can call to present the paywall. Injected by `RootView`.
struct PresentPaywall {
    let action: () -> Void
    func callAsFunction() { action() }
}

private struct PresentPaywallKey: EnvironmentKey {
    static let defaultValue = PresentPaywall(action: {})
}
extension EnvironmentValues {
    var presentPaywall: PresentPaywall {
        get { self[PresentPaywallKey.self] }
        set { self[PresentPaywallKey.self] = newValue }
    }
}

/// Whether the current user has Pro. Injected by `RootView`, so any deep child can gate features
/// without threading `PurchaseManager` through navigation destinations.
private struct IsProKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var isPro: Bool {
        get { self[IsProKey.self] }
        set { self[IsProKey.self] = newValue }
    }
}

/// A sheet that renders the current RevenueCat paywall. On successful purchase / restore
/// it dismisses itself; the app's `PurchaseManager.isPro` observer flips independently.
struct PaywallSheet: View {
    @ObservedObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if canImport(RevenueCatUI)
        PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { _ in Task { await purchases.refresh(); dismiss() } }
            .onRestoreCompleted { info in
                Task {
                    await purchases.refresh()
                    if info.entitlements[Pro.entitlement]?.isActive == true { dismiss() }
                }
            }
        #else
        // Fallback used only until the RevenueCatUI package finishes resolving.
        VStack(spacing: 14) {
            Text("Paywall unavailable").font(Typo.sans(17, .semibold)).foregroundColor(Paper.ink)
            Text("RevenueCat isn't linked in this build.").font(Typo.sans(13)).foregroundColor(Paper.ink3)
        }
        .padding(24)
        #endif
    }
}
