//  Transcriber.swift — Voice Journal
//  On-device transcription (WhisperKit) + a local extractive summarizer.
//
//  The WhisperKit-specific code is guarded by `#if canImport(WhisperKit)`, so the
//  project builds before the Swift package is added and lights up automatically once it is.

import SwiftUI
import Combine
import Foundation
import NaturalLanguage

#if canImport(WhisperKit)
import WhisperKit
#endif

// MARK: - Model state

enum TranscriptionState: Equatable {
    case idle              // not started
    case preparing        // downloading / loading model
    case ready            // model loaded, waiting for audio
    case transcribing     // working on a clip
    case unavailable      // WhisperKit not linked
    case failed(String)   // error

    var isBusy: Bool { self == .preparing || self == .transcribing }
}

// MARK: - Manager

@MainActor
final class TranscriptionManager: ObservableObject {
    @Published var state: TranscriptionState = .idle
    /// IDs of entries currently being transcribed (drives per-row spinners).
    @Published var working: Set<UUID> = []
    /// IDs whose most recent transcription attempt failed (drives per-entry retry UI).
    @Published private(set) var failedEntries: Set<UUID> = []
    /// Partial text streamed live during capture (empty when live streaming is off/unavailable).
    @Published var liveText: String = ""

    #if canImport(WhisperKit)
    private var pipe: WhisperKit?
    private var loadedModel = ""
    private var pending: [(id: UUID, url: URL)] = []   // serial transcription queue
    private var draining = false
    private var attempted: Set<UUID> = []              // entries transcribed this session (avoids re-spinning)
    private var liveBuffer: [Float] = []          // accumulated 16 kHz mono samples during capture
    private var liveTask: Task<Void, Never>?
    private var liveActive = false
    private var inferring = false                  // single-flight gate: one WhisperKit inference at a time
    private var lastInferCount = 0
    #endif

    /// Model + language come from Settings (persisted to UserDefaults).
    var modelName: String { UserDefaults.standard.string(forKey: "s_model") ?? "base.en" }
    private var languageCode: String { UserDefaults.standard.string(forKey: "s_lang") ?? "en" }

    var isSupported: Bool {
        #if canImport(WhisperKit)
        return true
        #else
        return false
        #endif
    }

    /// Kick off model loading. Safe to call repeatedly.
    func prepare() {
        #if canImport(WhisperKit)
        guard pipe == nil, state != .preparing else { return }
        state = .preparing
        let requested = modelName
        Task {
            do {
                // Named model only. (Never bare `WhisperKit()` — it downloads the ~600MB
                // recommended model.) Transient failures are retried by `run`.
                let kit = try await WhisperKit(WhisperKitConfig(model: requested))
                self.pipe = kit
                self.loadedModel = requested
                self.state = .ready
            } catch {
                self.state = .failed(error.localizedDescription)
            }
        }
        #else
        state = .unavailable
        #endif
    }

    /// Reload after the user changes the model/language in Settings.
    func reload() {
        #if canImport(WhisperKit)
        liveActive = false; liveTask?.cancel(); liveTask = nil
        liveBuffer.removeAll(); lastInferCount = 0; inferring = false
        pipe = nil; attempted.removeAll(); pending.removeAll(); working.removeAll(); failedEntries.removeAll()
        state = .idle
        prepare()
        #endif
    }

    /// Begin live transcription (opt-in). The recorder (AudioEngine) owns the single mic and pushes
    /// 16 kHz samples via `feedLive`; we transcribe a rolling window as they arrive. This replaces the
    /// old AudioStreamTranscriber, which opened its *own* mic and fought AVAudioRecorder for it.
    func startLive() {
        liveText = ""
        #if canImport(WhisperKit)
        liveBuffer.removeAll(keepingCapacity: true)
        lastInferCount = 0
        liveActive = UserDefaults.standard.bool(forKey: "s_live")
        guard liveActive else { return }
        if pipe == nil { prepare() }   // start loading now; samples buffer until it's ready
        #endif
    }

