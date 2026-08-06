//  Model.swift — Voice Journal
//  Entry model, store, moods and daily prompts.

import SwiftUI
import Combine
import Foundation

// MARK: - Mood

enum Mood: String, Codable, CaseIterable, Identifiable {
    case none, serene, joyful, pensive, tense, grateful, raw
    var id: String { rawValue }

    /// Warm, on-palette label.
    nonisolated var label: String {
        switch self {
        case .none:     return "—"
        case .serene:   return "Calm"
        case .joyful:   return "Joyful"
        case .pensive:  return "Pensive"
        case .tense:    return "Tense"
        case .grateful: return "Grateful"
        case .raw:      return "Raw"
        }
    }

    /// Small glyph used inline in tags.
    var glyph: String {
        switch self {
        case .none:     return "circle"
        case .serene:   return "leaf"
        case .joyful:   return "sun.max"
        case .pensive:  return "cloud"
        case .tense:    return "bolt"
        case .grateful: return "sparkles"
        case .raw:      return "flame"
        }
    }

    /// Warm swatch colors — together they read as a gentle gradient of warmth.
    var color: Color {
        switch self {
        case .none:     return Paper.muted
        case .serene:   return Color(0xB98A66)
        case .joyful:   return Color(0xC7906B)
        case .pensive:  return Color(0xA98F7A)
        case .tense:    return Color(0xA9694B)
        case .grateful: return Color(0xCBA36A)
        case .raw:      return Color(0x9C6650)
        }
    }

    static var selectable: [Mood] { allCases.filter { $0 != .none } }
}

// MARK: - Word timing

struct WordStamp: Codable, Hashable, Equatable {
    var text: String
    var start: Double
    var end: Double
}

// MARK: - Entry

struct VoiceEntry: Identifiable, Codable, Equatable, Hashable {
    var id        = UUID()
    var date      = Date()
    var duration:  TimeInterval
    var fileName:  String
    var title:     String
    var mood:      Mood   = .none
    var isFavorite        = false
    var note:      String = ""

    // Transcription (WhisperKit)
    var transcript: String = ""
    var summary:    String = ""
    var themes:     [String] = []
    var prompt:     String = ""
    var waveform:   [Double] = []   // normalized amplitude envelope (0…1) of the recording
    var words:      [WordStamp] = []// per-word timings for tap-to-seek
    /// On-device sentiment analysis (Apple NL). Range roughly -1…+1. `nil` = not computed.
    var sentiment:  Double? = nil

    init(duration: TimeInterval, fileName: String, title: String = "",
         mood: Mood = .none, note: String = "", prompt: String = "") {
        self.duration = duration
        self.fileName = fileName
        self.mood     = mood
        self.note     = note
        self.prompt   = prompt
        self.title    = title.isEmpty ? Self.smartTitle() : title
    }

    // Backward-compatible decoding: older entries lack transcript/summary/etc.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decodeIfPresent(UUID.self,         forKey: .id) ?? UUID()
        date       = try c.decodeIfPresent(Date.self,         forKey: .date) ?? Date()
        duration   = try c.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        fileName   = try c.decodeIfPresent(String.self,       forKey: .fileName) ?? ""
        title      = try c.decodeIfPresent(String.self,       forKey: .title) ?? Self.smartTitle()
        mood       = try c.decodeIfPresent(Mood.self,         forKey: .mood) ?? .none
        isFavorite = try c.decodeIfPresent(Bool.self,         forKey: .isFavorite) ?? false
        note       = try c.decodeIfPresent(String.self,       forKey: .note) ?? ""
        transcript = try c.decodeIfPresent(String.self,       forKey: .transcript) ?? ""
        summary    = try c.decodeIfPresent(String.self,       forKey: .summary) ?? ""
        themes     = try c.decodeIfPresent([String].self,     forKey: .themes) ?? []
        prompt     = try c.decodeIfPresent(String.self,       forKey: .prompt) ?? ""
        waveform   = try c.decodeIfPresent([Double].self,     forKey: .waveform) ?? []
        words      = try c.decodeIfPresent([WordStamp].self,  forKey: .words) ?? []
        sentiment  = try c.decodeIfPresent(Double.self,       forKey: .sentiment)
    }

    enum CodingKeys: String, CodingKey {
        case id, date, duration, fileName, title, mood, isFavorite, note, transcript, summary, themes, prompt, waveform, words, sentiment
    }

    // MARK: Derived

    static func smartTitle() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        let pool: [(Range<Int>, [String])] = [
            (5..<9,  ["First light", "Dawn thought", "Morning pages"]),
            (9..<12, ["Morning note", "Before noon", "AM reflection"]),
            (12..<14,["Midday pause", "Lunch hour", "Noon entry"]),
            (14..<17,["Afternoon drift", "Mid-afternoon", "Golden hour"]),
            (17..<20,["Evening entry", "Winding down", "Dusk thoughts"]),
            (20..<24,["Night journal", "Late evening", "Before sleep"]),
            (0..<5,  ["Can't sleep", "3am thought", "Night owl"])
        ]
        for (r, opts) in pool where r.contains(h) { return opts.randomElement()! }
        return "Untitled"
    }

    /// One-line preview: the transcript's opening if present, else the note, else a gentle placeholder.
    var preview: String {
        let source = !transcript.isEmpty ? transcript : note
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "A moment, captured in your voice." }
        return trimmed
    }

    var durationClock: String {
        let m = Int(duration) / 60, s = Int(duration) % 60
        return String(format: "%d:%02d", m, s)
    }

    nonisolated var durationLong: String {
        let total = Int(duration)
        let m = total / 60, s = total % 60
        if m == 0 { return "\(s) sec" }
        return "\(m) min \(String(format: "%02d", s)) sec"
    }

    var timeShort: String { date.formatted(.dateTime.hour().minute()) }

    var dayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    /// Feed group label — "Today", "Yesterday", "Mon, Jul 6".
    var groupLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let d = cal.dateComponents([.day], from: date, to: .now).day ?? 0
        if d < 7 { return date.formatted(.dateTime.weekday(.abbreviated)) }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

