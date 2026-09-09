//  Onboarding.swift — Voice Journal
//  A calm, paper-toned first run. Preloads the on-device model while the user reads.

import SwiftUI
import Combine
import AVFoundation

private struct OnbPage {
    let eyebrow: String
    let title: String
    let accentWord: String
    let body: String
}

struct OnboardingView: View {
    @ObservedObject var transcription: TranscriptionManager
    let onComplete: () -> Void

    @State private var page = 0
    @State private var phase: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let clock = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()

    private var modelReady: Bool { transcription.state == .ready }
    private var modelBusy: Bool  { transcription.state.isBusy || transcription.state == .idle }

    // Text-only metadata. Heroes are built one-at-a-time in `hero(for:)` so we don't allocate
    // all six (each formerly an AnyView) on every 30fps animation tick.
    private var pages: [OnbPage] {
        [
            OnbPage(eyebrow: "Voice Journal", title: "Speak your", accentWord: "mind.",
                    body: "No typing, no formatting. Press once and talk — your thoughts, exactly as they arrive."),
            OnbPage(eyebrow: "On device", title: "Every word,", accentWord: "transcribed.",
                    body: "Your voice becomes searchable text, right on your phone. Nothing is uploaded, ever."),
            OnbPage(eyebrow: "How it felt", title: "Name the", accentWord: "feeling.",
                    body: "Tag each moment — calm, joyful, tense — with a single tap, and let the mood color your journal."),
            OnbPage(eyebrow: "Insights", title: "Watch it", accentWord: "unfold.",
                    body: "Your emotional weather, your moods over time, and the rhythm of your days — patterns you can actually feel."),
            OnbPage(eyebrow: "Only yours", title: "Private by", accentWord: "design.",
                    body: "Everything stays on your device. No cloud, no account — no one else can read your journal."),
            OnbPage(eyebrow: "Almost there", title: "Getting", accentWord: "ready.",
                    body: modelReady
                        ? "On-device transcription is ready. Your first entry will turn into text the moment you finish."
                        : "We're setting up on-device transcription so your very first entry is ready to go.")
        ]
    }

    @ViewBuilder
    private func hero(for index: Int) -> some View {
        switch index {
        case 0: MicHero(phase: phase)
        case 1: WaveHero(phase: phase)
        case 2: MoodHero(phase: phase)
        case 3: InsightsHero(phase: phase)
        case 4: LockHero(phase: phase)
        default: ModelHero(phase: phase, ready: modelReady, busy: modelBusy)
        }
    }

    private var isLast: Bool { page == pages.count - 1 }

    /// Index of the privacy page — where we prime the mic permission so the OS prompt lands with context.
    private var privacyPageIndex: Int { pages.firstIndex { $0.eyebrow == "Only yours" } ?? -1 }

    /// Ask for microphone access once, in context, right after the privacy page. The result doesn't
    /// gate onboarding — recording itself handles denial (AudioEngine.micDenied → Capture alert).
    private func primeMicIfNeeded() {
        guard AVAudioApplication.shared.recordPermission == .undetermined else { return }
        AVAudioApplication.requestRecordPermission { _ in }
    }

    var body: some View {
        let p = pages[page]
        ZStack {
            Paper.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress
                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i <= page ? Paper.terra : Paper.muted.opacity(0.4))
                            .frame(width: i == page ? 20 : 6, height: 6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)
                    }
                    Spacer()
                    if !isLast {
                        Button(L("Skip")) { HX.tap(); onComplete() }
                            .font(Typo.sans(14, .medium)).foregroundColor(Paper.ink3)
                    }
                }
                .padding(.horizontal, 28).padding(.top, 20)

                Spacer()

                hero(for: page)
                    .frame(height: 240)
                    .id(page)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))

                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    Text(L(p.eyebrow)).eyebrow()
                    VStack(alignment: .leading, spacing: 0) {
                        Text(L(p.title)).font(Typo.sans(38, .bold)).foregroundColor(Paper.ink)
                        Text(L(p.accentWord)).font(Typo.serifItalic(38, .medium)).foregroundColor(Paper.terra)
                    }
                    Text(L(p.body))
                        .font(Typo.sans(16))
                        .foregroundColor(Paper.ink2)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(.easeInOut(duration: 0.25), value: p.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .id("txt\(page)")
                .transition(.opacity.combined(with: .offset(y: 12)))

                Spacer().frame(height: 24)

                Button {
                    HX.press()
                    if !isLast {
                        if page == privacyPageIndex { primeMicIfNeeded() }
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { page += 1 }
                    } else { HX.ok(); onComplete() }
                } label: {
                    HStack(spacing: 8) {
                        Text(L(isLast ? "Start journaling" : "Continue"))
                            .font(Typo.sans(16, .semibold))
                        Image(systemName: isLast ? "mic.fill" : "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(Paper.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Paper.terra)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Paper.terra.opacity(0.3), radius: 14, y: 6)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .onReceive(clock) { _ in if !reduceMotion { phase += 0.03 } }
        .onAppear {
            // Preload the on-device model now, while the user reads the onboarding.
            if transcription.isSupported { transcription.prepare() }
        }
    }
}

// MARK: - Heroes

/// Mood chips (matching the picker) gently bobbing — the "name the feeling" illustration.
private struct MoodHero: View {
    let phase: Double
    private let moods: [Mood] = [.serene, .joyful, .pensive, .tense]
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) { chip(moods[0], 0); chip(moods[1], 1) }
            HStack(spacing: 16) { chip(moods[2], 2); chip(moods[3], 3) }
        }
    }
    private func chip(_ m: Mood, _ i: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: m.glyph).font(.system(size: 15, weight: .semibold))
            Text(m.label).font(Typo.sans(15, .semibold))
        }
        .foregroundColor(Paper.ink)
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(m.color.opacity(0.22))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(m.color.opacity(0.4), lineWidth: 1))
        .shadow(color: m.color.opacity(0.18), radius: 8, y: 4)
        .offset(y: sin(phase * 1.1 + Double(i) * 0.9) * 5)
    }
}

