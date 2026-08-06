//  Analytics.swift — Voice Journal
//  On-device analytics + algorithms: sentiment, similarity, trends, personalized prompts.
//  No network, no third party — everything runs locally on the user's phone.

import Foundation
import NaturalLanguage

// MARK: - Sentiment engine

enum Sentiment {
    /// Compute a sentiment score for the given text on-device.
    /// Range roughly -1 (very negative) … 0 (neutral) … +1 (very positive).
    /// Returns `nil` if the text is too short or the language model can't score it.
    static func score(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 12 else { return nil }
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = trimmed
        let (tag, _) = tagger.tag(at: trimmed.startIndex, unit: .paragraph, scheme: .sentimentScore)
        guard let s = tag?.rawValue, let v = Double(s) else { return nil }
        return v
    }

    /// A short, human-friendly label for a sentiment score.
    static func label(for s: Double) -> String {
        switch s {
        case ..<(-0.35): return "Heavy"
        case ..<(-0.10): return "Low"
        case ..<0.10:    return "Even"
        case ..<0.35:    return "Bright"
        default:         return "Uplifted"
        }
    }

    /// Best-fit mood suggestion from a sentiment score. Only used as a *suggestion*,
    /// never overrides a mood the user has explicitly set.
    static func suggestedMood(for s: Double) -> Mood {
        switch s {
        case ..<(-0.35): return .raw
        case ..<(-0.10): return .tense
        case ..<0.10:    return .pensive
        case ..<0.35:    return .serene
        default:         return .joyful
        }
    }
}

// MARK: - Similarity

enum Similarity {
    /// Score two entries 0…1 by Jaccard theme overlap + Jaccard content-word overlap.
    /// Cheap enough to run for every entry pair when needed; good enough for "you may want to revisit".
    static func score(_ a: VoiceEntry, _ b: VoiceEntry) -> Double {
        let ta = Set(a.themes.map { $0.lowercased() })
        let tb = Set(b.themes.map { $0.lowercased() })
        let themeScore: Double = jaccard(ta, tb)
        let wa = wordSet(from: a.transcript.isEmpty ? a.note : a.transcript)
        let wb = wordSet(from: b.transcript.isEmpty ? b.note : b.transcript)
        let wordScore = jaccard(wa, wb)
        // Themes weighted higher — they're already the "signal", words are context.
        return themeScore * 0.65 + wordScore * 0.35
    }

