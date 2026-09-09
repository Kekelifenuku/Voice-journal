//  VoiceJournalWidget.swift
//  Home-screen widget entry point. Content unlocks inside the main app after the paywall gate.

import WidgetKit
import SwiftUI

// MARK: - Palette (self-contained, adaptive)

private enum W {
    static func c(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { trait in
            let h = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((h >> 16) & 0xFF) / 255,
                           green: CGFloat((h >> 8) & 0xFF) / 255,
                           blue: CGFloat(h & 0xFF) / 255, alpha: 1)
        })
    }
    static let bg    = c(0xE9E2D5, 0x1A1712)
    static let ink   = c(0x2B2620, 0xF0EBE0)
    static let ink3  = c(0x8A8073, 0x9A9082)
    static let terra = c(0xA9694B, 0xCE8A63)
}

// MARK: - Timeline

struct PromptEntry: TimelineEntry {
    let date: Date
}

struct PromptProvider: TimelineProvider {
    func placeholder(in context: Context) -> PromptEntry {
        PromptEntry(date: Date())
    }
    func getSnapshot(in context: Context, completion: @escaping (PromptEntry) -> Void) {
        completion(PromptEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PromptEntry>) -> Void) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let entries = (0..<4).map { i -> PromptEntry in
            let day = cal.date(byAdding: .day, value: i, to: start)!
            return PromptEntry(date: day)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - View

struct PromptWidgetView: View {
    var entry: PromptEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "text.quote").font(.system(size: 10, weight: .semibold))
                Text("TODAY'S PROMPT").font(.system(size: 10, weight: .semibold)).tracking(1)
            }
            .foregroundColor(W.terra)

            // Literal string → LocalizedStringKey, so WidgetKit localizes it against the
            // widget target's String Catalog following the system language.
            Text("Open Voice Journal to unlock today's prompt.")
                .font(.system(size: family == .systemSmall ? 14 : 19, weight: .regular, design: .serif))
                .italic()
                .foregroundColor(W.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(family == .systemSmall ? 5 : 3)
                .fixedSize(horizontal: false, vertical: true)

            if family != .systemSmall {
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill").font(.system(size: 11, weight: .bold))
                    Text("Tap to open").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(W.terra)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { W.bg }
        .widgetURL(URL(string: "voicejournal://record"))
    }
}

// MARK: - Widget

struct PromptWidget: Widget {
    let kind = "VoiceJournalPromptWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PromptProvider()) { entry in
            PromptWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Prompt")
        .description("Open Voice Journal and continue your reflection.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct VoiceJournalWidgetBundle: WidgetBundle {
    var body: some Widget { PromptWidget() }
}
