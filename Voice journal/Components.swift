//  Components.swift — Voice Journal
//  Reusable visual pieces: waveforms, mood tags, week strip, audio pill.

import SwiftUI

// MARK: - Live capture waveform (centered, terracotta)

struct LiveWaveform: View {
    let bars: [CGFloat]
    var color: Color = Paper.terra
    var body: some View {
        GeometryReader { g in
            let count = bars.count
            let bw = max(2.5, (g.size.width / CGFloat(count)) * 0.46)
            let sp = count > 1 ? (g.size.width - bw * CGFloat(count)) / CGFloat(count - 1) : 0
            HStack(alignment: .center, spacing: sp) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, h in
                    Capsule()
                        .fill(color.opacity(0.35 + Double(h) * 0.55))
                        .frame(width: bw, height: max(3, h * g.size.height))
                        .animation(.easeOut(duration: 0.08), value: h)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Static mini waveform (entry cards) — real amplitude envelope

struct MiniWaveform: View {
    let bars: [Double]           // normalized envelope (0…1) of the recording
    var count: Int = 26
    var color: Color = Paper.tan
    var progress: Double = 0     // 0…1 fills bars terracotta up to here

    var body: some View {
        GeometryReader { g in
            let display = WaveformExtractor.resample(bars, to: count)
            let bw = max(1.5, (g.size.width / CGFloat(count)) * 0.5)
            let sp = count > 1 ? (g.size.width - bw * CGFloat(count)) / CGFloat(count - 1) : 0
            HStack(alignment: .center, spacing: sp) {
                ForEach(Array(display.enumerated()), id: \.offset) { i, h in
                    let played = Double(i) / Double(count) <= progress
                    Capsule()
                        .fill((played ? Paper.terra : color).opacity(0.4 + h * 0.5))
                        .frame(width: bw, height: max(2, CGFloat(h) * g.size.height))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Undo toast (shown after a soft-delete, root level)

struct UndoToast: View {
    let title: String
    let onUndo: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Paper.ink3)
            Text(L(title))
                .font(Typo.sans(14, .medium))
                .foregroundColor(Paper.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button(action: onUndo) {
                Text(L("Undo"))
                    .font(Typo.sans(14, .semibold))
                    .foregroundColor(Paper.terra)
                    .padding(.horizontal, 6).padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .accessibilityHint(L("Restores the deleted entry"))
        }
        .padding(.leading, 18).padding(.trailing, 12).padding(.vertical, 11)
        .background(Paper.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Paper.hair, lineWidth: 1))
        .shadow(color: Color(0x2B2620, opacity: 0.14), radius: 18, y: 8)
    }
}

// MARK: - Primary capsule action (empty-state CTAs, standardized)

struct PrimaryCapsuleButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button { HX.press(); action() } label: {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 14, weight: .bold))
                }
                Text(L(title)).font(Typo.sans(15, .semibold))
            }
            .foregroundColor(Paper.white)
            .padding(.horizontal, 22).padding(.vertical, 13)
            .background(Paper.terra)
            .clipShape(Capsule())
            .shadow(color: Paper.terra.opacity(0.3), radius: 12, y: 5)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Mood tag (filled soft chip)

struct MoodTag: View {
    let mood: Mood
    var body: some View {
        Text(mood.label)
            .font(Typo.sans(12, .medium))
            .foregroundColor(Paper.ink2)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(mood.color.opacity(0.22))
            .clipShape(Capsule())
    }
}

// MARK: - Theme chip (outline, for summary)

struct ThemeChip: View {
    let text: String
    var leadingGlyph: String? = nil
    var body: some View {
        HStack(spacing: 5) {
            if let g = leadingGlyph {
                Image(systemName: g).font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Paper.terra)
            }
            Text(text).font(Typo.sans(12, .medium)).foregroundColor(Paper.ink2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Paper.white.opacity(0.7))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Paper.hair, lineWidth: 1))
    }
}

// MARK: - Weekly mood strip

struct WeekMoodStrip: View {
    let moods: [Mood?]     // 7 entries, oldest → newest (index 6 = today)

