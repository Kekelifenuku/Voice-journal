//
//  Voice_journalApp.swift
//  Voice journal
//
//  Created by Fenuku kekeli on 3/11/26.
//

import SwiftUI

@main
struct Voice_journalApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "vj_onboarded")

    var body: some View {
        ZStack {
            VoiceJournalView()

            if showOnboarding {
                OnboardingView {
                    UserDefaults.standard.set(true, forKey: "vj_onboarded")
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showOnboarding = false
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
    }
}
