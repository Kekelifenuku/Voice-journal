//  DesignSystem.swift — Voice Journal
//  "Paper" — a warm, editorial light theme.
//  Palette, typography (bundled Hanken Grotesk + Newsreader), haptics, reusable styling.

import SwiftUI
import UIKit
import CoreText

// MARK: - Color helpers

extension Color {
    init(_ hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
    /// Adaptive color that resolves per light/dark appearance.
    init(light: UInt32, dark: UInt32) {
        self = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
    }
}

extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
    }
}

// MARK: - Palette (Paper) — adaptive light / dark

/// The signature warm editorial system, resolving to a warm-dark variant in dark mode.
enum Paper {
    // Surfaces
    static let bg       = Color(light: 0xE9E2D5, dark: 0x1A1712)   // page background
    static let card     = Color(light: 0xF6F1E8, dark: 0x242019)   // primary card
    static let cardAlt  = Color(light: 0xF1EADD, dark: 0x2C2720)   // secondary surface
    static let white    = Color(light: 0xFFFFFF, dark: 0x2F2A22)   // spotlight card (mood strip)
    static let espresso = Color(light: 0x3A342C, dark: 0x0F0D0A)   // dark audio pill

    // Ink
    static let ink   = Color(light: 0x2B2620, dark: 0xF0EBE0)      // primary text
    static let ink2  = Color(light: 0x5A5348, dark: 0xC8BFB0)      // secondary text
    static let ink3  = Color(light: 0x8A8073, dark: 0x9A9082)      // tertiary / labels
    static let muted = Color(light: 0xB4A896, dark: 0x6B6154)      // faint / placeholder

    // Accent — terracotta (a touch brighter in the dark)
    static let terra   = Color(light: 0xA9694B, dark: 0xCE8A63)
    static let terraLt = Color(light: 0xC7906B, dark: 0xD79B76)
    static let tan     = Color(light: 0xB98A66, dark: 0xC79A78)

    // Lines
    static let hair = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor.white.withAlphaComponent(0.09)
        : UIColor(rgb: 0x2B2620, alpha: 0.06) })

    // On-espresso (light text inside the dark pill — constant)
    static let onDark  = Color(0xF6F1E8)
    static let onDark2 = Color(0xF6F1E8, opacity: 0.55)

    /// Placeholder / hint text — darker than `muted` so it clears WCAG AA on the page.
    /// (`muted` stays reserved for non-text fills where its low contrast is fine.)
    static let placeholder = Color(light: 0x8A7F6E, dark: 0x8F857A)

    /// Destructive intent — adaptive so it reads on the warm-dark ground too.
    static let danger = Color(light: 0xB03A2E, dark: 0xE0715C)
}

// MARK: - Motion tokens

/// Named springs/curves so motion is consistent instead of scattered magic numbers.
enum Motion {
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.82)
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.85)
    static let gentle = Animation.easeInOut(duration: 0.25)
}

// MARK: - Typography

/// Font helper with graceful fallback to system fonts if the bundled
/// families failed to register (checked once, cached).
enum Typo {
    private static let sansName  = "Hanken Grotesk"
    private static let serifName = "Newsreader 16pt"

    static let hasSans:  Bool = UIFont(name: sansName, size: 12) != nil
    static let hasSerif: Bool = UIFont(name: serifName, size: 12) != nil

    /// Map a point size to the nearest text style so custom fonts scale with Dynamic Type.
    private static func style(_ size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<12: return .caption2
        case ..<14: return .caption
        case ..<16: return .subheadline
        case ..<19: return .body
        case ..<24: return .title3
        case ..<30: return .title2
        default:    return .largeTitle
        }
    }

    /// Hanken Grotesk (or SF Pro fallback). Scales with Dynamic Type (same size at default).
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        hasSans ? .custom(sansName, size: size, relativeTo: style(size)).weight(weight)
                : .system(size: size, weight: weight, design: .default)
    }

    /// Newsreader italic (or New York italic fallback) — used for prompts & quotes.
    static func serifItalic(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        hasSerif ? .custom(serifName, size: size, relativeTo: style(size)).weight(weight).italic()
                 : .system(size: size, weight: weight, design: .serif).italic()
    }
}

