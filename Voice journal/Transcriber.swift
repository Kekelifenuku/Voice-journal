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
    /// Partial text streamed live during capture (empty when live streaming is off/unavailable).
    @Published var liveText: String = ""

    #if canImport(WhisperKit)
    private var pipe: WhisperKit?
    private var loadedModel = ""
    private var pending: [(id: UUID, url: URL)] = []   // serial transcription queue
    private var draining = false
    private var attempted: Set<UUID> = []              // entries transcribed this session (avoids re-spinning)
    private var streamer: AudioStreamTranscriber?
    private var streamTask: Task<Void, Never>?
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
        pipe = nil; attempted.removeAll(); pending.removeAll(); working.removeAll()
        state = .idle
        prepare()
        #endif
    }

    /// Begin live streaming transcription (opt-in beta). Best-effort: if the mic is unavailable
    /// or conflicts with the recorder, it silently no-ops — the recorded file is unaffected and
    /// the transcript still fills in from the saved audio on stop.
    func startLive() {
        liveText = ""
        #if canImport(WhisperKit)
        guard UserDefaults.standard.bool(forKey: "s_live"),
              let pipe, let tok = pipe.tokenizer else { return }
        let lang = languageCode
        let opts = DecodingOptions(language: lang == "auto" ? nil : lang,
                                   detectLanguage: lang == "auto",
                                   wordTimestamps: false)
        let ast = AudioStreamTranscriber(
            audioEncoder: pipe.audioEncoder,
            featureExtractor: pipe.featureExtractor,
            segmentSeeker: pipe.segmentSeeker,
            textDecoder: pipe.textDecoder,
            tokenizer: tok,
            audioProcessor: pipe.audioProcessor,
            decodingOptions: opts,
            stateChangeCallback: { [weak self] _, newState in
                let text = (newState.confirmedSegments.map { $0.text } + [newState.currentText])
                    .joined(separator: " ")
                Task { @MainActor in self?.liveText = Summarizer.tidy(text) }
            }
        )
        streamer = ast
        streamTask = Task {
            do { try await ast.startStreamTranscription() }
            catch { /* mic conflict/unavailable — ignore; file recording continues */ }
        }
        #endif
    }

    func stopLive() {
        #if canImport(WhisperKit)
        if let s = streamer { Task { await s.stopStreamTranscription() } }
        streamTask?.cancel()
        streamer = nil; streamTask = nil
        #endif
        liveText = ""
    }

    /// Queue an entry's audio for transcription (serial), then derive a summary + themes, and persist.
    func transcribe(_ entry: VoiceEntry, store: JournalStore, force: Bool = false) {
        guard force || entry.transcript.isEmpty else { return }
        #if canImport(WhisperKit)
        if force { attempted.remove(entry.id) }
        // Skip if already tried this session, or already queued/running.
        if !force && attempted.contains(entry.id) { return }
        if working.contains(entry.id) || pending.contains(where: { $0.id == entry.id }) { return }
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
                    attempted.insert(job.id)
                    if !out.text.isEmpty, var e = store.entries.first(where: { $0.id == job.id }) {
                        let digest = Summarizer.summarize(out.text, mood: e.mood)
                        e.transcript = out.text
                        e.summary    = digest.summary
                        e.themes     = digest.themes
                        e.words      = out.words
                        store.update(e)
                    }
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
        state = .transcribing
        let lang = languageCode
        let options = DecodingOptions(
            language: lang == "auto" ? nil : lang,
            detectLanguage: lang == "auto",
            wordTimestamps: true
        )
        do {
            // Explicit type selects the [TranscriptionResult] overload (vs the optional one).
            let results: [TranscriptionResult] = try await pipe.transcribe(audioPath: url.path, decodeOptions: options)
            let text = Summarizer.tidy(results.map(\.text).joined(separator: " "))
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

    /// Clean whitespace, and strip Whisper non-speech markers, from raw ASR output.
    static func tidy(_ raw: String) -> String {
        var s = raw
        // Remove non-speech tokens like [BLANK_AUDIO], [MUSIC], [ Silence ].
        s = s.replacingOccurrences(of: #"\[[^\]]{0,40}\]"#, with: "", options: .regularExpression)
        // Remove parentheticals that are clearly sound cues, e.g. (upbeat music), (applause).
        s = s.replacingOccurrences(
            of: #"\([^)]{0,40}(?:music|silence|noise|applause|laughter|inaudible)[^)]{0,40}\)"#,
            with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "\n", with: " ")
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func summarize(_ text: String, mood: Mood) -> (summary: String, themes: [String]) {
        let sentences = splitSentences(text)
        guard !sentences.isEmpty else { return ("", themes(for: text, mood: mood)) }

        // Score sentences by keyword overlap with the whole entry; keep top 2, in original order.
        let freq = wordFrequency(text)
        let scored = sentences.enumerated().map { (i, s) -> (Int, Double, String) in
            let words = tokenize(s)
            let score = words.reduce(0.0) { $0 + (freq[$1] ?? 0) } / Double(max(1, words.count))
            return (i, score, s)
        }
        let top = scored.sorted { $0.1 > $1.1 }.prefix(2).sorted { $0.0 < $1.0 }
        var summary = top.map { $0.2 }.joined(separator: " ")
        if summary.count > 320 { summary = String(summary.prefix(317)) + "…" }
        return (summary, themes(for: text, mood: mood))
    }

    // Theme tags: mood label first, then salient noun keywords.
    static func themes(for text: String, mood: Mood) -> [String] {
        var tags: [String] = []
        if mood != .none { tags.append(mood.label) }
        for kw in keywords(text, limit: 3) where !tags.contains(where: { $0.caseInsensitiveCompare(kw) == .orderedSame }) {
            tags.append(kw.capitalized)
            if tags.count >= 3 { break }
        }
        return tags
    }

    // MARK: helpers

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

    /// Salient nouns via NLTagger, ranked by frequency.
    private static func keywords(_ text: String, limit: Int) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var counts: [String: Int] = [:]
        let opts: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: opts) { tag, range in
            if tag == .noun {
                let w = text[range].lowercased()
                if w.count > 3 && !stop.contains(w) { counts[w, default: 0] += 1 }
            }
            return true
        }
        return counts.sorted { $0.value > $1.value }.map { $0.key }.prefix(limit).map { $0 }
    }
}
