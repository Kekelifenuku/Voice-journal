//  Capture.swift — Voice Journal
//  The recording screen: daily prompt, live transcription, terracotta waveform.

import SwiftUI
import UIKit

struct CaptureView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var store: JournalStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var transcription: TranscriptionManager
    /// First-run hand-off: after the very first entry, show it in the Journal so the loop resolves.
    var goToJournal: () -> Void = {}

    @State private var savedNote = false
    @State private var recordFailedNote = false
    @State private var showMicDenied = false
    @State private var showRecordFailed = false
    /// Cached so the personalized-prompt computation doesn't re-run on every waveform frame.
    @State private var todaysPrompt = ""
    @State private var pulse = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall

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
                        Text(L("Today's prompt")).eyebrow()
                        Text(L(todaysPrompt.isEmpty ? PersonalPrompts.today(entries: store.entries) : todaysPrompt))
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

            // Recording-failed confirmation (empty/corrupt file)
            if recordFailedNote {
                VStack {
                    Spacer()
                    failedBanner.padding(.bottom, 120)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isActive)
        .onAppear {
            engine.onRecordFinish = handleFinish
            engine.onLiveSamples = { [weak transcription] samples in transcription?.feedLive(samples) }
            // Warm up the on-device model so it's ready by the time recording ends.
            if settings.autoTranscribe && transcription.isSupported { transcription.prepare() }
            todaysPrompt = PersonalPrompts.today(entries: store.entries)
            consumePendingRecord()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { consumePendingRecord() }
        }
        // Reset the pulse when recording ends so its animation re-triggers next time (not just once).
        .onChange(of: engine.state) { _, s in
            if s == .idle { pulse = false }
        }
        .onChange(of: engine.micDenied) { _, denied in
            guard denied else { return }
            engine.micDenied = false
            pulse = false
            transcription.stopLive()
            HX.warn()
            showMicDenied = true
        }
        .onChange(of: engine.recordStartFailed) { _, failed in
            guard failed else { return }
            engine.recordStartFailed = false
            pulse = false
            transcription.stopLive()
            HX.error()
            showRecordFailed = true
        }
        .onChange(of: store.entries.count) { _, _ in
            todaysPrompt = PersonalPrompts.today(entries: store.entries)
        }
        .alert(L("Microphone access needed"), isPresented: $showMicDenied) {
            Button(L("Open Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button(L("Not now"), role: .cancel) {}
        } message: {
            Text(L("Turn on microphone access in Settings to record your voice entries."))
        }
        .alert(L("Couldn't start recording"), isPresented: $showRecordFailed) {
            Button(L("OK"), role: .cancel) {}
        } message: {
            Text(L("Your microphone may be in use by another app. Try again in a moment."))
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day().locale(AppLocale.locale)))
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
                    .animation(isRecording && !reduceMotion ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: pulse)
                Text(L(isPaused ? "PAUSED" : "LISTENING"))
                    .font(Typo.sans(11, .semibold)).tracking(1.6)
                    .foregroundColor(Paper.ink3)
                Text("· \(engine.elapsedFormatted())")
                    .font(Typo.sans(12, .medium)).foregroundColor(Paper.ink3)
            }

            // Live text — height-capped and pinned to the newest words. Without the cap a long
            // entry grows this Text until the waveform and record button are pushed off-screen.
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    Text(liveDisplay)
                        .font(Typo.sans(21, .regular))
                        .foregroundColor(liveText.isEmpty ? Paper.placeholder : Paper.ink)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(liveTailID)
                }
                .frame(maxHeight: 170)
                .onChange(of: liveText) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(liveTailID, anchor: .bottom) }
                }
            }

            LiveWaveform(bars: engine.bars, color: Paper.terra)
                .frame(height: 60)
                .opacity(isPaused ? 0.4 : 1)
                .accessibilityHidden(true)
        }
    }

    private let liveTailID = "liveTail"
    private var liveText: String { transcription.liveText }
    private var liveDisplay: String {
        if !liveText.isEmpty { return liveText }
        return isPaused ? String(localized: "Paused — resume when you're ready.", bundle: AppLocale.bundle) : String(localized: "Listening… speak freely.", bundle: AppLocale.bundle)
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
                        Text(L(isPaused ? "Resume" : "Pause")).font(Typo.sans(14, .semibold))
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

            Text(L(isRecording ? "TAP TO FINISH" : isPaused ? "TAP TO FINISH" : "TAP TO BEGIN"))
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
                if isActive && !reduceMotion {
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
        .accessibilityLabel(L(isActive ? "Stop recording" : "Start recording"))
        .accessibilityHint(L(isActive ? "Saves this entry" : "Records a new voice entry"))
    }

    private var savedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(Paper.terra)
            Text(L(transcription.isSupported && settings.autoTranscribe ? "Saved · transcribing…" : "Saved to your journal"))
                .font(Typo.sans(14, .medium)).foregroundColor(Paper.ink)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Paper.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Paper.hair, lineWidth: 1))
        .shadow(color: Color(0x2B2620, opacity: 0.1), radius: 16, y: 6)
    }

    private var failedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Paper.danger)
            Text(L("Recording failed — nothing was saved"))
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
        guard dur >= 0.6 else {                          // ignore accidental taps
            try? FileManager.default.removeItem(at: store.docURL(file))
            return
        }
        // Guard against an empty/corrupt file (interruption, disk full, converter failure): don't
        // create a normal-looking entry that plays nothing and shows a flat resting waveform.
        let url = store.docURL(file)
        let size = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int) ?? 0
        guard size > 1200 else {
            try? FileManager.default.removeItem(at: url)
            HX.error()
            withAnimation { recordFailedNote = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation { recordFailedNote = false }
            }
            return
        }
        let prompt = settings.showPromptOnCapture ? todaysPrompt : ""
        let entry = VoiceEntry(duration: dur, fileName: file, prompt: prompt)
        store.add(entry)
        store.ensureWaveform(for: entry)
        if settings.autoTranscribe { transcription.transcribe(entry, store: store) }
        HX.ok()
        withAnimation { savedNote = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { savedNote = false }
        }
        // First-run hand-off: on the very first entry, reveal it in the Journal so the loop resolves
        // (answers "where did it go?" and shows the live transcription). Only once — later saves stay put.
        if store.entries.count == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation { savedNote = false }
                goToJournal()
            }
        }
        // Ask for a review only after a genuine value moment (a saved entry). RatingManager still
        // guards on launch count + once-only; this screen is only reachable past the gate.
        RatingManager.shared.requestReviewIfNeeded()
        // Highest-intent paywall moment: after their 3rd entry they clearly value the app.
        // Delay slightly so the "Saved" banner registers first.
        if !isPro && store.entries.count == 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                presentPaywall()
            }
        }
    }
}
