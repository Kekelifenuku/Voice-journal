//  Analytics.swift — Voice Journal
//  On-device analytics + algorithms: sentiment, similarity, trends, personalized prompts.
//  No network, no third party — everything runs locally on the user's phone.

import Foundation
import NaturalLanguage

// MARK: - Sentiment engine

nonisolated enum Sentiment {
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
        case ..<(-0.35): return String(localized: "Heavy", bundle: AppLocale.bundle)
        case ..<(-0.10): return String(localized: "Low", bundle: AppLocale.bundle)
        case ..<0.10:    return String(localized: "Even", bundle: AppLocale.bundle)
        case ..<0.35:    return String(localized: "Bright", bundle: AppLocale.bundle)
        default:         return String(localized: "Uplifted", bundle: AppLocale.bundle)
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

    /// Themes the two entries share — the "why" behind a match (display casing from `a`).
    static func sharedThemes(_ a: VoiceEntry, _ b: VoiceEntry) -> [String] {
        let other = Set(b.themes.map { $0.lowercased() })
        var seen = Set<String>()
        return a.themes.filter { other.contains($0.lowercased()) && seen.insert($0.lowercased()).inserted }
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

// MARK: - Time-of-day buckets

/// Coarse parts of the day for "mood by time of day".
enum Daypart: CaseIterable {
    case morning, afternoon, evening, night

    static func of(hour h: Int) -> Daypart {
        switch h {
        case 5..<12:  return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default:      return .night
        }
    }
    var label: String {
        switch self {
        case .morning:   return String(localized: "Morning", bundle: AppLocale.bundle)
        case .afternoon: return String(localized: "Afternoon", bundle: AppLocale.bundle)
        case .evening:   return String(localized: "Evening", bundle: AppLocale.bundle)
        case .night:     return String(localized: "Night", bundle: AppLocale.bundle)
        }
    }
    var glyph: String {
        switch self {
        case .morning:   return "sunrise"
        case .afternoon: return "sun.max"
        case .evening:   return "sunset"
        case .night:     return "moon.stars"
        }
    }
}

// MARK: - Trends & patterns

@MainActor
enum Trends {
    private static var cal: Calendar { Calendar.current }
    private static var localeCal: Calendar {
        var c = Calendar.current; c.locale = AppLocale.locale; return c
    }

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
        sentimentDelta(from: sentimentSeries(entries, days: days))
    }

    /// Same trend, computed from an already-built series (avoids recomputing sentimentSeries).
    static func sentimentDelta(from points: [SentimentPoint]) -> Double? {
        let series = points.compactMap { $0.sentiment }
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
        // Locale-aware: "6 AM" in en, "06" in 24-hour locales — never hardcoded meridiem.
        var comps = DateComponents(); comps.hour = h % 24
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(.dateTime.hour().locale(AppLocale.locale))
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

    // ── Consistency ─────────────────────────────────────────

    /// Longest run of consecutive days with at least one entry, across all history.
    static func longestStreak(_ entries: [VoiceEntry]) -> Int {
        let days = Set(entries.map { cal.startOfDay(for: $0.date) }).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1, run = 1
        for i in 1..<days.count {
            let gap = cal.dateComponents([.day], from: days[i - 1], to: days[i]).day ?? 0
            if gap == 1 { run += 1; best = max(best, run) } else { run = 1 }
        }
        return best
    }

    /// Distinct days with an entry within the last `days` days (inclusive of today).
    static func activeDayCount(_ entries: [VoiceEntry], inLast days: Int) -> Int {
        guard days > 0 else { return 0 }
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(days - 1), to: Date())!)
        return Set(entries.map { cal.startOfDay(for: $0.date) }).filter { $0 >= start }.count
    }

    struct DayActivity: Identifiable { let id = UUID(); let date: Date; let count: Int }

    /// Per-day entry counts for the last `days` days, oldest → newest (for the consistency strip).
    static func activityStrip(_ entries: [VoiceEntry], days: Int) -> [DayActivity] {
        (0..<days).reversed().map { back in
            let day = cal.date(byAdding: .day, value: -back, to: Date())!
            let count = entries.filter { cal.isDate($0.date, inSameDayAs: day) }.count
            return DayActivity(date: day, count: count)
        }
    }

    // ── Weekly rhythm ───────────────────────────────────────

    struct WeekdayCount: Identifiable { let id = UUID(); let symbol: String; let count: Int }

    /// Entry counts per weekday, ordered by the locale's first weekday, with short symbols.
    static func weekdayRhythm(_ entries: [VoiceEntry]) -> [WeekdayCount] {
        let c = localeCal
        var counts = Array(repeating: 0, count: 7)   // index 0 = Sunday
        for e in entries { counts[c.component(.weekday, from: e.date) - 1] += 1 }
        let syms = c.shortWeekdaySymbols             // Sunday-first
        let first = c.firstWeekday - 1
        return (0..<7).map { i in
            let idx = (first + i) % 7
            return WeekdayCount(symbol: syms[idx], count: counts[idx])
        }
    }

    /// Full localized name of the weekday with the most entries (nil if no data).
    static func peakWeekday(_ entries: [VoiceEntry]) -> String? {
        let c = localeCal
        var counts = Array(repeating: 0, count: 7)
        for e in entries { counts[c.component(.weekday, from: e.date) - 1] += 1 }
        guard let idx = counts.indices.max(by: { counts[$0] < counts[$1] }), counts[idx] > 0 else { return nil }
        return c.weekdaySymbols[idx]
    }

    // ── Mood by time of day ─────────────────────────────────

    struct DaypartMood: Identifiable { let id = UUID(); let part: Daypart; let avgSentiment: Double?; let count: Int }

    static func moodByDaypart(_ entries: [VoiceEntry]) -> [DaypartMood] {
        var sums: [Daypart: [Double]] = [:]
        var counts: [Daypart: Int] = [:]
        for e in entries {
            let p = Daypart.of(hour: cal.component(.hour, from: e.date))
            counts[p, default: 0] += 1
            if let s = e.sentiment { sums[p, default: []].append(s) }
        }
        return Daypart.allCases.map { p in
            let arr = sums[p] ?? []
            let avg = arr.isEmpty ? nil : arr.reduce(0, +) / Double(arr.count)
            return DaypartMood(part: p, avgSentiment: avg, count: counts[p] ?? 0)
        }
    }

    /// The daypart with the brightest average sentiment (needs ≥2 scored entries in it).
    static func brightestDaypart(_ entries: [VoiceEntry]) -> Daypart? {
        moodByDaypart(entries)
            .filter { $0.avgSentiment != nil && $0.count >= 2 }
            .max(by: { ($0.avgSentiment ?? -2) < ($1.avgSentiment ?? -2) })?
            .part
    }

    // ── Emotional balance ───────────────────────────────────

    struct EmotionalBalance { let bright: Int; let even: Int; let heavy: Int; var total: Int { bright + even + heavy } }

    /// Split scored entries into bright / even / heavy by sentiment.
    static func emotionalBalance(_ entries: [VoiceEntry]) -> EmotionalBalance {
        var b = 0, e = 0, h = 0
        for x in entries {
            guard let s = x.sentiment else { continue }
            if s > 0.1 { b += 1 } else if s < -0.1 { h += 1 } else { e += 1 }
        }
        return EmotionalBalance(bright: b, even: e, heavy: h)
    }

    // ── Mood insights (from the moods you tag) ──────────────

    struct DominantMood { let mood: Mood; let count: Int; let share: Double }
    struct MoodShift    { let from: Mood; let to: Mood; let count: Int }

    /// Entries within the last `days` days (all of them if `days` is nil).
    private static func inLast(_ entries: [VoiceEntry], days: Int?) -> [VoiceEntry] {
        guard let days else { return entries }
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(days - 1), to: Date())!)
        return entries.filter { $0.date >= start }
    }

    /// The most-tagged mood in the window, with its share of tagged entries.
    static func dominantMood(_ entries: [VoiceEntry], days: Int? = nil) -> DominantMood? {
        let tagged = inLast(entries, days: days).filter { $0.mood != .none }
        guard !tagged.isEmpty else { return nil }
        var counts: [Mood: Int] = [:]
        for e in tagged { counts[e.mood, default: 0] += 1 }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        return DominantMood(mood: top.key, count: top.value, share: Double(top.value) / Double(tagged.count))
    }

    /// Average mood valence in the window (nil if nothing tagged). Maps onto Sentiment.label.
    static func moodValence(_ entries: [VoiceEntry], days: Int? = nil) -> Double? {
        let vals = inLast(entries, days: days).compactMap { $0.mood.valence }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }

    /// Change in mood valence: last 14 days vs the 14 before. Positive = brightening.
    static func moodValenceDelta(_ entries: [VoiceEntry]) -> Double? {
        let d14 = cal.date(byAdding: .day, value: -14, to: Date())!
        let d28 = cal.date(byAdding: .day, value: -28, to: Date())!
        let recent = entries.filter { $0.date > d14 }.compactMap { $0.mood.valence }
        let prior  = entries.filter { $0.date <= d14 && $0.date > d28 }.compactMap { $0.mood.valence }
        guard recent.count >= 2, prior.count >= 2 else { return nil }
        return recent.reduce(0, +) / Double(recent.count) - prior.reduce(0, +) / Double(prior.count)
    }

    /// The most common move from one tagged mood to a different one on the next entry.
    /// A tiny transition-frequency model over the mood sequence.
    static func topMoodTransition(_ entries: [VoiceEntry]) -> MoodShift? {
        let seq = entries.filter { $0.mood != .none }.sorted { $0.date < $1.date }
        guard seq.count >= 3 else { return nil }
        var counts: [String: (from: Mood, to: Mood, n: Int)] = [:]
        for i in 1..<seq.count {
            let a = seq[i - 1].mood, b = seq[i].mood
            guard a != b else { continue }
            let key = "\(a.rawValue)>\(b.rawValue)"
            counts[key] = (a, b, (counts[key]?.n ?? 0) + 1)
        }
        guard let best = counts.values.max(by: { $0.n < $1.n }), best.n >= 2 else { return nil }
        return MoodShift(from: best.from, to: best.to, count: best.n)
    }

    // ── Narrative digest + milestones ───────────────────────

    /// Total words across all transcribed entries — the "words spoken" milestone.
    static func totalWordsSpoken(_ entries: [VoiceEntry]) -> Int {
        entries.reduce(0) { $0 + ($1.transcript.isEmpty ? 0 : wordCount($1.transcript)) }
    }

    /// A short plain-language recap that synthesizes the other signals (1–2 sentences).
    static func monthlyDigest(_ entries: [VoiceEntry]) -> [String] {
        var lines: [String] = []
        let active = activeDayCount(entries, inLast: 30)
        let dom = dominantMood(entries, days: 30)

        if active >= 1, let dom {
            lines.append(String(localized: "You journaled \(active) of the last 30 days, mostly feeling \(dom.mood.label).", bundle: AppLocale.bundle))
        } else if let dom {
            lines.append(String(localized: "Lately you've mostly felt \(dom.mood.label).", bundle: AppLocale.bundle))
        } else if active >= 1 {
            lines.append(String(localized: "You journaled \(active) of the last 30 days.", bundle: AppLocale.bundle))
        }

        if let delta = moodValenceDelta(entries), abs(delta) > 0.1 {
            lines.append(delta >= 0
                ? String(localized: "Your mood has been brightening.", bundle: AppLocale.bundle)
                : String(localized: "Your mood has been softening lately.", bundle: AppLocale.bundle))
        } else if let bright = brightestDaypart(entries) {
            lines.append(String(localized: "You tend to feel brightest in the \(bright.label).", bundle: AppLocale.bundle))
        }
        return lines
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
