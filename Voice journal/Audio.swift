//  Audio.swift — Voice Journal
//  Recording + playback engine.

import SwiftUI
import Combine
import AVFoundation

@MainActor
final class AudioEngine: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    enum State { case idle, recording, paused, playing }

    @Published var state: State           = .idle
    @Published var elapsed: TimeInterval  = 0
    @Published var bars: [CGFloat]        = Array(repeating: 0.04, count: 48)
    @Published var level: CGFloat         = 0        // instantaneous mic level 0…1
    @Published var playProgress: Double   = 0
    @Published var playingID: UUID?
    @Published var playSpeed: Float       = 1.0
    @Published var playTime: TimeInterval = 0
    @Published var playDuration: TimeInterval = 0

    /// Set when the mic permission is denied — CaptureView observes it to guide the user to Settings.
    @Published var micDenied = false
    /// Set when recording couldn't start despite permission (mic busy / no input).
    @Published var recordStartFailed = false

    private var recorder:   AVAudioRecorder?
    private var player:     AVAudioPlayer?
    private var recClock:   Timer?
    private var meterTimer: Timer?
    private var playTimer:  Timer?
    private var recStart:   Date?
    private var pausedAt:   TimeInterval = 0
    private var pendingFile: String?

    private var session:    RecordingSession?     // single-engine path, used when live transcription is on
    private var usingEngine = false
    private var wasInterrupted = false            // recording was paused by a system interruption

    override init() {
        super.init()
        // Pause/resume recording around system interruptions (calls, Siri, alarms) so audio isn't
        // truncated while the clock keeps running — otherwise the saved entry reports dead time.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        }
    }

    private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            if state == .recording { pauseRecording(); wasInterrupted = true }
        case .ended:
            guard wasInterrupted else { return }
            wasInterrupted = false
            let opts = AVAudioSession.InterruptionOptions(
                rawValue: info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            // Resume only if the system says we may; otherwise stay paused (clock frozen) so the
            // user can resume or finish — the recording keeps the audio captured before the call.
            if opts.contains(.shouldResume), state == .paused { resumeRecording() }
        @unknown default:
            break
        }
    }

    /// (fileName, duration) once a recording finishes.
    var onRecordFinish: ((String, TimeInterval) -> Void)?
    /// 16 kHz mono samples delivered during capture for live transcription (set by CaptureView).
    var onLiveSamples: (([Float]) -> Void)?

    private var wantsLive: Bool { onLiveSamples != nil && UserDefaults.standard.bool(forKey: "s_live") }

    // MARK: Recording

    func requestAndRecord() {
        AVAudioApplication.requestRecordPermission { [weak self] ok in
            Task { @MainActor in
                guard let self else { return }
                if ok { self.startRecording() }
                else { self.micDenied = true }
            }
        }
    }

    private func startRecording() {
        if state == .playing { stopPlaying() }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? s.setActive(true)
        let name = "vj_\(UUID().uuidString).m4a"; pendingFile = name

        // Live on → single AVAudioEngine (mic → file + 16 kHz feed). Otherwise the proven recorder.
        // If the engine path can't start (e.g. no input), fall back so recording still works.
        let started = (wantsLive && startEngine(name: name)) || startRecorder(name: name)
        guard started else {
            Store.removeAudio(named: name)
            state = .idle; pendingFile = nil; recordStartFailed = true
            return
        }

        recStart = Date(); elapsed = 0; pausedAt = 0; state = .recording
        startClock()
    }

    private func startEngine(name: String) -> Bool {
        guard let sess = try? RecordingSession(url: Self.docURL(name)) else { return false }
        sess.onLevel   = { [weak self] lvl in Task { @MainActor in self?.applyLevel(lvl) } }
        sess.onSamples = { [weak self] samples in Task { @MainActor in self?.onLiveSamples?(samples) } }
        do { try sess.start() } catch { sess.stop(); return false }
        session = sess; usingEngine = true
        return true
    }

    private func startRecorder(name: String) -> Bool {
        let cfg: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        guard let r = try? AVAudioRecorder(url: Self.docURL(name), settings: cfg) else { return false }
        r.delegate = self; r.isMeteringEnabled = true
        guard r.prepareToRecord(), r.record() else { return false }
        recorder = r
        usingEngine = false
        startMeterTimer()
        return true
    }

    private func startClock() {
        recClock?.invalidate()
        recClock = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let t = self.recStart else { return }
                self.elapsed = self.pausedAt + Date().timeIntervalSince(t)
            }
        }
    }

    private func startMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleMeter() }
        }
    }

    func pauseRecording() {
        guard state == .recording else { return }
        if usingEngine { session?.pause() } else { recorder?.pause() }
        pausedAt += Date().timeIntervalSince(recStart ?? Date())
        recClock?.invalidate(); meterTimer?.invalidate()
        state = .paused
    }

    func resumeRecording() {
        guard state == .paused else { return }
        if usingEngine {
            do { try session?.resume() }
            catch { recordStartFailed = true; return }
        } else {
            guard recorder?.record() == true else { recordStartFailed = true; return }
            startMeterTimer()
        }
        recStart = Date(); state = .recording
        startClock()
    }

    func stopRecording() {
        guard state == .recording || state == .paused else { return }
        let duration = state == .recording
            ? pausedAt + max(0, Date().timeIntervalSince(recStart ?? Date()))
            : pausedAt
        if usingEngine { session?.stop(); session = nil; usingEngine = false }
        else { recorder?.stop(); recorder = nil }
        recClock?.invalidate(); meterTimer?.invalidate()
        state = .idle; elapsed = 0; pausedAt = 0; level = 0
        bars = Array(repeating: 0.04, count: bars.count)
        if let f = pendingFile { onRecordFinish?(f, duration) }
        pendingFile = nil
    }

    private func sampleMeter() {
        recorder?.updateMeters()
        let p = recorder?.averagePower(forChannel: 0) ?? -80
        applyLevel(CGFloat(max(0, (p + 70) / 70)))
    }

    /// Push an instantaneous 0…1 level into the meter + scrolling bars (used by both record paths).
    private func applyLevel(_ n: CGFloat) {
        level = n
        guard !bars.isEmpty else { return }
        bars.removeFirst(); bars.append(max(0.04, n * 0.96))
    }

    // MARK: Playback

    func play(entry: VoiceEntry, speed: Float? = nil) {
        guard state != .recording, state != .paused else { return }
        stopPlaying()
        let url = Self.docURL(entry.fileName)
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback); try? s.setActive(true)
        let spd = speed ?? playSpeed
        player = p; p.delegate = self; p.enableRate = true; p.rate = spd
        guard p.play() else { player = nil; return }
        state = .playing; playingID = entry.id
        playDuration = p.duration; playSpeed = spd; playProgress = 0; playTime = 0
        playTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let pl = self.player else { return }
                self.playTime = pl.currentTime
                self.playProgress = pl.duration > 0 ? pl.currentTime / pl.duration : 0
            }
        }
    }

    func togglePlay(entry: VoiceEntry) {
        if playingID == entry.id && state == .playing { stopPlaying() }
        else { play(entry: entry) }
    }

    func seek(to fraction: Double) {
        guard let p = player else { return }
        let clamped = min(max(0, fraction), 1)
        p.currentTime = p.duration * clamped
        playTime = p.currentTime; playProgress = clamped
    }
    func skip(seconds: Double) {
        guard let p = player else { return }
        let t = min(max(0, p.currentTime + seconds), p.duration)
        p.currentTime = t; playTime = t
        playProgress = p.duration > 0 ? t / p.duration : 0
    }
    func setSpeed(_ s: Float) { playSpeed = s; player?.rate = s }
    func cycleSpeed() {
        let speeds: [Float] = [1.0, 1.5, 2.0, 0.5]
        let i = speeds.firstIndex(of: playSpeed) ?? 0
        setSpeed(speeds[(i + 1) % speeds.count])
    }
    func stopPlaying() {
        player?.stop(); playTimer?.invalidate()
        player = nil; playingID = nil; playProgress = 0; playTime = 0; playDuration = 0
        if state == .playing { state = .idle }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stopPlaying() }
    }

    // MARK: Helpers
    static func docURL(_ n: String) -> URL {
        Store.audioURL(n)
    }
    func fmt(_ t: TimeInterval) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }
    func elapsedFormatted() -> String { fmt(elapsed) }
}