// MARK: - Font registration

enum FontRegistrar {
    /// Register every bundled .ttf at launch so `UIFont(name:)` / `Font.custom` resolve.
    static func register() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else { return }
        for url in urls {
            var err: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err)
            // Duplicate-registration errors are harmless; ignore.
        }
    }
}

// MARK: - Reusable styling

extension View {
    /// Standard cream card: rounded, hairline border, soft shadow.
    func paperCard(_ radius: CGFloat = 22, fill: Color = Paper.card) -> some View {
        self
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Paper.hair, lineWidth: 1)
            )
            .shadow(color: Color(0x2B2620, opacity: 0.05), radius: 14, x: 0, y: 6)
    }

    /// Small uppercase tracked label.
    func eyebrow(_ color: Color = Paper.terra) -> some View {
        self.font(Typo.sans(11, .semibold))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundColor(color)
    }
}

// MARK: - Circular icon button (menu / search / back)

struct CircleIconButton: View {
    let system: String
    var size: CGFloat = 44
    /// Localized VoiceOver label. Without it the control announces its raw SF Symbol name.
    var a11yLabel: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(Paper.ink2)
                .frame(width: size, height: size)
                .background(Paper.card)
                .clipShape(Circle())
                .overlay(Circle().stroke(Paper.hair, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11yLabel.map { Text(L($0)) } ?? Text(verbatim: system))
    }
}

// MARK: - Pressable button style (tactile feedback for primary controls)

/// Gentle press feedback so large shadowed CTAs visibly react to touch-down
/// (default `.plain` gives none). Respects Reduce Motion.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        Pressable(configuration: configuration, scale: scale)
    }
    // Inner View so @Environment is reliably injected (a ButtonStyle itself isn't a View).
    private struct Pressable: View {
        let configuration: Configuration
        let scale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        var body: some View {
            configuration.label
                .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? scale : 1))
                .opacity(configuration.isPressed ? 0.92 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
        }
    }
}

// MARK: - Pro badge (shared)

/// The small locked "PRO" pill, used by every upsell surface.
struct ProBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "lock.fill").font(.system(size: 8, weight: .bold))
            Text(L("PRO")).font(Typo.sans(9, .bold)).tracking(0.4)
        }
        .foregroundColor(Paper.white)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Paper.terra).clipShape(Capsule())
        .accessibilityLabel(L("Pro feature"))
    }
}

// MARK: - Stats row (shared by Insights + Settings)

/// A single stat (big value over a small label).
struct StatCell: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 5) {
            Text(value).font(Typo.sans(22, .bold)).foregroundColor(Paper.ink)
            Text(L(label)).font(Typo.sans(11, .medium)).foregroundColor(Paper.ink3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The three-up stat card (entries · recorded · streak). Each pair is (value, label).
struct StatRow: View {
    let stats: [(String, String)]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { i, s in
                if i > 0 {
                    Rectangle().fill(Paper.hair).frame(width: 1, height: 34)
                }
                StatCell(value: s.0, label: s.1)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .paperCard(22)
    }
}

// MARK: - Haptics

enum HX {
    static var enabled: Bool = UserDefaults.standard.object(forKey: "hx_enabled") as? Bool ?? true

    static func setEnabled(_ v: Bool) {
        enabled = v
        UserDefaults.standard.set(v, forKey: "hx_enabled")
    }

    static func tap()   { guard enabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func press() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func rigid() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func soft()  { guard enabled else { return }; UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func ok()    { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warn()  { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tick()  { guard enabled else { return }; UISelectionFeedbackGenerator().selectionChanged() }
}