    /// Push freshly captured 16 kHz mono samples from the recorder. No-ops unless live is active.
    func feedLive(_ samples: [Float]) {
        #if canImport(WhisperKit)
        guard liveActive, !samples.isEmpty else { return }
        liveBuffer.append(contentsOf: samples)
        // Only the tail is ever decoded, so cap the buffer — a long entry would otherwise hold the
        // entire recording in memory as Float32 (~3.8 MB/min) for no benefit.
        if liveBuffer.count > liveCap {
            let drop = liveBuffer.count - liveCap
            liveBuffer.removeFirst(drop)
            lastInferCount = max(0, lastInferCount - drop)
        }
        scheduleLive()
        #endif
    }

    func stopLive() {
        #if canImport(WhisperKit)
        liveActive = false
        liveTask?.cancel(); liveTask = nil
        liveBuffer.removeAll(keepingCapacity: false)
        lastInferCount = 0
        // Deliberately leave `inferring` as-is: any in-flight pass sets it false when it returns,
        // and the final file transcription (run) waits on it, so the two never overlap.
        #endif
        liveText = ""
    }

    #if canImport(WhisperKit)
    private var liveWindow: Int { 384_000 }   // decode the last ~24 s
    private var liveCap: Int { 400_000 }      // keep a little more than we decode

    /// Transcribe the most recent ~24 s of audio, single-flight. Re-arms itself if more audio arrived.
    private func scheduleLive() {
        guard liveActive, !inferring, let pipe, pipe.tokenizer != nil else { return }
        // Gate on ~0.8 s of new audio (12.8k samples @16 kHz) so we don't thrash the model, and require
        // ~1 s before the very first pass — decoding 0.5 s of audio mostly invents a phantom word.
        let fresh = liveBuffer.count - lastInferCount
        guard fresh >= 12_800 || (lastInferCount == 0 && liveBuffer.count >= 16_000) else { return }
        inferring = true
        lastInferCount = liveBuffer.count
        let window = Array(liveBuffer.suffix(liveWindow))
        let lang = languageCode
        liveTask = Task { [weak self] in
            let opts = DecodingOptions(language: lang == "auto" ? nil : lang,
                                       detectLanguage: lang == "auto",
                                       skipSpecialTokens: true,
                                       wordTimestamps: false)
            let results: [TranscriptionResult]? = try? await pipe.transcribe(audioArray: window, decodeOptions: opts)
            guard let self else { return }
            self.inferring = false
            if self.liveActive, let results {
                let text = Summarizer.tidy(results.map(\.text).joined(separator: " "))
                if !text.isEmpty { self.liveText = text }
            }
            if self.liveActive { self.scheduleLive() }     // catch up on audio that arrived mid-pass
        }
    }
    #endif

    /// Queue an entry's audio for transcription (serial), then derive a summary + themes, and persist.
    func transcribe(_ entry: VoiceEntry, store: JournalStore, force: Bool = false) {
        guard force || entry.transcript.isEmpty else { return }
        #if canImport(WhisperKit)
        if force { attempted.remove(entry.id) }
        // Skip if already tried this session, or already queued/running.
        if !force && attempted.contains(entry.id) { return }
        if working.contains(entry.id) || pending.contains(where: { $0.id == entry.id }) { return }
        failedEntries.remove(entry.id)
        working.insert(entry.id)
        pending.append((id: entry.id, url: store.docURL(entry.fileName)))
        drain(store: store)
        #else
        state = .unavailable
        #endif
    }

