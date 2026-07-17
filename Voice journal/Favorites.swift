//  Favorites.swift — Voice Journal
//  Saved entries, in the same card style as the Journal feed.

import SwiftUI

struct FavoritesView: View {
    @ObservedObject var store: JournalStore
    @ObservedObject var engine: AudioEngine
    @ObservedObject var settings: AppSettings
    @ObservedObject var transcription: TranscriptionManager

    private var favorites: [VoiceEntry] {
        store.entries.filter { $0.isFavorite }.sorted { $0.date > $1.date }
    }
    private var playingEntry: VoiceEntry? { store.entries.first { $0.id == engine.playingID } }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header

                    if favorites.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(favorites) { entry in
                                NavigationLink(value: entry) {
                                    EntryCard(entry: entry, engine: engine, store: store,
                                              transcribing: transcription.working.contains(entry.id))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        var e = entry; e.isFavorite.toggle(); store.update(e); HX.tap()
                                    } label: {
                                        Label("Remove from favorites", systemImage: "heart.slash")
                                    }
                                    Button(role: .destructive) { store.remove(entry); HX.warn() } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: playingEntry != nil ? 90 : 24)
                }
                .padding(.top, 6)
            }
        }
        .navigationBarHidden(true)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(favorites.isEmpty ? "Saved" : "\(favorites.count) saved").eyebrow()
            Text("Favorites")
                .font(Typo.sans(32, .bold))
                .foregroundColor(Paper.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 60)
            Image(systemName: "heart")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Paper.terra.opacity(0.6))
            Text("No favorites yet")
                .font(Typo.sans(19, .semibold)).foregroundColor(Paper.ink)
            Text("Tap the heart on any entry\nto keep it here.")
                .font(Typo.serifItalic(16))
                .foregroundColor(Paper.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