// MARK: - Store

@MainActor
final class JournalStore: ObservableObject {
    @Published var entries: [VoiceEntry] = []
    @Published var searchQuery = ""
    @Published var favOnly     = false
    @Published var moodFilter: Mood? = nil

    init() {
        entries = Store.load()
        backfillSentiments()
    }

    /// Score sentiment on any entry that has a transcript but no cached score yet
    /// (migrations from before sentiment existed, or restored backups).
    private func backfillSentiments() {
        let needs = entries.enumerated().compactMap { i, e -> (Int, String)? in
            (e.sentiment == nil && !e.transcript.isEmpty) ? (i, e.transcript) : nil
        }
        guard !needs.isEmpty else { return }
        Task.detached(priority: .utility) {
            let scored: [(Int, Double?)] = needs.map { ($0.0, Sentiment.score($0.1)) }
            await MainActor.run {
                var changed = false
                for (i, s) in scored where i < self.entries.count {
                    if self.entries[i].sentiment == nil {
                        self.entries[i].sentiment = s
                        changed = true
                    }
                }
                if changed { Store.save(self.entries) }
            }
        }
    }

    // Filtering / grouping
    func filtered() -> [VoiceEntry] {
        entries.filter {
            (searchQuery.isEmpty
                || $0.title.localizedCaseInsensitiveContains(searchQuery)
                || $0.note.localizedCaseInsensitiveContains(searchQuery)
                || $0.transcript.localizedCaseInsensitiveContains(searchQuery))
            && (!favOnly || $0.isFavorite)
            && (moodFilter == nil || $0.mood == moodFilter)
        }
        .sorted { $0.date > $1.date }
    }

    func groupedByDay() -> [(key: String, date: Date, entries: [VoiceEntry])] {
        let sorted = filtered()
        let g = Dictionary(grouping: sorted) { $0.dayKey }
        return g.keys.sorted(by: >).compactMap { k in
            guard let first = g[k]?.first else { return nil }
            return (key: k, date: first.date, entries: g[k]!.sorted { $0.date > $1.date })
        }
    }

    // Stats
    var totalSeconds: TimeInterval { entries.reduce(0) { $0 + $1.duration } }
    var totalFormatted: String {
        let mins = Int(totalSeconds) / 60
        return mins < 60 ? "\(mins)m" : "\(mins / 60)h \(mins % 60)m"
    }
    var streak: Int {
        var n = 0, d = Date()
        let cal = Calendar.current
        for _ in 0..<365 {
            if entries.contains(where: { cal.isDate($0.date, inSameDayAs: d) }) { n += 1 }
            else { break }
            d = cal.date(byAdding: .day, value: -1, to: d)!
        }
        return n
    }
    var daysWithEntries: Set<String> { Set(entries.map { $0.dayKey }) }

    /// Moods for the last 7 days (oldest→newest) for the weekly strip. `nil` = no entry that day.
    func weekMoods() -> [Mood?] {
        let cal = Calendar.current
        return (0..<7).reversed().map { back -> Mood? in
            let day = cal.date(byAdding: .day, value: -back, to: Date())!
            let dayEntries = entries.filter { cal.isDate($0.date, inSameDayAs: day) }
            // most recent entry's mood that day
            return dayEntries.sorted { $0.date > $1.date }.first?.mood
        }
    }