    /// Weekday name for a strip index, derived from today going back 6 days.
    private func dayName(_ indexFromOldest: Int) -> String {
        let back = 6 - indexFromOldest
        let day = Calendar.current.date(byAdding: .day, value: -back, to: Date()) ?? Date()
        return day.formatted(.dateTime.weekday(.wide).locale(AppLocale.locale))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("This week's mood")).eyebrow(Paper.ink3)
            HStack(spacing: 10) {
                ForEach(Array(moods.enumerated()), id: \.offset) { i, m in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(m?.color ?? Paper.cardAlt)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Paper.hair, lineWidth: m == nil ? 1 : 0)
                        )
                        .accessibilityElement()
                        .accessibilityLabel("\(dayName(i)): \(m?.label ?? String(localized: "no entry", bundle: AppLocale.bundle))")
                }
            }
            .accessibilityElement(children: .contain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(22, fill: Paper.white)
    }
}

// MARK: - Flow layout (wrapping words)

struct FlowLayout: Layout {
    var spacing: CGFloat = 5
    var lineSpacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxWidth && x > 0 { x = 0; y += lineHeight + lineSpacing; lineHeight = 0 }
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
        let w = maxWidth == .infinity ? x - spacing : maxWidth
        return CGSize(width: max(0, w), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += lineHeight + lineSpacing; lineHeight = 0 }
            sv.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
    }
}

// MARK: - Interactive (tap-to-seek) transcript

struct InteractiveTranscript: View {
    let entry: VoiceEntry
    @ObservedObject var engine: AudioEngine

    private var isThis: Bool { engine.playingID == entry.id }
    private var activeIndex: Int? {
        guard isThis, engine.state == .playing else { return nil }
        let t = engine.playTime
        return entry.words.firstIndex { t >= $0.start && t < $0.end }
    }

    var body: some View {
        FlowLayout(spacing: 4, lineSpacing: 7) {
            ForEach(Array(entry.words.enumerated()), id: \.offset) { i, w in
                let active = i == activeIndex
                Text(w.text.trimmingCharacters(in: .whitespaces))
                    .font(Typo.sans(16))
                    .foregroundColor(active ? Paper.white : Paper.ink2)
                    .padding(.horizontal, 3).padding(.vertical, 1)
                    .background(active ? Paper.terra : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
                    .onTapGesture { seek(to: w) }
            }
        }
        .animation(.easeOut(duration: 0.15), value: activeIndex)
        // Read the transcript as one element instead of forcing a swipe per word.
        // (Sighted users keep per-word tap-to-seek.)
        .accessibilityElement(children: .combine)
    }

    private func seek(to w: WordStamp) {
        HX.tap()
        let dur = max(entry.duration, entry.words.last?.end ?? entry.duration)
        if !isThis || engine.state != .playing { engine.play(entry: entry) }
        engine.seek(to: min(0.999, w.start / max(0.01, dur)))
    }
}

// MARK: - Dark audio pill (Reflect)

struct AudioPill: View {
    @ObservedObject var engine: AudioEngine
    let entry: VoiceEntry
    var isPlaying: Bool { engine.playingID == entry.id && engine.state == .playing }
    var progress: Double { engine.playingID == entry.id ? engine.playProgress : 0 }
    var timeLabel: String {
        engine.playingID == entry.id ? engine.fmt(engine.playTime) : "0:00"
    }

    var body: some View {
        HStack(spacing: 16) {
            Button {
                HX.press()
                engine.togglePlay(entry: entry)
            } label: {
                ZStack {
                    Circle().fill(Paper.terra).frame(width: 52, height: 52)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(Paper.white)
                        .contentTransition(.symbolEffect(.replace))
                        .offset(x: isPlaying ? 0 : 1.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L(isPlaying ? "Pause" : "Play recording"))

            VStack(alignment: .leading, spacing: 8) {
                MiniWaveform(bars: entry.waveform, count: 34,
                             color: Paper.onDark2, progress: progress)
                    .frame(height: 26)
                    .accessibilityHidden(true)
                Text(timeLabel)
                    .font(Typo.sans(11, .medium))
                    .foregroundColor(Paper.onDark2)
                    .accessibilityLabel(String(localized: "Elapsed \(timeLabel)", bundle: AppLocale.bundle))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Paper.espresso)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