    #if canImport(WhisperKit)
    /// Process the queue one clip at a time (WhisperKit shares a single model instance).
    private func drain(store: JournalStore) {
        guard !draining else { return }
        draining = true
        if pipe == nil { prepare() }
        Task {
            while !pending.isEmpty {
                let job = pending.removeFirst()
                let out = await run(url: job.url)
                working.remove(job.id)
                if let out {                        // nil ⇒ model unavailable; leave un-attempted to retry later
                    failedEntries.remove(job.id)
                    attempted.insert(job.id)
                    if !out.text.isEmpty, var e = store.entries.first(where: { $0.id == job.id }) {
                        let digest = Summarizer.summarize(out.text, mood: e.mood)
                        e.transcript = out.text
                        e.summary    = digest.summary
                        e.themes     = digest.themes
                        e.words      = out.words
                        e.sentiment  = Sentiment.score(out.text)
                        // If the user didn't tag a mood, quietly suggest one from sentiment.
                        // (Never overrides an explicit choice.)
                        if e.mood == .none, let s = e.sentiment {
                            e.mood = Sentiment.suggestedMood(for: s)
                        }
                        store.update(e)
                    }
                } else if case .failed = state {
                    failedEntries.insert(job.id)
                }
            }
            draining = false
            if working.isEmpty, state == .transcribing { state = .ready }
        }
    }

