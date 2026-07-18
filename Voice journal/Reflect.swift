//  Reflect.swift — Voice Journal
//  Entry detail: audio pill, AI summary, transcript, mood, notes.

import SwiftUI

struct ReflectView: View {
    let entryID: UUID
    @ObservedObject var store: JournalStore
    @ObservedObject var engine: AudioEngine
    @ObservedObject var settings: AppSettings
    @ObservedObject var transcription: TranscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var showRename = false
    @State private var renameText = ""
    @State private var editingNote = false
    @State private var noteDraft = ""
    @State private var editingTranscript = false
    @State private var transcriptDraft = ""
    @State private var showShare = false
    @FocusState private var noteFocused: Bool

    private var entry: VoiceEntry? { store.entries.first { $0.id == entryID } }
    private var isWorking: Bool { transcription.working.contains(entryID) }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            if let entry {
                content(entry)
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func content(_ entry: VoiceEntry) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                topBar(entry)

                // Title block
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(Typo.sans(14, .medium)).foregroundColor(Paper.ink3)
                    Text(entry.title)
                        .font(Typo.sans(28, .bold)).foregroundColor(Paper.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(entry.timeShort) · \(entry.durationLong)")
                        .font(Typo.sans(13, .medium)).foregroundColor(Paper.ink3)
                }
                .padding(.horizontal, 24)

                // Audio pill
                AudioPill(engine: engine, entry: entry)
                    .padding(.horizontal, 24)

                // Prompt (if the entry was recorded against one)
                if !entry.prompt.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "text.quote").font(.system(size: 13)).foregroundColor(Paper.terra)
                        Text(entry.prompt).font(Typo.serifItalic(15)).foregroundColor(Paper.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 24)
                }

                // Summary
                if !entry.summary.isEmpty {
                    summaryCard(entry).padding(.horizontal, 24)
                }

                // Transcript
                transcriptSection(entry).padding(.horizontal, 24)

                // Mood
                moodSection(entry).padding(.horizontal, 24)

                // Note
                noteSection(entry).padding(.horizontal, 24)

                Spacer().frame(height: 40)
            }
            .padding(.top, 6)
        }
        .alert("Rename entry", isPresented: $showRename) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                var e = entry
                let t = renameText.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { e.title = t; store.update(e); HX.soft() }
            }
        }
        .sheet(isPresented: $showShare) { ShareSheet(url: store.docURL(entry.fileName)) }
        .onAppear {
            store.ensureWaveform(for: entry)
            if entry.transcript.isEmpty && settings.autoTranscribe && transcription.isSupported {
                transcription.transcribe(entry, store: store)
            }
        }
    }

    // MARK: Top bar

    private func topBar(_ entry: VoiceEntry) -> some View {
        HStack {
            CircleIconButton(system: "chevron.left") { HX.tap(); dismiss() }
            Spacer()
            HStack(spacing: 10) {
                Button {
                    var e = entry; e.isFavorite.toggle(); store.update(e); HX.tap()
                } label: {
                    Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(entry.isFavorite ? Paper.terra : Paper.ink2)
                        .frame(width: 44, height: 44)
                        .background(Paper.card).clipShape(Circle())
                        .overlay(Circle().stroke(Paper.hair, lineWidth: 1))
                }.buttonStyle(.plain)

                Menu {
                    Button { renameText = entry.title; showRename = true } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button { showShare = true } label: { Label("Share audio", systemImage: "square.and.arrow.up") }
                    if transcription.isSupported {
                        Button { transcription.transcribe(entry, store: store, force: true); HX.tap() } label: {
                            Label(entry.transcript.isEmpty ? "Transcribe" : "Re-transcribe", systemImage: "waveform")
                        }
                    }
                    Divider()
                    Button(role: .destructive) { store.remove(entry); dismiss() } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(Paper.ink2)
                        .frame(width: 44, height: 44)
                        .background(Paper.card).clipShape(Circle())
                        .overlay(Circle().stroke(Paper.hair, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Summary

    private func summaryCard(_ entry: VoiceEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 12, weight: .semibold)).foregroundColor(Paper.terra)
                Text("Summary").eyebrow()
            }
            Text(entry.summary)
                .font(Typo.sans(16))
                .foregroundColor(Paper.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            if !entry.themes.isEmpty {
                FlowChips(items: entry.themes)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(20, fill: Paper.cardAlt)
    }

    // MARK: Transcript

    private func transcriptSection(_ entry: VoiceEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcript").eyebrow(Paper.ink3)
                if !entry.words.isEmpty && !editingTranscript {
                    Text("· tap a word to play")
                        .font(Typo.sans(11)).foregroundColor(Paper.muted)
                }
                Spacer()
                if !entry.transcript.isEmpty {
                    Button {
                        if editingTranscript {
                            var e = entry
                            e.transcript = transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            e.words = []              // manual edits invalidate word timings
                            store.update(e); editingTranscript = false; HX.soft()
                        } else {
                            transcriptDraft = entry.transcript; editingTranscript = true; HX.tap()
                        }
                    } label: {
                        Text(editingTranscript ? "Done" : "Edit")
                            .font(Typo.sans(13, .semibold)).foregroundColor(Paper.terra)
                    }.buttonStyle(.plain)
                }
            }

            if editingTranscript {
                TextEditor(text: $transcriptDraft)
                    .font(Typo.sans(16)).foregroundColor(Paper.ink2)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(12)
                    .background(Paper.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Paper.hair, lineWidth: 1))
            } else if !entry.words.isEmpty {
                InteractiveTranscript(entry: entry, engine: engine)
            } else if !entry.transcript.isEmpty {
                Text(entry.transcript)
                    .font(Typo.sans(16))
                    .foregroundColor(Paper.ink2)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } else if isWorking {
                HStack(spacing: 10) {
                    ProgressView().tint(Paper.terra)
                    Text(transcription.state == .preparing ? "Loading the on-device model…" : "Transcribing…")
                        .font(Typo.serifItalic(15)).foregroundColor(Paper.ink3)
                }
                .padding(.vertical, 8)
            } else if transcription.isSupported {
                Button {
                    HX.tap(); transcription.transcribe(entry, store: store, force: true)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform").font(.system(size: 14, weight: .semibold))
                        Text("Transcribe this entry").font(Typo.sans(15, .semibold))
                    }
                    .foregroundColor(Paper.terra)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Paper.terra.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Text("Transcription isn't available on this device.")
                    .font(Typo.serifItalic(15)).foregroundColor(Paper.ink3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Mood

    private func moodSection(_ entry: VoiceEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How did it feel?").eyebrow(Paper.ink3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Mood.selectable) { m in
                        let on = entry.mood == m
                        Button {
                            HX.tick()
                            var e = entry; e.mood = on ? .none : m; store.update(e)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: m.glyph).font(.system(size: 11, weight: .semibold))
                                Text(m.label).font(Typo.sans(13, .medium))
                            }
                            .foregroundColor(on ? Paper.ink : Paper.ink2)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(on ? m.color.opacity(0.28) : Paper.card)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(on ? m.color.opacity(0.5) : Paper.hair, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(m.label)
                        .accessibilityAddTraits(on ? [.isSelected] : [])
                    }
                }
            }
        }
    }

    // MARK: Note

    private func noteSection(_ entry: VoiceEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Note").eyebrow(Paper.ink3)
                Spacer()
                Button {
                    if editingNote {
                        var e = entry; e.note = noteDraft; store.update(e); editingNote = false; noteFocused = false; HX.soft()
                    } else {
                        noteDraft = entry.note; editingNote = true; noteFocused = true; HX.tap()
                    }
                } label: {
                    Text(editingNote ? "Done" : (entry.note.isEmpty ? "Add" : "Edit"))
                        .font(Typo.sans(13, .semibold)).foregroundColor(Paper.terra)
                }.buttonStyle(.plain)
            }

            if editingNote {
                TextEditor(text: $noteDraft)
                    .focused($noteFocused)
                    .font(Typo.sans(15))
                    .foregroundColor(Paper.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 90)
                    .padding(12)
                    .background(Paper.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Paper.hair, lineWidth: 1))
            } else {
                Text(entry.note.isEmpty ? "Add your own reflection…" : entry.note)
                    .font(Typo.sans(15))
                    .foregroundColor(entry.note.isEmpty ? Paper.muted : Paper.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(4)
            }
        }
    }
}

// MARK: - Theme chips row (wraps to two rows if needed)

struct FlowChips: View {
    let items: [String]
    var body: some View {
        // Summaries yield at most a handful of short chips; two rows of three covers it.
        let rows = stride(from: 0, to: items.count, by: 3).map {
            Array(items[$0..<min($0 + 3, items.count)])
        }
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { text in
                        ThemeChip(text: text,
                                  leadingGlyph: text.caseInsensitiveCompare("calm") == .orderedSame ? "sun.max" : nil)
                    }
                }
            }
        }
    }
}
