//  Voice_journalApp.swift — Voice Journal

import SwiftUI
import StoreKit
import UIKit

@main
struct Voice_journalApp: App {
    init() {
        FontRegistrar.register()
        Appearance.apply()
        RatingManager.shared.registerLaunch()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear { RatingManager.shared.requestReviewIfNeeded() }
        }
    }
}

// MARK: - UIKit appearance (tab & nav bars tuned to Paper)

enum Appearance {
    static func apply() {
        // Adaptive so the chrome tracks light/dark.
        let tabBG = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(rgb: 0x1A1712, alpha: 0.92) : UIColor(rgb: 0xE9E2D5, alpha: 0.92) }
        let ink = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(rgb: 0xF0EBE0) : UIColor(rgb: 0x2B2620) }

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = tabBG
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [.foregroundColor: ink]
        nav.largeTitleTextAttributes = [.foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }
}

// MARK: - Rating

final class RatingManager {
    static let shared = RatingManager()
    private let launchKey = "vj_launch_count"
    private let ratedKey  = "vj_has_requested_review"

    func registerLaunch() {
        let d = UserDefaults.standard
        d.set(d.integer(forKey: launchKey) + 1, forKey: launchKey)
    }

    func requestReviewIfNeeded() {
        let d = UserDefaults.standard
        guard d.integer(forKey: launchKey) >= 3, !d.bool(forKey: ratedKey) else { return }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
        d.set(true, forKey: ratedKey)
    }
}