    /// Wait for the model (through a first-time download), then transcribe with word timings.
    /// Returns nil if the model never became available (so the caller can retry later).
    private func run(url: URL) async -> (text: String, words: [WordStamp])? {
        if pipe == nil { prepare() }
        var retried = false
        var ticks = 0
        while pipe == nil {
            if case .failed = state {
                if retried { return nil }           // give up after one retry
                retried = true; state = .idle; prepare()
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            ticks += 1
            if ticks > 1200 { return nil }          // ~10 min hard ceiling
        }
        guard let pipe else { return nil }
        // Serialize with any live pass — WhisperKit runs a single inference at a time.
        while inferring { try? await Task.sleep(nanoseconds: 60_000_000) }
        inferring = true
        defer { inferring = false }
        state = .transcribing
        let lang = languageCode
        let options = DecodingOptions(
            language: lang == "auto" ? nil : lang,
            detectLanguage: lang == "auto",
            skipSpecialTokens: true,          // keeps <|nospeech|> etc. out of both text and words
            wordTimestamps: true
        )
        do {
            // Explicit type selects the [TranscriptionResult] overload (vs the optional one).
            let results: [TranscriptionResult] = try await pipe.transcribe(audioPath: url.path, decodeOptions: options)
            let text = Summarizer.tidy(results.map(\.text).joined(separator: " "))
            // Nothing real was said (silence → hallucinated boilerplate). Drop the word stamps too,
            // or the detail view's InteractiveTranscript would still render the fabricated line.
            guard !text.isEmpty else { return ("", []) }
            let words = results.flatMap { $0.segments }.flatMap { $0.words ?? [] }
                .map { WordStamp(text: $0.word, start: Double($0.start), end: Double($0.end)) }
            return (text, words)
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }
    #endif
}

// MARK: - Summarizer (on-device, extractive)

/// Produces a short reflective summary + theme tags from a transcript without a network call.
/// Extractive (selects representative sentences) + keyword/mood-derived themes.
enum Summarizer {

    /// Clean whitespace, strip Whisper non-speech markers, collapse its repetition loops, and drop
    /// the boilerplate it hallucinates over silence. Returns "" if nothing real was said.
    static func tidy(_ raw: String) -> String {
        var s = raw
        // Remove non-speech tokens like [BLANK_AUDIO], [MUSIC], [ Silence ].
        s = s.replacingOccurrences(of: #"\[[^\]]{0,40}\]"#, with: "", options: .regularExpression)
        // Remove parentheticals that are clearly sound cues, e.g. (upbeat music), (sighs).
        s = s.replacingOccurrences(
            of: #"\([^)]{0,40}(?:music|silence|noise|applause|laughter|inaudible|sighs?|coughs?|laughs?|clears throat|indistinct|unintelligible|crosstalk|blank_audio|static|beep|breathing)[^)]{0,40}\)"#,
            with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"[\u{266A}\u{266B}\u{2669}\u{266C}]"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\n", with: " ")
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)

        // Tidy punctuation orphaned by the strips above. Collapse "punct (space punct)+" runs FIRST
        // (each inner group needs a real space, so "…", "..." and "?!" are left alone), THEN remove a
        // lone space-before-punct — doing it in this order avoids fusing ". ." into an uncatchable "..".
        s = s.replacingOccurrences(of: #"([.!?])(?:\s+[.!?])+"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+([.,!?;:])"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^[\s.,!?;:]+"#, with: "", options: .regularExpression)

        s = collapseRepeats(s)
        s = stripHallucinations(s)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func summarize(_ text: String, mood: Mood) -> (summary: String, themes: [String]) {
        let sentences = dedupeSentences(splitSentences(text))
        // With 0–1 distinct sentences any "summary" is just the entry again — Reflect already shows
        // the transcript, so emit nothing rather than printing the same paragraph twice.
        guard sentences.count > 1 else { return ("", themes(for: text, mood: mood)) }

        // Score by keyword overlap with the whole entry; keep top 2, in original order.
        // Normalize by √length: a plain mean favours 2-word fragments, a plain sum favours rambling.
        let freq = wordFrequency(text)
        let scored = sentences.enumerated().map { (i, s) -> (Int, Double, String) in
            let words = tokenize(s)
            let total = words.reduce(0.0) { $0 + (freq[$1] ?? 0) }
            return (i, total / Double(max(1, words.count)).squareRoot(), s)
        }
        let top = scored.sorted { $0.1 > $1.1 }.prefix(2).sorted { $0.0 < $1.0 }
        var summary = clamp(top.map { $0.2 }.joined(separator: " "), to: 320)
        // If we just echoed the entry back, the summary card adds nothing.
        if fingerprint(summary) == fingerprint(text) { summary = "" }
        return (summary, themes(for: text, mood: mood))
    }

    /// Theme tags: salient noun keywords. Mood is deliberately not a tag — it has its own UI on the
    /// entry, and tags aren't recomputed when the mood changes, so a mood tag goes stale immediately.
    static func themes(for text: String, mood: Mood) -> [String] {
        var tags: [String] = []
        for kw in keywords(text, limit: 3)
        where !tags.contains(where: { $0.caseInsensitiveCompare(kw) == .orderedSame }) {
            tags.append(kw)
            if tags.count >= 3 { break }
        }
        return tags
    }

    // MARK: helpers

    /// Letters+digits only — for comparing two strings ignoring case, spacing and punctuation.
    private nonisolated static func fingerprint(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Trim to `limit`, cutting on a word boundary rather than mid-word.
    private static func clamp(_ s: String, to limit: Int) -> String {
        guard s.count > limit else { return s }
        let cut = String(s.prefix(limit - 1))
        if let sp = cut.lastIndex(of: " ") {
            return cut[..<sp].trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return cut + "…"
    }

    /// All sentences, unfiltered (unlike `splitSentences`, which drops very short ones).
    private static func allSentences(_ text: String) -> [String] {
        var out: [String] = []
        let t = NLTokenizer(unit: .sentence)
        t.string = text
        t.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { out.append(s) }
            return true
        }
        return out
    }

    private static func dedupeSentences(_ sentences: [String]) -> [String] {
        var seen: Set<String> = []
        return sentences.filter { seen.insert(fingerprint($0)).inserted }
    }

    /// Collapse Whisper's degenerate repetition loops ("I guess I guess I guess …"). Only fires on
    /// runs of ≥3 identical n-grams (>4 for single words, so "no, no, no" survives).
    private static func collapseRepeats(_ s: String) -> String {
        var tokens = s.split(separator: " ").map(String.init)
        guard tokens.count >= 24 else { return s }
        for n in stride(from: 8, through: 1, by: -1) {
            var out: [String] = []
            var i = 0
            while i < tokens.count {
                if i + n <= tokens.count {
                    let window = tokens[i..<(i + n)].map(fingerprint)
                    var reps = 1
                    var j = i + n
                    while j + n <= tokens.count, tokens[j..<(j + n)].map(fingerprint) == window {
                        reps += 1; j += n
                    }
                    if reps >= (n == 1 ? 5 : 3), !window.joined().isEmpty {
                        out.append(contentsOf: tokens[(j - n)..<j])   // keep the LAST copy — it carries the run's trailing punctuation
                        i = j
                        continue
                    }
                }
                out.append(tokens[i]); i += 1
            }
            tokens = out
        }
        // Then drop a sentence that exactly repeats the one before it.
        var kept: [String] = []
        var last = ""
        for sent in allSentences(tokens.joined(separator: " ")) {
            let f = fingerprint(sent)
            if !f.isEmpty, f == last { continue }
            kept.append(sent); last = f
        }
        return kept.joined(separator: " ")
    }

    /// Phrases Whisper fabricates over silence. Matched as a whole sentence only.
    private static let hallucinations: Set<String> = [
        "thankyou", "thankyouverymuch", "thankyouforwatching", "thanksforwatching",
        "pleasesubscribe", "subscribetomychannel", "bye", "byebye", "theend", "thanks", "you"
    ]

    /// Drop a clip that is *nothing but* fabricated boilerplate (the silence-hallucination signature).
    /// If any real sentence survives, the transcript is returned untouched — so a genuine entry that
    /// happens to end with "Thank you." keeps it verbatim.
    private static func stripHallucinations(_ s: String) -> String {
        let sents = allSentences(s)
        guard !sents.isEmpty else { return s }
        let real = sents.filter { !hallucinations.contains(fingerprint($0)) }
        return real.isEmpty ? "" : s
    }

    private static func splitSentences(_ text: String) -> [String] {
        var out: [String] = []
        let t = NLTokenizer(unit: .sentence)
        t.string = text
        t.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if s.count > 4 { out.append(s) }
            return true
        }
        return out
    }

    private static let stop: Set<String> = [
        "the","a","an","and","or","but","if","then","so","because","of","to","in","on","at","for","with",
        "i","you","he","she","it","we","they","me","my","your","this","that","these","those","is","am","are",
        "was","were","be","been","being","do","does","did","have","has","had","will","would","can","could",
        "just","really","kind","sort","like","about","up","down","out","not","no","yes","get","got","going",
        "know","think","feel","felt","today","yeah","um","uh","one","thing","things","some","more","been"
    ]

    private static func tokenize(_ s: String) -> [String] {
        s.lowercased().unicodeScalars.split { !CharacterSet.alphanumerics.contains($0) }
            .map { String($0) }.filter { $0.count > 2 && !stop.contains($0) }
    }

    private static func wordFrequency(_ text: String) -> [String: Double] {
        var f: [String: Double] = [:]
        for w in tokenize(text) { f[w, default: 0] += 1 }
        return f
    }

    /// Nouns too generic to be a useful "recurring theme".
    private static let genericNouns: Set<String> = ["stuff", "lot", "bit", "way", "moment", "part", "point"]

    /// Salient nouns via NLTagger, ranked by frequency. Folds plurals onto their lemma (day/days),
    /// keeps the original surface casing (iPhone stays iPhone), and breaks ties by first appearance
    /// so the same transcript always yields the same tags.
    private static func keywords(_ text: String, limit: Int) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text
        var counts: [String: Int] = [:]
        var display: [String: String] = [:]   // lemma → surface form as first written
        var order: [String: Int] = [:]        // lemma → first-appearance index (deterministic ties)
        var idx = 0
        let opts: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: opts) { tag, range in
            idx += 1
            guard tag == .noun else { return true }
            let surface = String(text[range])
            let lower = surface.lowercased()
            guard lower.count >= 3, !stop.contains(lower), !genericNouns.contains(lower) else { return true }
            let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue.lowercased()
            let key = (lemma?.isEmpty == false) ? lemma! : lower
            counts[key, default: 0] += 1
            if display[key] == nil { display[key] = surface; order[key] = idx }
            return true
        }
        // Capitalize only all-lowercase words, so "mom" → "Mom" but "iPhone"/"NYC" survive intact.
        func present(_ s: String) -> String { s == s.lowercased() ? s.capitalized : s }
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : (order[$0.key] ?? 0) < (order[$1.key] ?? 0) }
            .prefix(limit)
            .map { present(display[$0.key] ?? $0.key) }
    }

}
