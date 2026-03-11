import SwiftUI
import StoreKit
import StoreKit
import UIKit
@main
struct Voice_journalApp: App {
    
    init() {
        RatingManager.shared.registerLaunch()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    
    @State private var showOnboarding: Bool =
    !UserDefaults.standard.bool(forKey: "vj_onboarded")

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
                .transition(
                    .asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    )
                )
                .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            RatingManager.shared.requestReviewIfNeeded()
        }
    }
}


class RatingManager {

    static let shared = RatingManager()

    private let launchKey = "vj_launch_count"
    private let ratedKey = "vj_has_requested_review"

    func registerLaunch() {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: launchKey) + 1
        defaults.set(count, forKey: launchKey)
    }

    func requestReviewIfNeeded() {
        let defaults = UserDefaults.standard

        let launchCount = defaults.integer(forKey: launchKey)
        let hasRequested = defaults.bool(forKey: ratedKey)

        guard launchCount >= 2, !hasRequested else { return }

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }

        defaults.set(true, forKey: ratedKey)
    }
}
