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

    private var recorder:   AVAudioRecorder?
    private var player:     AVAudioPlayer?
    private var recClock:   Timer?
    private var meterTimer: Timer?
    private var playTimer:  Timer?
    private var recStart:   Date?
    private var pausedAt:   TimeInterval = 0
    private var pendingFile: String?

    /// (fileName, duration) once a recording finishes.
    var onRecordFinish: ((String, TimeInterval) -> Void)?
    /// Streamed mic buffers for live transcription (optional consumer).
    var onLevel: ((CGFloat) -> Void)?

    // MARK: Recording

    func requestAndRecord() {
        AVAudioApplication.requestRecordPermission { [weak self] ok in
            Task { @MainActor in if ok { self?.startRecording() } }
        }
    }

    private func startRecording() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? s.setActive(true)
        let name = "vj_\(UUID().uuidString).m4a"; pendingFile = name
        let cfg: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        recorder = try? AVAudioRecorder(url: Self.docURL(name), settings: cfg)
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true
        recorder?.record()
        recStart = Date(); elapsed = 0; state = .recording
        startTimers()
    }

    private func startTimers() {
        recClock = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let t = self.recStart else { return }
                self.elapsed = self.pausedAt + Date().timeIntervalSince(t)
            }
        }
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleMeter() }
        }
    }

    func pauseRecording() {
        recorder?.pause()
        pausedAt += Date().timeIntervalSince(recStart ?? Date())
        recClock?.invalidate(); meterTimer?.invalidate()
        state = .paused
    }

    func resumeRecording() {
        recorder?.record(); recStart = Date(); state = .recording
        startTimers()
    }

    func stopRecording() {
        recorder?.stop(); recClock?.invalidate(); meterTimer?.invalidate()
        let dur = elapsed
        state = .idle; elapsed = 0; pausedAt = 0; level = 0
        bars = Array(repeating: 0.04, count: bars.count)
        if let f = pendingFile { onRecordFinish?(f, dur) }
    }

    private func sampleMeter() {
        recorder?.updateMeters()
        let p = recorder?.averagePower(forChannel: 0) ?? -80
        let n = CGFloat(max(0, (p + 70) / 70))
        level = n
        onLevel?(n)
        bars.removeFirst(); bars.append(max(0.04, n * 0.96))
    }

    // MARK: Playback

    func play(entry: VoiceEntry, speed: Float? = nil) {
        player?.stop(); playTimer?.invalidate()
        let url = Self.docURL(entry.fileName)
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback); try? s.setActive(true)
        let spd = speed ?? playSpeed
        player = p; player?.delegate = self; player?.enableRate = true; player?.rate = spd
        player?.play()
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
        p.currentTime = p.duration * fraction
        playTime = p.currentTime; playProgress = fraction
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
        state = .idle; playingID = nil; playProgress = 0; playTime = 0
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stopPlaying() }
    }

    // MARK: Helpers
    static func docURL(_ n: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(n)
    }
    func fmt(_ t: TimeInterval) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }
    func elapsedFormatted() -> String { fmt(elapsed) }
}

// MARK: - Waveform extraction

/// Reads an audio file and produces a normalized peak-amplitude envelope for display.
enum WaveformExtractor {
    static func envelope(url: URL, buckets: Int = 48) -> [Double] {
        guard let file = try? AVAudioFile(forReading: url) else { return [] }
        let format = file.processingFormat
        let total = Int(file.length)
        guard total > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)),
              (try? file.read(into: buffer)) != nil,
              let channels = buffer.floatChannelData
        else { return [] }

        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return [] }
        let channelCount = Int(format.channelCount)
        let per = max(1, frames / buckets)

        var peaks: [Double] = []
        peaks.reserveCapacity(buckets)
        var maxPeak = 0.0
        var i = 0
        while i < frames {
            let end = min(i + per, frames)
            var peak: Float = 0
            var j = i
            while j < end {
                var s: Float = 0
                for c in 0..<channelCount { s = max(s, abs(channels[c][j])) }
                if s > peak { peak = s }
                j += 1
            }
            let v = Double(peak)
            peaks.append(v)
            if v > maxPeak { maxPeak = v }
            i = end
        }
        guard maxPeak > 0 else { return [] }
        // Normalize, then apply a gentle curve so quiet detail stays visible.
        return peaks.map { min(1, pow($0 / maxPeak, 0.7)) }
    }

    /// Resample an envelope to exactly `n` bars (nearest-bucket). Empty input → a flat resting shape.
    static func resample(_ src: [Double], to n: Int) -> [Double] {
        guard n > 0 else { return [] }
        guard !src.isEmpty else { return Array(repeating: 0.12, count: n) }
        if src.count == n { return src }
        return (0..<n).map { idx in
            let pos = Double(idx) / Double(n) * Double(src.count)
            return src[min(src.count - 1, Int(pos))]
        }
    }
}
