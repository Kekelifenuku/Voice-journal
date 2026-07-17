//  Onboarding.swift — Voice Journal
//  A calm, paper-toned first run. Preloads the on-device model while the user reads.

import SwiftUI
import Combine

private struct OnbPage {
    let eyebrow: String
    let title: String
    let accentWord: String
    let body: String
    let hero: AnyView
}

struct OnboardingView: View {
    @ObservedObject var transcription: TranscriptionManager
    let onComplete: () -> Void

    @State private var page = 0
    @State private var phase: Double = 0
    private let clock = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()

    private var modelReady: Bool { transcription.state == .ready }
    private var modelBusy: Bool  { transcription.state.isBusy || transcription.state == .idle }

    private var pages: [OnbPage] {
        [
            OnbPage(eyebrow: "Voice Journal", title: "Speak your", accentWord: "mind.",
                    body: "No typing, no formatting. Press once and talk — your thoughts, exactly as they arrive.",
                    hero: AnyView(MicHero(phase: phase))),
            OnbPage(eyebrow: "On device", title: "Every word,", accentWord: "transcribed.",
                    body: "Your voice becomes searchable text, right on your phone. Nothing is uploaded, ever.",
                    hero: AnyView(WaveHero(phase: phase))),
            OnbPage(eyebrow: "Reflect", title: "See your", accentWord: "patterns.",
                    body: "A quiet summary of each entry, your moods over time, and the themes that keep returning.",
                    hero: AnyView(SummaryHero(phase: phase))),
            OnbPage(eyebrow: "Every day", title: "A prompt,", accentWord: "a nudge.",
                    body: "Each day brings a fresh reflection prompt and a little motivation to begin.",
                    hero: AnyView(PromptHero(phase: phase))),
            OnbPage(eyebrow: "Only yours", title: "Private by", accentWord: "design.",
                    body: "Everything stays on your device. No cloud, no account — no one else can read your journal.",
                    hero: AnyView(LockHero(phase: phase))),
            OnbPage(eyebrow: "Almost there", title: "Getting", accentWord: "ready.",
                    body: modelReady
                        ? "On-device transcription is ready. Your first entry will turn into text the moment you finish."
                        : "We're setting up on-device transcription so your very first entry is ready to go.",
                    hero: AnyView(ModelHero(phase: phase, ready: modelReady, busy: modelBusy)))
        ]
    }

    private var isLast: Bool { page == pages.count - 1 }

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
                        Button("Skip") { HX.tap(); onComplete() }
                            .font(Typo.sans(14, .medium)).foregroundColor(Paper.ink3)
                    }
                }
                .padding(.horizontal, 28).padding(.top, 20)

                Spacer()

                p.hero
                    .frame(height: 240)
                    .id(page)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))

                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    Text(p.eyebrow).eyebrow()
                    VStack(alignment: .leading, spacing: 0) {
                        Text(p.title).font(Typo.sans(38, .bold)).foregroundColor(Paper.ink)
                        Text(p.accentWord).font(Typo.serifItalic(38, .medium)).foregroundColor(Paper.terra)
                    }
                    Text(p.body)
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
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { page += 1 }
                    } else { HX.ok(); onComplete() }
                } label: {
                    HStack(spacing: 8) {
                        Text(isLast ? "Start journaling" : "Continue")
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
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .onReceive(clock) { _ in phase += 0.03 }
        .onAppear {
            // Preload the on-device model now, while the user reads the onboarding.
            if transcription.isSupported { transcription.prepare() }
        }
    }
}

// MARK: - Heroes

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
            Text("\u{201C}I've been trying to slow down\u{2026}\u{201D}")
                .font(Typo.serifItalic(17)).foregroundColor(Paper.ink2)
        }
    }
}

private struct SummaryHero: View {
    let phase: Double
    private let swatches: [Color] = [
        Color(0xD9C4A8), Color(0xC7906B), Color(0xE0D3BE), Color(0xA9694B),
        Color(0xCBA36A), Color(0xE0D3BE), Color(0xB98A66)
    ]
    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                ForEach(Array(swatches.enumerated()), id: \.offset) { i, c in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(c)
                        .frame(width: 26, height: 40 + sin(phase + Double(i) * 0.6) * 5)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold)).foregroundColor(Paper.terra)
                    Text("Summary").eyebrow()
                }
                Text("A calm week, with room to breathe.")
                    .font(Typo.sans(15)).foregroundColor(Paper.ink)
            }
            .padding(16)
            .frame(width: 260, alignment: .leading)
            .paperCard(18, fill: Paper.cardAlt)
        }
    }
}

private struct PromptHero: View {
    let phase: Double
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Paper.cardAlt)
                .frame(width: 250, height: 170)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Paper.hair, lineWidth: 1))
                .rotationEffect(.degrees(sin(phase * 0.6) * 2))
                .shadow(color: Color(0x2B2620, opacity: 0.08), radius: 16, y: 8)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 5) {
                    Image(systemName: "text.quote").font(.system(size: 11, weight: .semibold))
                    Text("Today's prompt").eyebrow()
                }
                Text("Where did you feel most like yourself today?")
                    .font(Typo.serifItalic(20)).foregroundColor(Paper.ink).lineSpacing(4)
            }
            .frame(width: 210, alignment: .leading)
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

            Text(ready ? "Transcription ready" : "Preparing transcription\u{2026}")
                .font(Typo.sans(14, .medium)).foregroundColor(Paper.ink3)
        }
    }
}
