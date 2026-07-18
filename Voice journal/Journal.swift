//  Journal.swift — Voice Journal
//  The entry feed: header, weekly mood strip, entry cards.

import SwiftUI

struct JournalView: View {
    @ObservedObject var store: JournalStore
    @ObservedObject var engine: AudioEngine
    @ObservedObject var settings: AppSettings
    @ObservedObject var transcription: TranscriptionManager
    var goToCapture: () -> Void = {}

    @State private var searching = false
    @AppStorage("vj_calendar") private var calendarMode = false
    @StateObject private var motivation = MotivationService()
    @FocusState private var searchFocused: Bool

    private var playingEntry: VoiceEntry? { store.entries.first { $0.id == engine.playingID } }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header

                    if searching {
                        searchField.padding(.horizontal, 20)
                    }

                    if settings.showMotivation && !searching {
                        MotivationCard(service: motivation)
                            .padding(.horizontal, 20)
                    }

                    if store.entries.isEmpty {
                        emptyState
                    } else {
                        MoodFilterChips(store: store)

                        if calendarMode {
                            CalendarMonthView(store: store, engine: engine,
                                              settings: settings, transcription: transcription)
                        } else {
                            if (!searching || store.searchQuery.isEmpty) && store.moodFilter == nil {
                                WeekMoodStrip(moods: store.weekMoods())
                                    .padding(.horizontal, 20)
                            }

                            let items = store.filtered()
                            if items.isEmpty {
                                noResults
                            } else {
                                LazyVStack(spacing: 14) {
                                    ForEach(items) { entry in
                                        NavigationLink(value: entry) {
                                            EntryCard(entry: entry, engine: engine, store: store,
                                                      transcribing: transcription.working.contains(entry.id))
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button {
                                                var e = entry; e.isFavorite.toggle(); store.update(e); HX.tap()
                                            } label: {
                                                Label(entry.isFavorite ? "Unfavorite" : "Favorite",
                                                      systemImage: entry.isFavorite ? "heart.slash" : "heart")
                                            }
                                            Button(role: .destructive) { store.remove(entry); HX.warn() } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }

                    Spacer().frame(height: playingEntry != nil ? 90 : 24)
                }
                .padding(.top, 6)
            }
        }
        .navigationBarHidden(true)
        .onAppear { if settings.showMotivation { motivation.loadDaily() } }
        .navigationDestination(for: VoiceEntry.self) { entry in
            ReflectView(entryID: entry.id, store: store, engine: engine,
                        settings: settings, transcription: transcription)
        }
        .safeAreaInset(edge: .bottom) {
            if let e = playingEntry {
                MiniPlayerBar(engine: engine, entry: e)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: playingEntry?.id)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().formatted(.dateTime.month(.wide).year())).eyebrow()
                Text("Your journal")
                    .font(Typo.sans(32, .bold))
                    .foregroundColor(Paper.ink)
            }
            Spacer()
            HStack(spacing: 10) {
                if !store.entries.isEmpty {
                    CircleIconButton(system: calendarMode ? "list.bullet" : "calendar") {
                        HX.tap()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { calendarMode.toggle() }
                    }
                }
                CircleIconButton(system: searching ? "xmark" : "magnifyingglass") {
                    HX.tap()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        searching.toggle()
                        if !searching { store.searchQuery = ""; searchFocused = false }
                        else { searchFocused = true }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(Paper.ink3)
            TextField("Search entries & transcripts", text: $store.searchQuery)
                .font(Typo.sans(15))
                .foregroundColor(Paper.ink)
                .focused($searchFocused)
                .submitLabel(.search)
            if !store.searchQuery.isEmpty {
                Button { store.searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Paper.muted)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Paper.card)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Paper.hair, lineWidth: 1))
    }

