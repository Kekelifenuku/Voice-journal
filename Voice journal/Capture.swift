//  Capture.swift — Voice Journal
//  The recording screen: daily prompt, live transcription, terracotta waveform.

import SwiftUI

struct CaptureView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var store: JournalStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var transcription: TranscriptionManager

    @State private var savedNote = false
    @State private var pulse = false
    @Environment(\.scenePhase) private var scenePhase

    private var isRecording: Bool { engine.state == .recording }
    private var isPaused: Bool { engine.state == .paused }
    private var isActive: Bool { isRecording || isPaused }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                // Prompt
                if settings.showPromptOnCapture {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's prompt").eyebrow()
                        Text(Prompts.today())
                            .font(Typo.serifItalic(26))
                            .foregroundColor(Paper.ink)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(isActive ? 0.45 : 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 26)
                    .animation(.easeInOut(duration: 0.4), value: isActive)
                }

                Spacer(minLength: 20)

                // Live transcription / listening area
                if isActive {
                    listeningArea
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 20)

                controls
                    .padding(.bottom, 20)
            }

            // Saved confirmation
            if savedNote {
                VStack {
                    Spacer()
                    savedBanner.padding(.bottom, 120)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isActive)
        .onAppear {
            engine.onRecordFinish = handleFinish
            // Warm up the on-device model so it's ready by the time recording ends.
            if settings.autoTranscribe && transcription.isSupported { transcription.prepare() }
            consumePendingRecord()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { consumePendingRecord() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(Typo.sans(15, .medium))
                    .foregroundColor(Paper.ink2)
            }
            Spacer()
        }
    }

    // MARK: Listening area

    private var listeningArea: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isRecording ? Paper.terra : Paper.muted)
                    .frame(width: 8, height: 8)
                    .opacity(isRecording ? (pulse ? 0.4 : 1) : 1)
                    .animation(isRecording ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: pulse)
                Text(isPaused ? "PAUSED" : "LISTENING")
                    .font(Typo.sans(11, .semibold)).tracking(1.6)
                    .foregroundColor(Paper.ink3)
                Text("· \(engine.elapsedFormatted())")
                    .font(Typo.sans(12, .medium)).foregroundColor(Paper.ink3)
            }

            // Live text — grows as WhisperKit streams; falls back to a gentle hint.
            Text(liveDisplay)
                .font(Typo.sans(21, .regular))
                .foregroundColor(liveText.isEmpty ? Paper.muted : Paper.ink)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeOut(duration: 0.2), value: liveText)

            LiveWaveform(bars: engine.bars, color: Paper.terra)
                .frame(height: 60)
                .opacity(isPaused ? 0.4 : 1)
                .accessibilityHidden(true)
        }
    }

    private var liveText: String { transcription.liveText }
    private var liveDisplay: String {
        if !liveText.isEmpty { return liveText }
        return isPaused ? "Paused — resume when you're ready." : "Listening… speak freely."
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 18) {
            if isActive {
                Button {
                    HX.press()
                    isRecording ? engine.pauseRecording() : engine.resumeRecording()
                    if !isRecording { pulse = true }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(isPaused ? "Resume" : "Pause").font(Typo.sans(14, .semibold))
                    }
                    .foregroundColor(Paper.terra)
                    .padding(.horizontal, 24).padding(.vertical, 11)
                    .background(Paper.terra.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            recordButton

            Text(isRecording ? "TAP TO FINISH" : isPaused ? "TAP TO FINISH" : "TAP TO BEGIN")
                .font(Typo.sans(11, .semibold)).tracking(2)
                .foregroundColor(Paper.ink3)
        }
    }

    private var recordButton: some View {
        Button {
            if isActive {
                HX.ok(); engine.stopRecording()
            } else {
                HX.heavy(); pulse = true
                transcription.startLive()
                engine.requestAndRecord()
            }
        } label: {
            ZStack {
                if isActive {
                    Circle().stroke(Paper.terra.opacity(0.25), lineWidth: 2)
                        .frame(width: 104, height: 104)
                        .scaleEffect(pulse ? 1.12 : 0.95)
                        .opacity(pulse ? 0 : 0.8)
                        .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: pulse)
                }
                Circle()
                    .fill(isActive ? Paper.terra : Paper.terra)
                    .frame(width: 84, height: 84)
                    .shadow(color: Paper.terra.opacity(0.35), radius: 16, x: 0, y: 8)
                if isActive {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Paper.white).frame(width: 28, height: 28)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(Paper.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Stop recording" : "Start recording")
        .accessibilityHint(isActive ? "Saves this entry" : "Records a new voice entry")
    }

    private var savedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(Paper.terra)
            Text(transcription.isSupported && settings.autoTranscribe ? "Saved · transcribing…" : "Saved to your journal")
                .font(Typo.sans(14, .medium)).foregroundColor(Paper.ink)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Paper.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Paper.hair, lineWidth: 1))
        .shadow(color: Color(0x2B2620, opacity: 0.1), radius: 16, y: 6)
    }

    // MARK: Save flow

    /// Start recording automatically when launched via the "New Entry" Siri/Shortcut intent.
    private func consumePendingRecord() {
        guard UserDefaults.standard.bool(forKey: "vj_pending_record"),
              UserDefaults.standard.bool(forKey: "vj_onboarded"),
              engine.state == .idle else { return }
        UserDefaults.standard.set(false, forKey: "vj_pending_record")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard engine.state == .idle else { return }
            HX.heavy(); pulse = true
            transcription.startLive()
            engine.requestAndRecord()
        }
    }

    private func handleFinish(file: String, dur: TimeInterval) {
        transcription.stopLive()
        guard dur >= 0.6 else { return }          // ignore accidental taps
        let entry = VoiceEntry(duration: dur, fileName: file, prompt: settings.showPromptOnCapture ? Prompts.today() : "")
        store.add(entry)
        store.ensureWaveform(for: entry)
        if settings.autoTranscribe { transcription.transcribe(entry, store: store) }
        HX.ok()
        withAnimation { savedNote = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { savedNote = false }
        }
    }
}