    // Mutations
    func add(_ e: VoiceEntry) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { entries.insert(e, at: 0) }
        save()
    }
    /// The entry disappears from the feed immediately, but its audio file is kept for a short
    /// grace period so an accidental delete can be reversed. `pendingDelete` drives the Undo toast.
    @Published var pendingDelete: VoiceEntry?
    private var pendingEntries: [UUID: VoiceEntry] = [:]
    private var deleteWork: [UUID: DispatchWorkItem] = [:]
    private let undoGrace: TimeInterval = 5

    func remove(_ e: VoiceEntry) {
        withAnimation(.easeOut(duration: 0.25)) { entries.removeAll { $0.id == e.id } }
        save()                                          // entry leaves the store; audio file lingers
        pendingEntries[e.id] = e
        pendingDelete = e
        let work = DispatchWorkItem { [weak self] in self?.finalizeDelete(e.id) }
        deleteWork[e.id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + undoGrace, execute: work)
    }

    /// Reverse the most recent delete while still inside the grace window.
    func undoDelete() {
        guard let e = pendingDelete else { return }
        deleteWork[e.id]?.cancel(); deleteWork[e.id] = nil
        pendingEntries[e.id] = nil
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            entries.insert(e, at: 0)
            entries.sort { $0.date > $1.date }
        }
        save(); HX.soft()
        pendingDelete = nil
    }

    /// Grace window elapsed — the audio file is now permanently removed.
    private func finalizeDelete(_ id: UUID) {
        deleteWork[id] = nil
        if let e = pendingEntries.removeValue(forKey: id) {
            try? FileManager.default.removeItem(at: Self.docURL(e.fileName))
        }
        if pendingDelete?.id == id { withAnimation(.easeOut(duration: 0.2)) { pendingDelete = nil } }
    }

    /// Force any lingering soft-deletes to finish (e.g. before a bulk wipe or app teardown).
    private func flushPendingDeletes() {
        deleteWork.values.forEach { $0.cancel() }; deleteWork.removeAll()
        pendingEntries.values.forEach { try? FileManager.default.removeItem(at: Self.docURL($0.fileName)) }
        pendingEntries.removeAll(); pendingDelete = nil
    }

    func update(_ e: VoiceEntry) {
        if let i = entries.firstIndex(where: { $0.id == e.id }) { entries[i] = e; save() }
    }
    func deleteAll() {
        flushPendingDeletes()
        entries.forEach { try? FileManager.default.removeItem(at: Self.docURL($0.fileName)) }
        withAnimation { entries.removeAll() }
        save()
    }

    // Persistence
    static func docURL(_ n: String) -> URL { Store.audioURL(n) }
    func docURL(_ n: String) -> URL { Store.audioURL(n) }

    /// Replace the whole store (used by restore).
    func replaceAll(_ newEntries: [VoiceEntry]) {
        deleteWork.values.forEach { $0.cancel() }; deleteWork.removeAll()
        pendingEntries.removeAll(); pendingDelete = nil
        withAnimation(.easeInOut(duration: 0.25)) { entries = newEntries }
        save()
    }

    private func save() { Store.save(entries) }

    /// Compute and persist the real amplitude envelope for an entry's audio, if not already done.
    func ensureWaveform(for entry: VoiceEntry) {
        guard entry.waveform.isEmpty else { return }
        let url = docURL(entry.fileName)
        let id = entry.id
        Task.detached(priority: .utility) {
            let env = WaveformExtractor.envelope(url: url)
            guard !env.isEmpty else { return }
            await MainActor.run {
                guard var e = self.entries.first(where: { $0.id == id }) else { return }
                e.waveform = env
                self.update(e)
            }
        }
    }
}

// MARK: - Daily prompts

enum Prompts {
    static let all: [String] = [
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

    /// Stable within a given calendar day.
    static func today(_ date: Date = Date()) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }
}

// MARK: - Daily motivation (local, offline)

enum Motivation {
    /// Original affirmations — warm and low-key, matching the app's voice (no external SDK).
    static let all: [String] = [
        "You don't have to have it all figured out to move forward.",
        "Small, honest steps still count as progress.",
        "Rest is part of the work, not a break from it.",
        "You've survived every hard day so far. That's not nothing.",
        "Speak to yourself the way you'd speak to a friend.",
        "You're allowed to change your mind, and to change your life.",
        "Not every day has to be productive to be meaningful.",
        "The fact that it's hard doesn't mean you're doing it wrong.",
        "Your feelings are information, not instructions.",
        "Begin before you feel ready — readiness often comes after.",
        "You can hold gratitude and grief in the same hand.",
        "Progress is quiet more often than it's loud.",
        "You are allowed to take up space and to be heard.",
        "One kind thing today can be for yourself.",
        "The goal isn't to be perfect; it's to keep showing up.",
        "What you practice grows stronger. Be gentle with what you feed.",
        "You don't owe anyone your constant availability.",
        "Slowing down is sometimes the bravest thing you can do.",
        "Your worth isn't measured by your output.",
        "It's okay if today was just about getting through it.",
        "Trust the version of you that keeps trying.",
        "You can start over as many times as you need to.",
        "The path clears as you walk it, not before.",
        "Let today be enough. You are enough.",
        "Courage is just fear that has said its piece and kept going.",
        "You can be a work in progress and still be worthy of love.",
        "Give yourself credit for what no one else can see.",
        "A calm mind is built one honest moment at a time.",
        "You're allowed to want more and to be at peace with now.",
        "Whatever you're carrying, you don't have to carry it perfectly."
    ]

    static func today(_ date: Date = Date()) -> String {
        // Offset from the prompt so the two don't move in lockstep.
        let day = (Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0) + 7
        return all[day % all.count]
    }
}
