//  Insights.swift — Voice Journal
//  Trends, mood distribution, themes, and "on this day".

import SwiftUI
import Charts

struct InsightsView: View {
    @ObservedObject var store: JournalStore
    @ObservedObject var engine: AudioEngine
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
            Text("Reflect").eyebrow()
            Text("Insights").font(Typo.sans(32, .bold)).foregroundColor(Paper.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private var statRow: some View {
        HStack(spacing: 0) {
            stat("\(store.entries.count)", "entries")
            vline
            stat(store.totalFormatted, "recorded")
            vline
            stat(store.streak == 0 ? "—" : "\(store.streak)", "day streak")
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .paperCard(22)
    }

    // MARK: Activity chart

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Last 14 days").eyebrow(Paper.ink3)
            Chart(last14) { p in
                BarMark(
                    x: .value("Day", p.date, unit: .day),
                    y: .value("Entries", p.count),
                    width: .fixed(10)
                )
                .foregroundStyle(Paper.terra.opacity(p.count == 0 ? 0.15 : 0.85))
                .cornerRadius(3)
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
            Text("How you've felt").eyebrow(Paper.ink3)
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
                    .accessibilityLabel("\(mc.mood.label): \(mc.count) \(mc.count == 1 ? "entry" : "entries")")
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
            Text("Recurring themes").eyebrow(Paper.ink3)
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
                Text("On this day").eyebrow()
            }
            ForEach(onThisDay.prefix(4)) { entry in
                NavigationLink(value: entry) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.date.formatted(.dateTime.year()))
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
                Text("Advanced").eyebrow()
                if !purchases.isPro {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill").font(.system(size: 8, weight: .bold))
                        Text("PRO").font(Typo.sans(9, .bold)).tracking(0.4)
                    }
                    .foregroundColor(Paper.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Paper.terra).clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.top, 4)

            if purchases.isPro {
                if !sentimentSeries.contains(where: { $0.sentiment != nil }) {
                    proHint("Sentiment appears once your entries are transcribed.")
                } else {
                    sentimentCard
                }
                bestTimeCard
                if avgWordCount > 0 { paceCard }
                if !trendingThemes.isEmpty { trendingCard }
            } else {
                proUpsell
            }
        }
    }

    private var sentimentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Emotional trend").eyebrow(Paper.ink3)
                Spacer()
                if let delta = Trends.sentimentDelta(store.entries) {
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(delta >= 0 ? "Brightening" : "Softening")
                    }
                    .font(Typo.sans(11, .semibold))
                    .foregroundColor(Paper.terra)
                }
            }
            Chart(sentimentSeries) { p in
                if let s = p.sentiment {
                    LineMark(x: .value("Day", p.date, unit: .day),
                             y: .value("Sentiment", s))
                    .foregroundStyle(Paper.terra)
                    .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Day", p.date, unit: .day),
                             y: .value("Sentiment", s))
                    .foregroundStyle(LinearGradient(colors: [Paper.terra.opacity(0.35), Paper.terra.opacity(0.02)],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
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
                Text("You journal most").font(Typo.sans(12, .medium)).foregroundColor(Paper.ink3)
                Text(Trends.bestWindow(store.entries) ?? "Not enough entries yet")
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
            paceStat("Avg length", "\(avgWordCount) words")
            Rectangle().fill(Paper.hair).frame(width: 1, height: 32)
            paceStat("Speaking pace", "\(avgWPM) wpm")
        }
        .padding(.vertical, 20).padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .paperCard(22)
    }
    private func paceStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Typo.sans(11, .medium)).foregroundColor(Paper.ink3)
            Text(value).font(Typo.sans(17, .bold)).foregroundColor(Paper.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trending this month").eyebrow(Paper.ink3)
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

    private func proHint(_ text: String) -> some View {
        Text(text).font(Typo.serifItalic(14)).foregroundColor(Paper.ink3)
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .paperCard(20, fill: Paper.cardAlt)
    }

    private var proUpsell: some View {
        Button { presentPaywall() } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").font(.system(size: 14, weight: .semibold)).foregroundColor(Paper.terra)
                    Text("See deeper patterns")
                        .font(Typo.sans(17, .semibold)).foregroundColor(Paper.ink)
                }
                Text("Emotional trend, best time to journal, speaking pace, trending themes — all computed on your device.")
                    .font(Typo.serifItalic(14)).foregroundColor(Paper.ink2).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                    Text("Unlock with Pro").font(Typo.sans(13, .semibold))
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
            Text("Nothing to reflect on yet")
                .font(Typo.sans(19, .semibold)).foregroundColor(Paper.ink)
            Text("Record a few entries and your\ntrends will appear here.")
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

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 5) {
            Text(v).font(Typo.sans(22, .bold)).foregroundColor(Paper.ink)
            Text(l).font(Typo.sans(11, .medium)).foregroundColor(Paper.ink3)
        }
        .frame(maxWidth: .infinity)
    }
    private var vline: some View { Rectangle().fill(Paper.hair).frame(width: 1, height: 34) }
}
