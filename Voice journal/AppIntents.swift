//  AppIntents.swift — Voice Journal
//  Shortcuts / Siri support (runs in the main app target, no extension needed).

import AppIntents
import Foundation
import SwiftUI

/// Opens the app on Capture and starts a recording.
struct NewEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "New Voice Journal Entry"
    static var description = IntentDescription("Open Voice Journal ready to record a new entry.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "vj_pending_record")
        return .result()
    }
}

/// Speaks / returns today's reflection prompt without opening the app.
struct TodaysPromptIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Journal Prompt"
    static var description = IntentDescription("Get today's reflection prompt.")

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let prompt = Prompts.today()
        return .result(dialog: IntentDialog(stringLiteral: prompt)) {
            PromptSnippet(text: prompt)
        }
    }
}

private struct PromptSnippet: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's prompt").eyebrow()
            Text(text).font(Typo.serifItalic(20)).foregroundColor(Paper.ink)
        }
        .padding(18)
    }
}

struct VoiceJournalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewEntryIntent(),
            phrases: [
                "Add a \(.applicationName) entry",
                "New entry in \(.applicationName)",
                "Record a \(.applicationName)"
            ],
            shortTitle: "New Entry",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: TodaysPromptIntent(),
            phrases: [
                "What's my \(.applicationName) prompt",
                "Today's \(.applicationName) prompt"
            ],
            shortTitle: "Today's Prompt",
            systemImageName: "text.quote"
        )
    }
}
