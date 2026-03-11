// Onboarding.swift — Voice Journal
// Premium first-launch experience.

import SwiftUI
import Combine

// MARK: - Page Model

struct OnboardPage {
    let icon: String
    let title: String
    let subtitle: String
    let body: String
    let accent: Color
    let bg: Color
    let bgTop: Color
}

// MARK: - Pages

private let onboardPages: [OnboardPage] = [
    OnboardPage(
        icon: "mic.fill",
        title: "Your voice.",
        subtitle: "Your journal.",
        body: "No typing. No formatting. Press once and speak — your thoughts, exactly as they come.",
        accent: Color(red: 0.95, green: 0.78, blue: 0.46),
        bg:    Color(red: 0.06, green: 0.06, blue: 0.08),
        bgTop: Color(red: 0.12, green: 0.10, blue: 0.06)
    ),
    OnboardPage(
        icon: "waveform",
        title: "Every word,",
        subtitle: "visualised.",
        body: "Watch your voice come alive. Pause mid-thought, resume when ready, or stop when you're done.",
        accent: Color(red: 0.50, green: 0.75, blue: 1.00),
        bg:    Color(red: 0.04, green: 0.05, blue: 0.13),
        bgTop: Color(red: 0.06, green: 0.10, blue: 0.20)
    ),
    OnboardPage(
        icon: "heart.fill",
        title: "Feel it.",
        subtitle: "Tag it.",
        body: "Attach a mood to every entry. Look back and see not just what you said — but how you felt.",
        accent: Color(red: 1.00, green: 0.55, blue: 0.65),
        bg:    Color(red: 0.11, green: 0.05, blue: 0.07),
        bgTop: Color(red: 0.20, green: 0.07, blue: 0.10)
    ),
    OnboardPage(
        icon: "lock.fill",
        title: "Only yours.",
        subtitle: "Always.",
        body: "Everything lives on your device. No cloud. No accounts. No one else reads your journal.",
        accent: Color(red: 0.65, green: 0.60, blue: 1.00),
        bg:    Color(red: 0.07, green: 0.07, blue: 0.12),
        bgTop: Color(red: 0.12, green: 0.10, blue: 0.20)
    )
]

// MARK: - Hero: Mic rings (page 0)

struct HeroMic: View {
    let accent: Color
    let phase: Double
    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                let scale = 1.0 + Double(i) * 0.28 + sin(phase + Double(i) * 0.9) * 0.04
                Circle()
                    .stroke(accent.opacity(0.05 + Double(3 - i) * 0.04), lineWidth: 1)
                    .scaleEffect(scale)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "mic.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(accent)
            }
            ForEach(0..<6) { i in
                let angle = Double(i) * 60.0 * .pi / 180.0
                let r = 64.0 + sin(phase * 1.3 + Double(i)) * 6.0
                Circle()
                    .fill(accent.opacity(0.35 + sin(phase + Double(i) * 1.1) * 0.25))
                    .frame(width: 5, height: 5)
                    .offset(x: cos(angle + phase * 0.4) * r,
                            y: sin(angle + phase * 0.4) * r)
            }
        }
        .frame(width: 240, height: 240)
    }
}

// MARK: - Hero: Live waveform (page 1)

struct HeroWave: View {
    let accent: Color
    let phase: Double
    let barCount = 32
    var body: some View {
        GeometryReader { g in
            let bw: CGFloat = 7
            let sp = (g.size.width - bw * CGFloat(barCount)) / CGFloat(barCount - 1)
            HStack(alignment: .center, spacing: sp) {
                ForEach(0..<barCount, id: \.self) { i in
                    let t = Double(i) / Double(barCount)
                    let h = abs(sin(phase + t * .pi * 4)) * 0.55
                          + abs(sin(phase * 0.7 + t * .pi * 2.5)) * 0.30
                          + abs(sin(phase * 1.3 + t * .pi * 1.2)) * 0.15
                    let dist = abs(t - 0.5)
                    Capsule()
                        .fill(accent.opacity((0.3 + h * 0.7) * (1.0 - dist * 0.8)))
                        .frame(width: bw, height: max(6, h * g.size.height * 0.88))
                }
            }
        }
    }
}

// MARK: - Hero: Mood orbit (page 2)

struct HeroMoods: View {
    let accent: Color
    let phase: Double
    private let moods: [(String, Double)] = [
        ("😌", 0), ("😄", 60), ("🤔", 120),
        ("😤", 180), ("🙏", 240), ("😭", 300)
    ]
    var body: some View {
        ZStack {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "heart.fill")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(accent)
            }
            ForEach(Array(moods.enumerated()), id: \.offset) { idx, m in
                let rad = (m.1 + phase * 18) * .pi / 180
                let r   = 96.0 + sin(phase * 0.8 + Double(idx)) * 8.0
                Text(m.0)
                    .font(.system(size: 26))
                    .scaleEffect(0.85 + sin(phase * 1.1 + Double(idx) * 1.3) * 0.15)
                    .offset(x: cos(rad) * r, y: sin(rad) * r)
                    .opacity(0.6 + sin(phase + Double(idx)) * 0.35)
            }
        }
        .frame(width: 260, height: 260)
    }
}

// MARK: - Hero: Lock + shield (page 3)

