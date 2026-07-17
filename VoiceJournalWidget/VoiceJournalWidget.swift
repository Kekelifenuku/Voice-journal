//  VoiceJournalWidget.swift
//  Home-screen widget showing today's reflection prompt (derived from the date — no shared data).

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

    // Mirrors the app's prompt pack so the widget matches without a shared target.
    static let prompts: [String] = [
        "What's been quietly taking up space in your mind lately?",
        "What did today ask of you — and how did you answer?",
        "Where did you feel most like yourself today?",
        "What's one thing you're carrying that you could set down?",
        "What surprised you in the last day or two?",
        "Who or what are you grateful for right now?",
        "What decision are you circling but not making?",
        "What did your body tell you today that your mind ignored?",
        "If today had a single sentence, what would it be?",
        "What do you want less of? What do you want more of?",
        "What's a small win you haven't let yourself notice?",
        "What would you tell yourself from a week ago?",
        "What are you avoiding, and what might be underneath it?",
        "When did you last feel genuinely at ease?",
        "What's changing in you that's hard to put into words?"
    ]
    static func today(_ date: Date = Date()) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return prompts[day % prompts.count]
    }
}

// MARK: - Timeline

struct PromptEntry: TimelineEntry {
    let date: Date
    let prompt: String
}

struct PromptProvider: TimelineProvider {
    func placeholder(in context: Context) -> PromptEntry {
        PromptEntry(date: Date(), prompt: W.today())
    }
    func getSnapshot(in context: Context, completion: @escaping (PromptEntry) -> Void) {
        completion(PromptEntry(date: Date(), prompt: W.today()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PromptEntry>) -> Void) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let entries = (0..<4).map { i -> PromptEntry in
            let day = cal.date(byAdding: .day, value: i, to: start)!
            return PromptEntry(date: day, prompt: W.today(day))
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

            Text(entry.prompt)
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
                    Text("Tap to record").font(.system(size: 12, weight: .semibold))
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
        .description("Today's reflection prompt. Tap to open and record.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct VoiceJournalWidgetBundle: WidgetBundle {
    var body: some Widget { PromptWidget() }
}
