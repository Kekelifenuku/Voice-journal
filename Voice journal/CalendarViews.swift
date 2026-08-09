//  CalendarViews.swift — Voice Journal
//  Mood filter chips + a month calendar view for the Journal.

import SwiftUI

// MARK: - Mood filter chips

struct MoodFilterChips: View {
    @ObservedObject var store: JournalStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(L("All"), active: store.moodFilter == nil, tint: Paper.ink) {
                    store.moodFilter = nil; HX.tick()
                }
                ForEach(Mood.selectable) { m in
                    chip(m.label, active: store.moodFilter == m, tint: m.color) {
                        store.moodFilter = store.moodFilter == m ? nil : m; HX.tick()
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chip(_ label: String, active: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Typo.sans(13, .medium))
                .foregroundColor(active ? Paper.ink : Paper.ink3)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(active ? tint.opacity(0.24) : Paper.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(active ? tint.opacity(0.5) : Paper.hair, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Filter by \(label)", bundle: AppLocale.bundle))
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}

// MARK: - Month calendar

struct CalendarMonthView: View {
    @ObservedObject var store: JournalStore
    @ObservedObject var engine: AudioEngine
    @ObservedObject var settings: AppSettings
    @ObservedObject var transcription: TranscriptionManager

    @State private var displayed = Date()
    @State private var selected: Date?

    private var cal: Calendar { Calendar.current }
    /// Weekday header symbols in the selected app language.
    private var weekdaySymbols: [String] {
        var c = Calendar.current; c.locale = AppLocale.locale
        return c.veryShortWeekdaySymbols
    }
    private var entriesForSelected: [VoiceEntry] {
        guard let s = selected else { return [] }
        return store.entries
            .filter { cal.isDate($0.date, inSameDayAs: s) && (store.moodFilter == nil || $0.mood == store.moodFilter) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                navButton("chevron.left") { shift(-1) }
                Spacer()
                Text(displayed.formatted(.dateTime.month(.wide).year().locale(AppLocale.locale)))
                    .font(Typo.sans(17, .semibold)).foregroundColor(Paper.ink)
                Spacer()
                navButton("chevron.right") { shift(1) }
            }
            .padding(.horizontal, 24)

            // Weekday headers
            let weekdays = weekdaySymbols
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, d in
                    Text(d).font(Typo.sans(11, .semibold)).foregroundColor(Paper.ink3).frame(height: 22)
                }
                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
            .padding(.horizontal, 16)

            // Selected day entries
            if selected != nil {
                if entriesForSelected.isEmpty {
                    Text(L("No entries this day"))
                        .font(Typo.serifItalic(15)).foregroundColor(Paper.ink3).padding(.top, 6)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(entriesForSelected) { entry in
                            NavigationLink(value: entry) {
                                EntryCard(entry: entry, engine: engine, store: store,
                                          transcribing: transcription.working.contains(entry.id))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let key = dayKey(day)
        let has = store.daysWithEntries.contains(key)
        let isSel = selected.map { cal.isDate(day, inSameDayAs: $0) } ?? false
        let isToday = cal.isDateInToday(day)
        let count = store.entries.filter { cal.isDate($0.date, inSameDayAs: day) }.count
        // Tint the dot with that day's most recent mood.
        let mood = store.entries.filter { cal.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date > $1.date }.first?.mood
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selected = isSel ? nil : day
            }
            isSel ? HX.tap() : HX.press()
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .font(Typo.sans(14, has || isToday ? .semibold : .regular))
                    .foregroundColor(isSel ? Paper.white : (isToday ? Paper.terra : Paper.ink2))
                Circle()
                    .fill(has ? (mood.map { $0 == .none ? Paper.terra : $0.color } ?? Paper.terra) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(isSel ? Paper.terra : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayLabel(day, count: count, isToday: isToday))
        .accessibilityAddTraits(isSel ? [.isSelected] : [])
    }

    /// VoiceOver label for a calendar day, e.g. "Today, July 6, 2 entries".
    private func dayLabel(_ day: Date, count: Int, isToday: Bool) -> String {
        let date = day.formatted(.dateTime.month(.wide).day().locale(AppLocale.locale))
        let entries = count == 0 ? String(localized: "no entries", bundle: AppLocale.bundle) : (count == 1 ? String(localized: "1 entry", bundle: AppLocale.bundle) : "\(count) entries")
        return "\(isToday ? "Today, " : "")\(date), \(entries)"
    }

    private func navButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system).font(.system(size: 15, weight: .semibold))
                .foregroundColor(Paper.ink2).frame(width: 36, height: 36)
                .background(Paper.card).clipShape(Circle())
                .overlay(Circle().stroke(Paper.hair, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func shift(_ months: Int) {
        HX.rigid()
        displayed = cal.date(byAdding: .month, value: months, to: displayed)!
    }

    private func daysInMonth() -> [Date?] {
        let range = cal.range(of: .day, in: .month, for: displayed)!
        let comps = cal.dateComponents([.year, .month], from: displayed)
        let first = cal.date(from: comps)!
        let leading = cal.component(.weekday, from: first) - 1
        var days: [Date?] = Array(repeating: nil, count: leading)
        for d in range { days.append(cal.date(byAdding: .day, value: d - 1, to: first)) }
        return days
    }
    private func dayKey(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
    }
}
