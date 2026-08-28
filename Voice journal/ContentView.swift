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

struct RootTabView: View {
    @ObservedObject var transcription: TranscriptionManager
    @ObservedObject var purchases: PurchaseManager
    @StateObject private var store         = JournalStore()
    @StateObject private var engine        = AudioEngine()
    @StateObject private var settings      = AppSettings()
    @StateObject private var cloud         = CloudBackupManager()
    @State private var tab = 0
    // Rebuilds the tab subtree when the app language changes so every localized
    // Text re-resolves against the newly selected .lproj. The StateObjects above
    // live on this (unchanged) view, so they and the selected tab survive the rebuild.
    @AppStorage("s_applang") private var appLang = "system"
    @Environment(\.scenePhase) private var scenePhase

    private func goToCapture() {
        withAnimation(.easeInOut(duration: 0.25)) { tab = 0 }
    }

    var body: some View {
        TabView(selection: $tab) {
            CaptureView(engine: engine, store: store, settings: settings,
                        transcription: transcription)
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
                             cloud: cloud, purchases: purchases)
            }
            .tag(4)
            .tabItem { Label(L("Settings"), systemImage: "gearshape.fill") }
        }
        .id(appLang)
        .tint(Paper.terra)
        .task { cloud.attach(store: store, settings: settings) }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)   // scale text, but cap the extremes
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