/// An animated emotional-trend line + mood dots — the "insights" illustration.
private struct InsightsHero: View {
    let phase: Double
    private let dotColors: [Color] = [
        Mood.serene.color, Mood.joyful.color, Mood.pensive.color,
        Mood.tense.color, Mood.grateful.color, Mood.serene.color, Mood.joyful.color
    ]
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Paper.cardAlt)
                    .frame(width: 264, height: 150)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Paper.hair, lineWidth: 1))
                    .shadow(color: Color(0x2B2620, opacity: 0.08), radius: 16, y: 8)
                trendChart.frame(width: 216, height: 92)
            }
            HStack(spacing: 7) {
                ForEach(Array(dotColors.enumerated()), id: \.offset) { i, c in
                    Circle().fill(c).frame(width: 12, height: 12)
                        .scaleEffect(0.85 + (sin(phase + Double(i) * 0.7) * 0.5 + 0.5) * 0.3)
                }
            }
        }
    }
    private var trendChart: some View {
        GeometryReader { g in
            let n = 7
            let w = g.size.width, h = g.size.height
            let xs = (0..<n).map { CGFloat($0) / CGFloat(n - 1) * w }
            let ys = (0..<n).map { i -> CGFloat in
                let t = Double(i) / Double(n - 1)
                let v = sin(phase * 0.8 + t * .pi * 1.6) * 0.5 + 0.5    // 0…1
                return h * 0.1 + (1 - CGFloat(v)) * h * 0.8
            }
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: xs[0], y: h))
                    for i in 0..<n { p.addLine(to: CGPoint(x: xs[i], y: ys[i])) }
                    p.addLine(to: CGPoint(x: xs[n - 1], y: h)); p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Paper.terra.opacity(0.28), Paper.terra.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))
                Path { p in
                    p.move(to: CGPoint(x: xs[0], y: ys[0]))
                    for i in 1..<n { p.addLine(to: CGPoint(x: xs[i], y: ys[i])) }
                }
                .stroke(Paper.terra, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                Circle().fill(Paper.terra).frame(width: 8, height: 8)
                    .position(x: xs[n - 1], y: ys[n - 1])
            }
        }
    }
}

private struct MicHero: View {
    let phase: Double
    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                let s = 1.0 + Double(i) * 0.3 + sin(phase + Double(i) * 0.8) * 0.04
                Circle().stroke(Paper.terra.opacity(0.14 - Double(i) * 0.03), lineWidth: 1.2)
                    .frame(width: 90, height: 90).scaleEffect(s)
            }
            Circle().fill(Paper.terra).frame(width: 88, height: 88)
                .shadow(color: Paper.terra.opacity(0.3), radius: 18, y: 8)
            Image(systemName: "mic.fill").font(.system(size: 34, weight: .medium)).foregroundColor(Paper.white)
        }
    }
}

private struct WaveHero: View {
    let phase: Double
    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 5) {
                ForEach(0..<18, id: \.self) { i in
                    let t = Double(i) / 18
                    let h = abs(sin(phase * 1.4 + t * .pi * 3)) * 0.7 + 0.25
                    Capsule().fill(Paper.terra.opacity(0.4 + h * 0.5))
                        .frame(width: 6, height: 22 + h * 60)
                }
            }
            Image(systemName: "arrow.down").font(.system(size: 12, weight: .bold)).foregroundColor(Paper.ink3)
            Text(L("\u{201C}I've been trying to slow down\u{2026}\u{201D}"))
                .font(Typo.serifItalic(17)).foregroundColor(Paper.ink2)
        }
    }
}

private struct LockHero: View {
    let phase: Double
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Paper.terra.opacity(0.12 - Double(i) * 0.03),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 9]))
                    .frame(width: CGFloat(96 + i * 42), height: CGFloat(96 + i * 42))
                    .rotationEffect(.degrees(phase * (i % 2 == 0 ? 14 : -10)))
            }
            Circle().fill(Paper.terra.opacity(0.12)).frame(width: 92, height: 92)
            Image(systemName: "lock.fill").font(.system(size: 34, weight: .medium)).foregroundColor(Paper.terra)
        }
    }
}

private struct ModelHero: View {
    let phase: Double
    let ready: Bool
    let busy: Bool
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Paper.cardAlt).frame(width: 110, height: 110)
                    .overlay(Circle().stroke(Paper.hair, lineWidth: 1))
                if ready {
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold)).foregroundColor(Paper.terra)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Paper.terra, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(phase * 140))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: ready)

            Text(L(ready ? "Transcription ready" : "Preparing transcription\u{2026}"))
                .font(Typo.sans(14, .medium)).foregroundColor(Paper.ink3)
        }
    }
}
