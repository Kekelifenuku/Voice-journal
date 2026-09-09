//  ContentView.swift — Voice Journal
//  App shell: tab container + onboarding gate.

import SwiftUI

struct RootView: View {
    private let onboardingKey = "vj_hard_paywall_onboarded_v1"
    @State private var showOnboarding =
        !UserDefaults.standard.bool(forKey: "vj_hard_paywall_onboarded_v1")
    @AppStorage("s_appearance") private var appearance = "system"
    @AppStorage("s_applang") private var appLang = "system"
    // Shared so the model preloaded during onboarding is still loaded once the app starts.
    @StateObject private var transcription = TranscriptionManager()
    // Shared entitlement observer; owns RevenueCat config for the app lifetime.
    @StateObject private var purchases = PurchaseManager()
    @Environment(\.scenePhase) private var rootScenePhase

    private var scheme: ColorScheme? {
        switch appearance { case "light": return .light; case "dark": return .dark; default: return nil }
    }

    @State private var showPaywall = false

    var body: some View {
        ZStack {
            if showOnboarding {
                OnboardingView(transcription: transcription) {
                    UserDefaults.standard.set(true, forKey: onboardingKey)
                    UserDefaults.standard.set(true, forKey: "vj_onboarded")
                    withAnimation(.easeInOut(duration: 0.45)) { showOnboarding = false }
                }
                .transition(.asymmetric(insertion: .opacity,
                                        removal: .move(edge: .bottom).combined(with: .opacity)))
                .zIndex(10)
            } else if !purchases.hasLoaded {
                EntitlementLoadingView()
            } else if purchases.isPro {
                RootTabView(transcription: transcription, purchases: purchases)
            } else if purchases.fetchFailed {
                // Couldn't verify entitlement (offline / transient). Don't strand a paying user
                // on the close-button-less paywall — offer Retry + Restore instead.
                EntitlementRecoveryView(purchases: purchases)
                    .transition(.opacity)
            } else {
                PaywallSheet(purchases: purchases, displayCloseButton: false)
                    .transition(.opacity)
            }
        }
        .environment(\.locale, AppLocale.locale)
        .preferredColorScheme(scheme)
        .environment(\.presentPaywall, PresentPaywall {
            guard !purchases.isPro else { return }        // never show to Pro users
            HX.tap(); showPaywall = true
        })
        .environment(\.isPro, purchases.isPro)
        .sheet(isPresented: $showPaywall) {
            PaywallSheet(purchases: purchases)
        }
        .onChange(of: rootScenePhase) { _, phase in
            if phase == .active { Task { await purchases.refresh() } }
        }
    }
}

private struct EntitlementLoadingView: View {
    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(Paper.terra)
                Text(L("Checking access"))
                    .font(Typo.sans(15, .medium))
                    .foregroundColor(Paper.ink2)
            }
        }
    }
}

/// Shown when the entitlement check couldn't reach the store (offline / transient error), so a
/// subscriber isn't locked out on the close-button-less paywall. Retry re-checks; Restore recovers.
private struct EntitlementRecoveryView: View {
    @ObservedObject var purchases: PurchaseManager
    @State private var busy = false

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 42, weight: .light))
                    .foregroundColor(Paper.terra.opacity(0.7))
                    .accessibilityHidden(true)
                Text(L("Couldn't verify your access"))
                    .font(Typo.sans(19, .semibold)).foregroundColor(Paper.ink)
                    .multilineTextAlignment(.center)
                Text(L("Check your connection and try again. If you've subscribed before, restore your purchase."))
                    .font(Typo.serifItalic(16)).foregroundColor(Paper.ink3)
                    .multilineTextAlignment(.center).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                VStack(spacing: 12) {
                    PrimaryCapsuleButton(title: "Try again", icon: "arrow.clockwise") {
                        guard !busy else { return }
                        busy = true
                        Task { await purchases.refresh(); busy = false }
                    }
                    Button {
                        guard !busy else { return }
                        busy = true
                        Task { await purchases.restore(); busy = false }
                    } label: {
                        Text(L("Restore purchase"))
                            .font(Typo.sans(15, .semibold)).foregroundColor(Paper.terra)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
                .opacity(busy ? 0.5 : 1)
            }
            .padding(.horizontal, 40)
        }
    }
}

struct RootTabView: View {
    @ObservedObject var transcription: TranscriptionManager
    @ObservedObject var purchases: PurchaseManager
    @StateObject private var store         = JournalStore()
    @StateObject private var engine        = AudioEngine()
    @StateObject private var settings      = AppSettings()
    @State private var tab = 0
    // Rebuilds the tab subtree when the app language changes so every localized
    // Text re-resolves against the newly selected .lproj. The StateObjects above
    // live on this (unchanged) view, so they and the selected tab survive the rebuild.
    @AppStorage("s_applang") private var appLang = "system"
    @Environment(\.scenePhase) private var scenePhase

    private func goToCapture() {
        withAnimation(.easeInOut(duration: 0.25)) { tab = 0 }
    }
    private func goToJournal() {
        withAnimation(.easeInOut(duration: 0.3)) { tab = 1 }
    }

    var body: some View {
        TabView(selection: $tab) {
            CaptureView(engine: engine, store: store, settings: settings,
                        transcription: transcription, goToJournal: goToJournal)
                .tag(0)
                .tabItem { Label(L("Capture"), systemImage: "mic.fill") }

            NavigationStack {
                JournalView(store: store, engine: engine, settings: settings,
                            transcription: transcription, goToCapture: goToCapture)
            }
            .tag(1)
            .tabItem { Label(L("Journal"), systemImage: "book.fill") }

            NavigationStack {
                InsightsView(store: store, engine: engine, settings: settings,
                             transcription: transcription, purchases: purchases,
                             goToCapture: goToCapture)
            }
            .tag(2)
            .tabItem { Label(L("Insights"), systemImage: "chart.bar.fill") }

            NavigationStack {
                FavoritesView(store: store, engine: engine, settings: settings,
                              transcription: transcription, goToCapture: goToCapture)
            }
            .tag(3)
            .tabItem { Label(L("Favorites"), systemImage: "heart.fill") }

            NavigationStack {
                SettingsView(settings: settings, store: store, transcription: transcription,
                             purchases: purchases)
            }
            .tag(4)
            .tabItem { Label(L("Settings"), systemImage: "gearshape.fill") }
        }
        .id(appLang)
        .tint(Paper.terra)
        .onAppear { store.audioEngine = engine }   // so deletes can stop playback of the removed entry
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)   // scale text, but cap the extremes
        .overlay(alignment: .bottom) {
            if store.pendingDelete != nil {
                UndoToast(title: "Entry deleted") { store.undoDelete() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 78)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.pendingDelete?.id)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, UserDefaults.standard.bool(forKey: "vj_pending_record") { tab = 0 }
        }
    }
}