// MARK: - Live recording session

/// Owns a single AVAudioEngine input tap. Writes the recording to `url` (AAC .m4a) and, when a
/// live-samples consumer is attached, emits resampled 16 kHz mono float chunks for transcription.
/// One mic consumer avoids the AVAudioRecorder-vs-WhisperKit conflict that broke live streaming.
final class RecordingSession: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let file: AVAudioFile
    private let inFormat: AVAudioFormat
    private let live16k: AVAudioFormat?
    private var writeConverter: AVAudioConverter?   // only if the file's format differs from the tap's
    private var liveConverter: AVAudioConverter?

    /// Instantaneous 0…1 level (called on the audio thread).
    var onLevel: (@Sendable (CGFloat) -> Void)?
    /// 16 kHz mono float samples (called on the audio thread).
    var onSamples: (@Sendable ([Float]) -> Void)?

    init(url: URL) throws {
        let format = engine.inputNode.inputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw NSError(domain: "VJRecording", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No audio input available."])
        }
        inFormat = format
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        file = try AVAudioFile(forWriting: url, settings: settings)
        if file.processingFormat != inFormat {
            writeConverter = AVAudioConverter(from: inFormat, to: file.processingFormat)
        }
        live16k = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                channels: 1, interleaved: false)
        if let live16k { liveConverter = AVAudioConverter(from: inFormat, to: live16k) }
    }

    func start() throws {
        engine.inputNode.installTap(onBus: 0, bufferSize: 2_048, format: inFormat) { [weak self] buf, _ in
            self?.process(buf)
        }
        engine.prepare()
        try engine.start()
    }
    func pause() { engine.pause() }
    func resume() throws { try engine.start() }
    func stop() { engine.inputNode.removeTap(onBus: 0); engine.stop() }

    private func process(_ buffer: AVAudioPCMBuffer) {
        if let wc = writeConverter {
            if let out = Self.convert(buffer, with: wc, to: file.processingFormat) { try? file.write(from: out) }
        } else {
            try? file.write(from: buffer)
        }
        onLevel?(Self.level(buffer))
        if let onSamples, let lc = liveConverter, let live16k,
           let out = Self.convert(buffer, with: lc, to: live16k) {
            let samples = Self.floats(out)
            if !samples.isEmpty { onSamples(samples) }
        }
    }

    // MARK: helpers

    /// One-shot convert (incl. sample-rate change) of a single buffer; the converter is reused so it
    /// keeps resampler state across calls (we signal `.noDataNow`, never `.endOfStream`).
    private static func convert(_ input: AVAudioPCMBuffer, with converter: AVAudioConverter, to out: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = out.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1_024
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: out, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: outBuffer, error: &error) { _, inStatus in
            if supplied { inStatus.pointee = .noDataNow; return nil }
            supplied = true
            inStatus.pointee = .haveData
            return input
        }
        return status == .error ? nil : outBuffer
    }

    private static func level(_ buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let ch = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let n = Int(buffer.frameLength)
        let d = ch[0]
        var sum: Float = 0
        var i = 0
        while i < n { sum += d[i] * d[i]; i += 1 }
        let rms = sqrt(sum / Float(n))
        let db = 20 * log10(max(rms, 1e-7))              // ~ -140…0 dB
        return CGFloat(max(0, min(1, (db + 55) / 55)))   // map -55…0 dB → 0…1
    }

    private static func floats(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let ch = buffer.floatChannelData, buffer.frameLength > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: ch[0], count: Int(buffer.frameLength)))
    }
}