struct HeroLock: View {
    let accent: Color
    let phase: Double
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(accent.opacity(0.07 + Double(i) * 0.03),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 10]))
                    .frame(width: CGFloat(90 + i * 40), height: CGFloat(90 + i * 40))
                    .rotationEffect(.degrees(phase * (i % 2 == 0 ? 22 : -16) + Double(i) * 40))
            }
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "lock.fill")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(accent)
            }
            ForEach(0..<8) { i in
                let angle = Double(i) * 45.0 * .pi / 180.0
                let r = 112.0 + sin(phase * 0.9 + Double(i) * 0.7) * 10.0
                Circle()
                    .fill(accent.opacity(0.22 + sin(phase * 1.2 + Double(i)) * 0.18))
                    .frame(width: 4, height: 4)
                    .offset(x: cos(angle + phase * 0.15) * r,
                            y: sin(angle + phase * 0.15) * r)
            }
        }
        .frame(width: 260, height: 260)
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var page:       Int    = 0
    @State private var phase:      Double = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool   = false

    @State private var heroVisible:  Bool = false
    @State private var titleVisible: Bool = false
    @State private var bodyVisible:  Bool = false

    private var p: OnboardPage { onboardPages[page] }
    private let clock = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {

                // Gradient background
                LinearGradient(colors: [p.bgTop, p.bg], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.65), value: page)

                // Dot grid texture
                Canvas { ctx, size in
                    let s: CGFloat = 38
                    for x in stride(from: CGFloat(0), through: size.width, by: s) {
                        for y in stride(from: CGFloat(0), through: size.height, by: s) {
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                                     with: .color(.white.opacity(0.03)))
                        }
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {

                    // Top bar
                    HStack {
                        HStack(spacing: 4) {
                            Text(String(format: "%02d", page + 1))
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(p.accent)
                                .contentTransition(.numericText())
                            Text("/")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.2))
                            Text(String(format: "%02d", onboardPages.count))
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white.opacity(0.25))
                        }
                        Spacer()
                        if page < onboardPages.count - 1 {
                            Button("Skip") { complete() }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, geo.size.height * 0.07)

                    Spacer()

                    // Hero
                    Group {
                        switch page {
                        case 0:
                            HeroMic(accent: p.accent, phase: phase)
                        case 1:
                            HeroWave(accent: p.accent, phase: phase)
                                .frame(width: geo.size.width - 48, height: 160)
                        case 2:
                            HeroMoods(accent: p.accent, phase: phase)
                        default:
                            HeroLock(accent: p.accent, phase: phase)
                        }
                    }
                    .frame(height: geo.size.height * 0.30)
                    .scaleEffect(heroVisible ? 1 : 0.80)
                    .opacity(heroVisible ? 1 : 0)
                    .offset(x: dragOffset * 0.06)

                    Spacer()

                    // Text block
                    VStack(alignment: .leading, spacing: 0) {
                        Text(p.title)
                            .font(.system(size: 44, weight: .ultraLight, design: .serif))
                            .foregroundColor(.white)
                        Text(p.subtitle)
                            .font(.system(size: 44, weight: .light, design: .serif))
                            .foregroundColor(p.accent)
                            .animation(.easeInOut(duration: 0.5), value: page)
                        Rectangle()
                            .fill(p.accent.opacity(0.4))
                            .frame(width: 36, height: 1.5)
                            .padding(.top, 20)
                            .padding(.bottom, 18)
                        Text(p.body)
                            .font(.system(size: 15, weight: .light))
                            .foregroundColor(.white.opacity(0.5))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 20)
                    .offset(x: dragOffset * 0.12)

                    Spacer()

                    // Progress + CTA
                    VStack(spacing: 22) {
                        // Segmented bar
                        HStack(spacing: 6) {
                            ForEach(0..<onboardPages.count, id: \.self) { i in
                                Capsule()
                                    .fill(i <= page ? p.accent : Color.white.opacity(0.1))
                                    .frame(height: 3)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: page)
                            }
                        }
                        .padding(.horizontal, 32)

                        // Button
                        Button { HX.press(); nextOrComplete() } label: {
                            HStack(spacing: 10) {
                                Text(page < onboardPages.count - 1 ? "Continue" : "Begin Journaling")
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: page < onboardPages.count - 1 ? "arrow.right" : "mic.fill")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(p.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(p.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .animation(.easeInOut(duration: 0.35), value: page)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 28)
                        .opacity(bodyVisible ? 1 : 0)
                        .offset(y: bodyVisible ? 0 : 12)
                    }
                    .padding(.bottom, geo.size.height * 0.07)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { v in
                        isDragging = true
                        withAnimation(.interactiveSpring()) { dragOffset = v.translation.width }
                    }
                    .onEnded { v in
                        isDragging = false
                        withAnimation(.spring(response: 0.35)) { dragOffset = 0 }
                        if v.translation.width < -60 && page < onboardPages.count - 1 { advance() }
                        if v.translation.width > 60  && page > 0                      { goBack()  }
                    }
            )
        }
        .preferredColorScheme(.dark)
        .onReceive(clock) { _ in phase += 0.022 }
        .onAppear { animateIn() }
    }

    // MARK: Actions

    func nextOrComplete() {
        if page < onboardPages.count - 1 { advance() } else { complete() }
    }

    func advance() {
        animateOut {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { page += 1 }
            HX.tick()
            animateIn()
        }
    }

    func goBack() {
        animateOut {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { page -= 1 }
            HX.tick()
            animateIn()
        }
    }

    func complete() { HX.ok(); onComplete() }

    func animateIn() {
        heroVisible = false; titleVisible = false; bodyVisible = false
        withAnimation(.spring(response: 0.55, dampingFraction: 0.70).delay(0.05)) { heroVisible  = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.18))                       { titleVisible = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.30))                       { bodyVisible  = true }
    }

    func animateOut(then: @escaping () -> Void) {
        withAnimation(.easeIn(duration: 0.16)) {
            heroVisible = false; titleVisible = false; bodyVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { then() }
    }
}