    /// Top-K entries most similar to `target`, excluding the target itself.
    static func similar(to target: VoiceEntry, in pool: [VoiceEntry], limit: Int = 3) -> [VoiceEntry] {
        pool
            .filter { $0.id != target.id }
            .map { ($0, score(target, $0)) }
            .filter { $0.1 > 0.05 }               // trivially-similar noise floor
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    // MARK: helpers

    private static let stop: Set<String> = [
        "the","a","an","and","or","but","if","then","so","because","of","to","in","on","at","for","with",
        "i","you","he","she","it","we","they","me","my","your","this","that","these","those","is","am","are",
        "was","were","be","been","being","do","does","did","have","has","had","will","would","can","could",
        "just","really","kind","sort","like","about","up","down","out","not","no","yes","get","got","going",
        "know","think","feel","felt","today","yeah","um","uh","one","thing","things","some","more","been"
    ]

    private static func wordSet(from text: String) -> Set<String> {
        Set(text.lowercased()
            .unicodeScalars.split { !CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .filter { $0.count > 3 && !stop.contains($0) })
    }

    private static func jaccard<T: Hashable>(_ a: Set<T>, _ b: Set<T>) -> Double {
        let union = a.union(b)
        guard !union.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(union.count)
    }
}

// MARK: - Trends & patterns

@MainActor
enum Trends {
    private static var cal: Calendar { Calendar.current }

    // ── Sentiment over time ─────────────────────────────────

    struct SentimentPoint: Identifiable {
        let id = UUID()
        let date: Date
        let sentiment: Double?           // daily average, `nil` if no scored entries that day
        let count: Int
    }

    /// Daily average sentiment for the last N days, oldest → newest.
    static func sentimentSeries(_ entries: [VoiceEntry], days: Int = 30) -> [SentimentPoint] {
        (0..<days).reversed().map { back in
            let day = cal.date(byAdding: .day, value: -back, to: Date())!
            let today = entries.filter { cal.isDate($0.date, inSameDayAs: day) }
            let scored = today.compactMap { $0.sentiment }
            let avg = scored.isEmpty ? nil : scored.reduce(0, +) / Double(scored.count)
            return SentimentPoint(date: day, sentiment: avg, count: today.count)
        }
    }

    /// Simple linear direction from earliest→latest scored day. Positive = trending brighter.
    static func sentimentDelta(_ entries: [VoiceEntry], days: Int = 30) -> Double? {
        let series = sentimentSeries(entries, days: days).compactMap { $0.sentiment }
        guard series.count >= 3 else { return nil }
        let first = series.prefix(series.count / 2).reduce(0, +) / Double(max(1, series.count / 2))
        let last  = series.suffix(series.count / 2).reduce(0, +) / Double(max(1, series.count / 2))
        return last - first
    }

    // ── When do you journal? ────────────────────────────────

    /// Counts of entries by hour bucket (0…23), for the whole store.
    static func hourHistogram(_ entries: [VoiceEntry]) -> [Int] {
        var buckets = Array(repeating: 0, count: 24)
        for e in entries {
            let h = cal.component(.hour, from: e.date)
            buckets[h] += 1
        }
        return buckets
    }

    /// Best 4-hour window label ("6–10 AM"). `nil` if not enough data.
    static func bestWindow(_ entries: [VoiceEntry]) -> String? {
        let h = hourHistogram(entries)
        guard h.reduce(0, +) >= 3 else { return nil }
        // Sliding 4-hour window; break ties toward earlier.
        var bestStart = 0, bestSum = -1
        for start in 0..<24 {
            let sum = (0..<4).reduce(0) { $0 + h[(start + $1) % 24] }
            if sum > bestSum { bestSum = sum; bestStart = start }
        }
        return "\(hourLabel(bestStart))–\(hourLabel((bestStart + 4) % 24))"
    }

    private static func hourLabel(_ h: Int) -> String {
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12) \(h < 12 ? "AM" : "PM")"
    }

    // ── Word count / speaking pace ──────────────────────────

    static func avgWordsPerEntry(_ entries: [VoiceEntry]) -> Int {
        let counts = entries.compactMap { $0.transcript.isEmpty ? nil : wordCount($0.transcript) }
        guard !counts.isEmpty else { return 0 }
        return counts.reduce(0, +) / counts.count
    }

    static func avgWordsPerMinute(_ entries: [VoiceEntry]) -> Int {
        let pairs = entries.compactMap { e -> (Int, Double)? in
            guard !e.transcript.isEmpty, e.duration > 5 else { return nil }
            return (wordCount(e.transcript), e.duration)
        }
        guard !pairs.isEmpty else { return 0 }
        let wpm = pairs.map { Double($0.0) / ($0.1 / 60) }.reduce(0, +) / Double(pairs.count)
        return Int(wpm.rounded())
    }

    private static func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    // ── Trending themes (last 30 vs prior 30 days) ───────────

    struct ThemeTrend { let theme: String; let recent: Int; let delta: Int }

    static func themeTrends(_ entries: [VoiceEntry], recentDays: Int = 30) -> [ThemeTrend] {
        let cutoff = cal.date(byAdding: .day, value: -recentDays, to: Date())!
        let priorCutoff = cal.date(byAdding: .day, value: -recentDays * 2, to: Date())!
        var recent: [String: Int] = [:]
        var prior:  [String: Int] = [:]
        for e in entries {
            let bucket: Int    // 0 = recent, 1 = prior, 2 = older
            if e.date > cutoff { bucket = 0 }
            else if e.date > priorCutoff { bucket = 1 }
            else { bucket = 2 }
            guard bucket < 2 else { continue }
            for t in e.themes {
                if bucket == 0 { recent[t, default: 0] += 1 }
                else           { prior[t, default: 0] += 1 }
            }
        }
        return recent.map { ThemeTrend(theme: $0.key, recent: $0.value, delta: $0.value - (prior[$0.key] ?? 0)) }
            .filter { $0.recent >= 2 }
            .sorted { $0.delta > $1.delta || ($0.delta == $1.delta && $0.recent > $1.recent) }
    }
}

// MARK: - Personalized prompts

enum PersonalPrompts {
    /// Today's prompt, biased away from themes the user has already been chewing on
    /// so each day feels like a fresh angle. Free-tier friendly (falls back to the plain rotation).
    static func today(entries: [VoiceEntry], date: Date = Date()) -> String {
        let baseIndex = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let base = Prompts.all[baseIndex % Prompts.all.count]

        // Not enough history to personalize → keep the standard rotation.
        guard entries.count >= 5 else { return base }

        // Frequency of recent themes (last 14 days).
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: date)!
        var recent: [String: Int] = [:]
        for e in entries where e.date > cutoff {
            for t in e.themes { recent[t.lowercased(), default: 0] += 1 }
        }
        guard !recent.isEmpty else { return base }

        // Score each prompt by *inverse* overlap with recent themes — we want variety.
        let ranked = Prompts.all.enumerated().map { (i, prompt) -> (String, Double) in
            let words = Set(prompt.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
            let overlap = words.reduce(0) { $0 + (recent[$1] ?? 0) }
            // Prefer prompts unrelated to what they've been writing; deterministic per day.
            let dayBias = Double((baseIndex &+ i) % 7) * 0.01
            return (prompt, -Double(overlap) + dayBias)
        }
        return ranked.max(by: { $0.1 < $1.1 })?.0 ?? base
    }
}