// MARK: - Waveform extraction

/// Reads an audio file and produces a normalized peak-amplitude envelope for display.
enum WaveformExtractor {
    nonisolated static func envelope(url: URL, buckets: Int = 48) -> [Double] {
        guard let file = try? AVAudioFile(forReading: url) else { return [] }
        let format = file.processingFormat
        let total = Int(file.length)
        guard buckets > 0, total > 0 else { return [] }

        // Read a fixed-size window instead of allocating the full decoded recording. A long AAC
        // journal can expand to hundreds of MB as PCM and previously risked terminating the app.
        let chunkFrames: AVAudioFrameCount = 8_192
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else { return [] }
        let channelCount = Int(format.channelCount)
        var peaks = Array(repeating: 0.0, count: buckets)
        var maxPeak = 0.0
        var processed = 0

        while processed < total {
            let requested = AVAudioFrameCount(min(Int(chunkFrames), total - processed))
            do { try file.read(into: buffer, frameCount: requested) }
            catch { return [] }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0, let channels = buffer.floatChannelData else { break }

            for frame in 0..<frameCount {
                var sample: Float = 0
                for channel in 0..<channelCount {
                    sample = max(sample, abs(channels[channel][frame]))
                }
                let bucket = min(buckets - 1, (processed + frame) * buckets / total)
                let value = Double(sample)
                if value > peaks[bucket] { peaks[bucket] = value }
                if value > maxPeak { maxPeak = value }
            }
            processed += frameCount
        }
        guard maxPeak > 0 else { return [] }
        // Normalize, then apply a gentle curve so quiet detail stays visible.
        return peaks.map { min(1, pow($0 / maxPeak, 0.7)) }
    }

    /// Resample an envelope to exactly `n` bars (nearest-bucket). Empty input → a flat resting shape.
    nonisolated static func resample(_ src: [Double], to n: Int) -> [Double] {
        guard n > 0 else { return [] }
        guard !src.isEmpty else { return Array(repeating: 0.12, count: n) }
        if src.count == n { return src }
        return (0..<n).map { idx in
            let pos = Double(idx) / Double(n) * Double(src.count)
            return src[min(src.count - 1, Int(pos))]
        }
    }
}
