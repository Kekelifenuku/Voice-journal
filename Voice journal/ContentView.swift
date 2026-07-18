//  ContentView.swift — Voice Journal
//  App shell: tab container + onboarding gate.

import SwiftUI

struct RootView: View {
    @State private var showOnboarding =
        !UserDefaults.standard.bool(forKey: "vj_onboarded")
    @AppStorage("s_appearance") private var appearance = "system"
    // Shared so the model preloaded during onboarding is still loaded once the app starts.
    @StateObject private var transcription = TranscriptionManager()

    private var scheme: ColorScheme? {
        switch appearance { case "light": return .light; case "dark": return .dark; default: return nil }
    }

    var body: some View {
        ZStack {
            RootTabView(transcription: transcription)
            if showOnboarding {
                OnboardingView(transcription: transcription) {
                    UserDefaults.standard.set(true, forKey: "vj_onboarded")
                    withAnimation(.easeInOut(duration: 0.45)) { showOnboarding = false }
                }
                .transition(.asymmetric(insertion: .opacity,
                                        removal: .move(edge: .bottom).combined(with: .opacity)))
                .zIndex(10)
            }
        }
        .preferredColorScheme(scheme)
    }
}

struct RootTabView: View {
    @ObservedObject var transcription: TranscriptionManager
    @StateObject private var store         = JournalStore()
    @StateObject private var engine        = AudioEngine()
    @StateObject private var settings      = AppSettings()
    @StateObject private var cloud         = CloudBackupManager()
    @State private var tab = 0
    @Environment(\.scenePhase) private var scenePhase

    private func goToCapture() {
        withAnimation(.easeInOut(duration: 0.25)) { tab = 0 }
    }

    var body: some View {
        TabView(selection: $tab) {
            CaptureView(engine: engine, store: store, settings: settings,
                        transcription: transcription)
                .tag(0)
                .tabItem { Label("Capture", systemImage: "mic.fill") }

            NavigationStack {
                JournalView(store: store, engine: engine, settings: settings,
                            transcription: transcription, goToCapture: goToCapture)
            }
            .tag(1)
            .tabItem { Label("Journal", systemImage: "book.fill") }

            NavigationStack {
                InsightsView(store: store, engine: engine, settings: settings,
                             transcription: transcription, goToCapture: goToCapture)
            }
            .tag(2)
            .tabItem { Label("Insights", systemImage: "chart.bar.fill") }

            NavigationStack {
                FavoritesView(store: store, engine: engine, settings: settings,
                              transcription: transcription, goToCapture: goToCapture)
            }
            .tag(3)
            .tabItem { Label("Favorites", systemImage: "heart.fill") }

            NavigationStack {
                SettingsView(settings: settings, store: store, transcription: transcription, cloud: cloud)
            }
            .tag(4)
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
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