    // MARK: Empty states

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 60)
            Image(systemName: "waveform")
                .font(.system(size: 46, weight: .light))
                .foregroundColor(Paper.terra.opacity(0.6))
                .accessibilityHidden(true)
            Text("Your journal is quiet")
                .font(Typo.sans(19, .semibold)).foregroundColor(Paper.ink)
            Text("Speak your first entry and it'll\nappear here, transcribed.")
                .font(Typo.serifItalic(16))
                .foregroundColor(Paper.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            PrimaryCapsuleButton(title: "Record your first entry", icon: "mic.fill", action: goToCapture)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var noResults: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 40)
            Image(systemName: "magnifyingglass").font(.system(size: 30)).foregroundColor(Paper.muted)
            Text("No matches").font(Typo.sans(16, .medium)).foregroundColor(Paper.ink3)
        }
        .frame(maxWidth: .infinity).padding(.top, 30)
    }
}

// MARK: - Entry card

struct EntryCard: View {
    let entry: VoiceEntry
    @ObservedObject var engine: AudioEngine
    @ObservedObject var store: JournalStore
    var transcribing: Bool
    private var isPlaying: Bool { engine.playingID == entry.id && engine.state == .playing }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 7) {
                    Text(entry.groupLabel)
                        .font(Typo.sans(16, .bold)).foregroundColor(Paper.ink)
                    if entry.isFavorite {
                        Image(systemName: "heart.fill").font(.system(size: 11)).foregroundColor(Paper.terra)
                    }
                }
                Spacer()
                Text("\(entry.timeShort) · \(entry.durationClock)")
                    .font(Typo.sans(13, .medium)).foregroundColor(Paper.ink3)
            }

            Text(entry.preview)
                .font(Typo.serifItalic(16))
                .foregroundColor(Paper.ink2)
                .lineSpacing(3)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button {
                    HX.press(); engine.togglePlay(entry: entry)
                } label: {
                    ZStack {
                        Circle().fill(Paper.terra.opacity(isPlaying ? 0.9 : 0.14)).frame(width: 34, height: 34)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isPlaying ? Paper.white : Paper.terra)
                            .offset(x: isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                MiniWaveform(bars: entry.waveform, count: 22, color: Paper.tan,
                             progress: isPlaying ? engine.playProgress : 0)
                    .frame(height: 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)

                if transcribing {
                    ProgressView().scaleEffect(0.7).tint(Paper.terra)
                } else if entry.mood != .none {
                    MoodTag(mood: entry.mood)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(22)
        .onAppear { store.ensureWaveform(for: entry) }
    }
}

// MARK: - Mini player bar (bottom, while a clip plays)

struct MiniPlayerBar: View {
    @ObservedObject var engine: AudioEngine
    let entry: VoiceEntry

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Paper.hair).frame(height: 3)
                    Rectangle().fill(Paper.terra)
                        .frame(width: max(0, g.size.width * engine.playProgress), height: 3)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                    engine.seek(to: min(max(0, v.location.x / g.size.width), 1)); HX.rigid()
                })
            }
            .frame(height: 3)
            .accessibilityHidden(true)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).font(Typo.sans(14, .semibold)).foregroundColor(Paper.ink).lineLimit(1)
                    Text("\(engine.fmt(engine.playTime)) / \(engine.fmt(engine.playDuration))")
                        .font(Typo.sans(11, .medium)).foregroundColor(Paper.ink3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Now playing \(entry.title), \(engine.fmt(engine.playTime)) of \(engine.fmt(engine.playDuration))")

                Button { HX.tap(); engine.skip(seconds: -15) } label: {
                    Image(systemName: "gobackward.15").font(.system(size: 18)).foregroundColor(Paper.ink2)
                }.buttonStyle(.plain)
                .accessibilityLabel("Skip back 15 seconds")

                Button { HX.press(); engine.togglePlay(entry: entry) } label: {
                    Image(systemName: engine.state == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22)).foregroundColor(Paper.terra)
                }.buttonStyle(.plain)
                .accessibilityLabel(engine.state == .playing ? "Pause" : "Play")

                Button { HX.tap(); engine.stopPlaying() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundColor(Paper.ink3)
                }.buttonStyle(.plain)
                .accessibilityLabel("Stop playback")
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(Paper.hair).frame(height: 1), alignment: .top)
    }
}
