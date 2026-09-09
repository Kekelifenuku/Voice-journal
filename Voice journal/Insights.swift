//  Insights.swift — Voice Journal
//  Trends, mood distribution, themes, and "on this day".

import SwiftUI
import Charts

struct InsightsView: View {
    @ObservedObject var store: JournalStore
    // Not observed: Insights never reads engine state, it only forwards it to ReflectView (which
    // observes it). Observing here re-ran every analytics computation 25×/sec during playback.
    let engine: AudioEngine
    @ObservedObject var settings: AppSettings
    @ObservedObject var transcription: TranscriptionManager
    @ObservedObject var purchases: PurchaseManager
    @Environment(\.presentPaywall) private var presentPaywall
    var goToCapture: () -> Void = {}

    private var cal: Calendar { Calendar.current }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header

                    if store.entries.isEmpty {
                        emptyState
                    } else {
                        statRow
                        activityCard
                        if !moodCounts.isEmpty { moodCard }
                        if !topThemes.isEmpty { themesCard }
                        if !onThisDay.isEmpty { onThisDayCard }
                        advancedSection
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(for: VoiceEntry.self) { entry in
            ReflectView(entryID: entry.id, store: store, engine: engine,
                        settings: settings, transcription: transcription)
        }
    }

    // MARK: Header + stats

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("Reflect")).eyebrow()
            Text(L("Insights")).font(Typo.sans(32, .bold)).foregroundColor(Paper.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private var statRow: some View {
        StatRow(stats: [
            ("\(store.entries.count)", "entries"),
            (store.totalFormatted, "recorded"),
            (store.streak == 0 ? "—" : "\(store.streak)", "day streak")
        ])
    }

    // MARK: Activity chart

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Last 14 days")).eyebrow(Paper.ink3)
            Chart(last14) { p in
                BarMark(
                    x: .value("Day", p.date, unit: .day),
                    y: .value("Entries", p.count),
                    width: .fixed(10)
                )
                .foregroundStyle(Paper.terra.opacity(p.count == 0 ? 0.15 : 0.85))
                .cornerRadius(3)
                .accessibilityLabel(p.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().locale(AppLocale.locale)))
                .accessibilityValue(String(localized: "\(p.count) entries", bundle: AppLocale.bundle))
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel().foregroundStyle(Paper.ink3)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { value in
                    AxisValueLabel(format: .dateTime.day(), centered: true).foregroundStyle(Paper.ink3)
                }
            }
            .frame(height: 130)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(22)
    }

    // MARK: Mood distribution

    private var moodCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("How you've felt")).eyebrow(Paper.ink3)
            let maxCount = max(1, moodCounts.map(\.count).max() ?? 1)
            VStack(spacing: 10) {
                ForEach(moodCounts, id: \.mood) { mc in
                    HStack(spacing: 10) {
                        Text(mc.mood.label)
                            .font(Typo.sans(13, .medium)).foregroundColor(Paper.ink2)
                            .frame(width: 70, alignment: .leading)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Paper.cardAlt).frame(height: 14)
                                Capsule().fill(mc.mood.color)
                                    .frame(width: max(14, g.size.width * CGFloat(mc.count) / CGFloat(maxCount)), height: 14)
                            }
                        }
                        .frame(height: 14)
                        Text("\(mc.count)").font(Typo.sans(13, .semibold)).foregroundColor(Paper.ink3)
                            .frame(width: 24, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(mc.mood.label): \(mc.count == 1 ? String(localized: "1 entry", bundle: AppLocale.bundle) : String(localized: "\(mc.count) entries", bundle: AppLocale.bundle))")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(22)
    }

    // MARK: Themes

    private var themesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Recurring themes")).eyebrow(Paper.ink3)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(topThemes, id: \.0) { theme, count in
                    HStack(spacing: 6) {
                        Text(theme).font(Typo.sans(13, .medium)).foregroundColor(Paper.ink2)
                        Text("\(count)").font(Typo.sans(11, .semibold)).foregroundColor(Paper.terra)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Paper.cardAlt)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Paper.hair, lineWidth: 1))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(22)
    }

    // MARK: On this day

    private var onThisDayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 12, weight: .semibold)).foregroundColor(Paper.terra)
                Text(L("On this day")).eyebrow()
            }
            ForEach(onThisDay.prefix(4)) { entry in
                NavigationLink(value: entry) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.date.formatted(.dateTime.year().locale(AppLocale.locale)))
                                .font(Typo.sans(12, .semibold)).foregroundColor(Paper.terra)
                            Text(entry.preview)
                                .font(Typo.serifItalic(15)).foregroundColor(Paper.ink2)
                                .lineLimit(2).multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Paper.muted)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(20, fill: Paper.cardAlt)
    }

    // MARK: Advanced (Pro)

    @ViewBuilder
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(L("Advanced")).eyebrow()
                if !purchases.isPro { ProBadge() }
                Spacer()
            }
            .padding(.top, 4)

            if purchases.isPro {
                let digest = Trends.monthlyDigest(store.entries)
                if !digest.isEmpty { digestCard(digest) }
                let series = sentimentSeries   // compute the 30-day series once, reuse below
                if !series.contains(where: { $0.sentiment != nil }) {
                    proHint("Sentiment appears once your entries are transcribed.")
                } else {
                    sentimentCard(series)
                }
                if let dominant = Trends.dominantMood(store.entries, days: 30) { emotionalWeatherCard(dominant) }
                let balance = Trends.emotionalBalance(store.entries)
                if balance.total >= 3 { balanceCard(balance) }
                if let shift = Trends.topMoodTransition(store.entries) { moodShiftsCard(shift) }
                if store.entries.count >= 3 { daypartCard }
                bestTimeCard
                if store.entries.count >= 3 { rhythmCard }
                consistencyCard
                let words = Trends.totalWordsSpoken(store.entries)
                if words > 0 { milestonesCard(words) }
                if avgWordCount > 0 { paceCard }
                if !trendingThemes.isEmpty { trendingCard }
            } else {
                proUpsell
            }
        }
    }

    private func sentimentCard(_ series: [Trends.SentimentPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Emotional trend")).eyebrow(Paper.ink3)
                Spacer()
                if let delta = Trends.sentimentDelta(from: series) {
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(L(delta >= 0 ? "Brightening" : "Softening"))
                    }
                    .font(Typo.sans(11, .semibold))
                    .foregroundColor(Paper.terra)
                }
            }
            Chart(series) { p in
                if let s = p.sentiment {
                    LineMark(x: .value("Day", p.date, unit: .day),
                             y: .value("Sentiment", s))
                    .foregroundStyle(Paper.terra)
                    .interpolationMethod(.catmullRom)
                    .accessibilityLabel(p.date.formatted(.dateTime.month(.wide).day().locale(AppLocale.locale)))
                    .accessibilityValue(Sentiment.label(for: s))
                    AreaMark(x: .value("Day", p.date, unit: .day),
                             y: .value("Sentiment", s))
                    .foregroundStyle(LinearGradient(colors: [Paper.terra.opacity(0.35), Paper.terra.opacity(0.02)],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                    .accessibilityHidden(true)
                }
            }
            .chartYScale(domain: -1...1)
            .chartYAxis { AxisMarks(values: [-1, 0, 1]) { _ in AxisValueLabel().foregroundStyle(Paper.ink3) } }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                        .foregroundStyle(Paper.ink3)
                }
            }
            .frame(height: 140)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(22)
    }

    private var bestTimeCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Paper.terra.opacity(0.14)).frame(width: 44, height: 44)
                Image(systemName: "sunrise").font(.system(size: 18, weight: .semibold)).foregroundColor(Paper.terra)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(L("You journal most")).font(Typo.sans(12, .medium)).foregroundColor(Paper.ink3)
                Text(Trends.bestWindow(store.entries) ?? String(localized: "Not enough entries yet", bundle: AppLocale.bundle))
                    .font(Typo.sans(16, .semibold)).foregroundColor(Paper.ink)
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(22)
    }

    private var paceCard: some View {
        HStack(spacing: 24) {
            paceStat("Avg length", String(localized: "\(avgWordCount) words", bundle: AppLocale.bundle))
            Rectangle().fill(Paper.hair).frame(width: 1, height: 32)
            paceStat("Speaking pace", String(localized: "\(avgWPM) wpm", bundle: AppLocale.bundle))
        }
        .padding(.vertical, 20).padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .paperCard(22)
    }
    private func paceStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L(label)).font(Typo.sans(11, .medium)).foregroundColor(Paper.ink3)
            Text(value).font(Typo.sans(17, .bold)).foregroundColor(Paper.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Trending this month")).eyebrow(Paper.ink3)
            VStack(spacing: 10) {
                ForEach(trendingThemes.prefix(4), id: \.theme) { t in
                    HStack {
                        Text(t.theme.capitalized).font(Typo.sans(14, .medium)).foregroundColor(Paper.ink)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: t.delta >= 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(abs(t.delta))")
                                .font(Typo.sans(12, .semibold))
                        }
                        .foregroundColor(t.delta >= 0 ? Paper.terra : Paper.ink3)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background((t.delta >= 0 ? Paper.terra : Paper.ink3).opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(22)
    }

    // MARK: At a glance + milestones

    /// A synthesized plain-language recap of the month — ties the other signals together.
    private func digestCard(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 12, weight: .semibold)).foregroundColor(Paper.terra)
                Text(L("At a glance")).eyebrow()
            }
            Text(lines.joined(separator: " "))
                .font(Typo.serifItalic(17)).foregroundColor(Paper.ink).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).paperCard(20, fill: Paper.cardAlt)
        .accessibilityElement(children: .combine)
    }

    private func milestonesCard(_ words: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Your journey")).eyebrow(Paper.ink3)
            Text(words.formatted(.number.locale(AppLocale.locale)))
                .font(Typo.sans(28, .bold)).foregroundColor(Paper.ink)
            Text(String(localized: "words spoken across \(store.entries.count) entries · \(store.totalFormatted) recorded", bundle: AppLocale.bundle))
                .font(Typo.sans(13, .medium)).foregroundColor(Paper.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).paperCard(22)
        .accessibilityElement(children: .combine)
    }

    // MARK: Mood insights (from the moods you tag)

    /// Dominant mood + overall tone + a brightening/softening trend — the mood-valence algorithm.
    private func emotionalWeatherCard(_ dominant: Trends.DominantMood) -> some View {
        let valence = Trends.moodValence(store.entries, days: 30)
        let delta = Trends.moodValenceDelta(store.entries)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(dominant.mood.color.opacity(0.2)).frame(width: 44, height: 44)
                Image(systemName: dominant.mood.glyph)
                    .font(.system(size: 18, weight: .semibold)).foregroundColor(dominant.mood.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Emotional weather")).font(Typo.sans(12, .medium)).foregroundColor(Paper.ink3)
                Text(String(localized: "Mostly \(dominant.mood.label)", bundle: AppLocale.bundle))
                    .font(Typo.sans(16, .semibold)).foregroundColor(Paper.ink)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let valence {
                    Text(Sentiment.label(for: valence))
                        .font(Typo.sans(11, .semibold)).foregroundColor(Paper.terra)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Paper.terra.opacity(0.14)).clipShape(Capsule())
                }
                if let delta, abs(delta) > 0.05 {
                    HStack(spacing: 3) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(L(delta >= 0 ? "Brightening" : "Softening"))
                    }
                    .font(Typo.sans(10, .semibold)).foregroundColor(Paper.ink3)
                }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).paperCard(22)
        .accessibilityElement(children: .combine)
    }

    /// The most common move from one mood to another on the next entry — a transition model.
    private func moodShiftsCard(_ shift: Trends.MoodShift) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Mood shifts")).eyebrow(Paper.ink3)
            HStack(spacing: 10) {
                moodChip(shift.from)
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundColor(Paper.ink3)
                moodChip(shift.to)
                Spacer()
            }
            Text(String(localized: "After feeling \(shift.from.label), you often feel \(shift.to.label) next.", bundle: AppLocale.bundle))
                .font(Typo.serifItalic(14)).foregroundColor(Paper.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).paperCard(22)
        .accessibilityElement(children: .combine)
    }

    private func moodChip(_ mood: Mood) -> some View {
        HStack(spacing: 5) {
            Image(systemName: mood.glyph).font(.system(size: 11, weight: .semibold))
            Text(mood.label).font(Typo.sans(13, .medium))
        }
        .foregroundColor(Paper.ink2)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(mood.color.opacity(0.22))
        .clipShape(Capsule())
    }

    // MARK: Emotional balance

    private func balanceCard(_ b: Trends.EmotionalBalance) -> some View {
        let total = max(1, b.total)
        let brightPct = Int((Double(b.bright) / Double(total) * 100).rounded())
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Emotional balance")).eyebrow(Paper.ink3)
                Spacer()
                Text("\(brightPct)%").font(Typo.sans(11, .semibold)).foregroundColor(Paper.terra)
            }
            GeometryReader { g in
                HStack(spacing: 0) {
                    if b.bright > 0 { Rectangle().fill(Mood.joyful.color).frame(width: g.size.width * CGFloat(b.bright) / CGFloat(total)) }
                    if b.even > 0 { Rectangle().fill(Paper.muted).frame(width: g.size.width * CGFloat(b.even) / CGFloat(total)) }
                    if b.heavy > 0 { Rectangle().fill(Mood.raw.color).frame(width: g.size.width * CGFloat(b.heavy) / CGFloat(total)) }
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())
            .accessibilityElement()
            .accessibilityLabel("\(L("Bright")) \(b.bright), \(L("Even")) \(b.even), \(L("Heavy")) \(b.heavy)")
            HStack(spacing: 16) {
                balanceLegend(Mood.joyful.color, "Bright", b.bright)
                balanceLegend(Paper.muted, "Even", b.even)
                balanceLegend(Mood.raw.color, "Heavy", b.heavy)
                Spacer()
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).paperCard(22)
    }

    private func balanceLegend(_ color: Color, _ label: String, _ n: Int) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(L(label)).font(Typo.sans(11, .medium)).foregroundColor(Paper.ink3)
            Text("\(n)").font(Typo.sans(11, .semibold)).foregroundColor(Paper.ink2)
        }
    }

    // MARK: Mood by time of day

    private var daypartCard: some View {
        let data = Trends.moodByDaypart(store.entries).filter { $0.count > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Mood by time of day")).eyebrow(Paper.ink3)
                Spacer()
                if let bright = Trends.brightestDaypart(store.entries) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.system(size: 10, weight: .semibold))
                        Text(bright.label)
                    }
                    .font(Typo.sans(11, .semibold)).foregroundColor(Paper.terra)
                }
            }
            VStack(spacing: 10) {
                ForEach(data) { d in
                    HStack(spacing: 12) {
                        Image(systemName: d.part.glyph).font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Paper.terra).frame(width: 22)
                        Text(d.part.label).font(Typo.sans(14, .medium)).foregroundColor(Paper.ink)
                        Spacer()
                        if let s = d.avgSentiment {
                            Text(Sentiment.label(for: s))
                                .font(Typo.sans(11, .semibold))
                                .foregroundColor(Sentiment.suggestedMood(for: s).color)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Sentiment.suggestedMood(for: s).color.opacity(0.16))
                                .clipShape(Capsule())
                        } else {
                            Text("\(d.count)").font(Typo.sans(12, .semibold)).foregroundColor(Paper.ink3)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).paperCard(22)
    }

    // MARK: Weekly rhythm

    private var rhythmCard: some View {
        let data = Trends.weekdayRhythm(store.entries)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("Weekly rhythm")).eyebrow(Paper.ink3)
                Spacer()
                if let peak = Trends.peakWeekday(store.entries) {
                    Text(peak).font(Typo.sans(11, .semibold)).foregroundColor(Paper.terra)
                }
            }
            Chart(data) { d in
                BarMark(x: .value("Weekday", d.symbol), y: .value("Entries", d.count), width: .fixed(16))
                    .foregroundStyle(Paper.terra.opacity(d.count == 0 ? 0.15 : 0.85))
                    .cornerRadius(3)
                    .accessibilityLabel(d.symbol)
                    .accessibilityValue(String(localized: "\(d.count) entries", bundle: AppLocale.bundle))
            }
            .chartXScale(domain: data.map { $0.symbol })
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel().foregroundStyle(Paper.ink3)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel().foregroundStyle(Paper.ink3)
                }
            }
            .frame(height: 130)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).paperCard(22)
    }

    // MARK: Consistency

    private var consistencyCard: some View {
        let strip = Trends.activityStrip(store.entries, days: 30)
        let longest = Trends.longestStreak(store.entries)
        let active = Trends.activeDayCount(store.entries, inLast: 30)
        return VStack(alignment: .leading, spacing: 14) {
            Text(L("Consistency")).eyebrow(Paper.ink3)
            HStack(spacing: 24) {
                paceStat("Longest streak", "\(longest)")
                Rectangle().fill(Paper.hair).frame(width: 1, height: 32)
                paceStat("Days journaled", "\(active)/30")
            }
            GeometryReader { g in
                let n = strip.count
                let gap: CGFloat = 3
                let w = max(2, (g.size.width - gap * CGFloat(n - 1)) / CGFloat(n))
                HStack(spacing: gap) {
                    ForEach(strip) { d in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(d.count == 0 ? Paper.cardAlt : Paper.terra.opacity(min(1.0, 0.45 + Double(d.count) * 0.25)))
                            .frame(width: w, height: 24)
                    }
                }
            }
            .frame(height: 24)
            .accessibilityElement()
            .accessibilityLabel(String(localized: "Journaled \(active) of the last 30 days", bundle: AppLocale.bundle))
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).paperCard(22)
    }

    private func proHint(_ text: String) -> some View {
        Text(L(text)).font(Typo.serifItalic(14)).foregroundColor(Paper.ink3)
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .paperCard(20, fill: Paper.cardAlt)
    }

    private var proUpsell: some View {
        Button { presentPaywall() } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").font(.system(size: 14, weight: .semibold)).foregroundColor(Paper.terra)
                    Text(L("See deeper patterns"))
                        .font(Typo.sans(17, .semibold)).foregroundColor(Paper.ink)
                }
                Text(L("Emotional trend & balance, mood by time of day, weekly rhythm, consistency, speaking pace, and trending themes — all computed privately on your device."))
                    .font(Typo.serifItalic(14)).foregroundColor(Paper.ink2).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                    Text(L("Unlock with Pro")).font(Typo.sans(13, .semibold))
                }
                .foregroundColor(Paper.terra)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperCard(20, fill: Paper.cardAlt)
        }
        .buttonStyle(.plain)
    }

    // Cached inputs
    private var sentimentSeries: [Trends.SentimentPoint] { Trends.sentimentSeries(store.entries) }
    private var avgWordCount: Int { Trends.avgWordsPerEntry(store.entries) }
    private var avgWPM: Int { Trends.avgWordsPerMinute(store.entries) }
    private var trendingThemes: [Trends.ThemeTrend] { Trends.themeTrends(store.entries) }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 60)
            Image(systemName: "chart.bar.xaxis").font(.system(size: 44, weight: .light)).foregroundColor(Paper.terra.opacity(0.6))
                .accessibilityHidden(true)
            Text(L("Nothing to reflect on yet"))
                .font(Typo.sans(19, .semibold)).foregroundColor(Paper.ink)
            Text(L("Record a few entries and your\ntrends will appear here."))
                .font(Typo.serifItalic(16)).foregroundColor(Paper.ink3)
                .multilineTextAlignment(.center).lineSpacing(4)
            PrimaryCapsuleButton(title: "Record your first entry", icon: "mic.fill", action: goToCapture)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }

    // MARK: Data

    private struct ActivityPoint: Identifiable { let id = UUID(); let date: Date; let count: Int }
    private struct MoodCount { let mood: Mood; let count: Int }

    private var last14: [ActivityPoint] {
        (0..<14).reversed().map { back in
            let day = cal.date(byAdding: .day, value: -back, to: Date())!
            let count = store.entries.filter { cal.isDate($0.date, inSameDayAs: day) }.count
            return ActivityPoint(date: day, count: count)
        }
    }
    private var moodCounts: [MoodCount] {
        Mood.selectable.map { m in MoodCount(mood: m, count: store.entries.filter { $0.mood == m }.count) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }
    private var onThisDay: [VoiceEntry] {
        let today = cal.dateComponents([.month, .day], from: Date())
        return store.entries.filter {
            let c = cal.dateComponents([.month, .day], from: $0.date)
            return c.month == today.month && c.day == today.day && !cal.isDateInToday($0.date)
        }.sorted { $0.date > $1.date }
    }
    private var topThemes: [(String, Int)] {
        var counts: [String: Int] = [:]
        for e in store.entries { for t in e.themes { counts[t, default: 0] += 1 } }
        return counts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
    }

}
