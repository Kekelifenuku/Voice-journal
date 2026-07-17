//  Settings.swift — Voice Journal
//  App settings model + the Settings screen (Paper styled).

import SwiftUI
import Combine
import StoreKit
import UserNotifications
import UniformTypeIdentifiers

// MARK: - Settings model

@MainActor
final class AppSettings: ObservableObject {
    @Published var remindersOn        = false { didSet { save(); remindersOn ? scheduleReminder() : cancelReminders() } }
    @Published var reminderHour       = 20    { didSet { save() } }
    @Published var reminderMinute     = 0     { didSet { save() } }
    @Published var playbackSpeed      = 1.0   { didSet { save() } }
    @Published var hapticsEnabled     = true  { didSet { save(); HX.setEnabled(hapticsEnabled) } }
    @Published var autoTranscribe     = true  { didSet { save() } }
    @Published var showPromptOnCapture = true { didSet { save() } }
    @Published var showMotivation      = true { didSet { save() } }   // daily motivation card in Journal
    @Published var modelQuality       = "base" { didSet { save() } }  // tiny | base | small
    @Published var language           = "en"   { didSet { save() } }  // en | es | fr | de | auto
    @Published var liveTranscription  = false  { didSet { save() } }  // beta: stream words while recording
    @Published var appearance         = "system" { didSet { save() } } // system | light | dark

    /// English-only models are faster & more accurate for English; other languages need multilingual.
    var effectiveModelName: String { language == "en" ? "\(modelQuality).en" : modelQuality }

    init() { load() }

    private func save() {
        let d = UserDefaults.standard
        d.set(remindersOn,        forKey: "s_rem")
        d.set(reminderHour,       forKey: "s_remH")
        d.set(reminderMinute,     forKey: "s_remM")
        d.set(playbackSpeed,      forKey: "s_speed")
        d.set(hapticsEnabled,     forKey: "s_haptics")
        d.set(autoTranscribe,     forKey: "s_autoTx")
        d.set(showPromptOnCapture,forKey: "s_prompt")
        d.set(showMotivation,     forKey: "s_motiv")
        d.set(modelQuality,       forKey: "s_modelq")
        d.set(language,           forKey: "s_lang")
        d.set(effectiveModelName, forKey: "s_model")   // read by TranscriptionManager
        d.set(appearance,         forKey: "s_appearance")
        d.set(liveTranscription,  forKey: "s_live")
    }
    private func load() {
        let d = UserDefaults.standard
        remindersOn        = d.bool(forKey: "s_rem")
        reminderHour       = d.object(forKey: "s_remH")   as? Int    ?? 20
        reminderMinute     = d.object(forKey: "s_remM")   as? Int    ?? 0
        playbackSpeed      = d.object(forKey: "s_speed")  as? Double ?? 1.0
        hapticsEnabled     = d.object(forKey: "s_haptics") as? Bool  ?? true
        autoTranscribe     = d.object(forKey: "s_autoTx") as? Bool   ?? true
        showPromptOnCapture = d.object(forKey: "s_prompt") as? Bool  ?? true
        showMotivation     = d.object(forKey: "s_motiv") as? Bool   ?? true
        modelQuality       = d.string(forKey: "s_modelq") ?? "base"
        language           = d.string(forKey: "s_lang") ?? "en"
        appearance         = d.string(forKey: "s_appearance") ?? "system"
        liveTranscription  = d.object(forKey: "s_live") as? Bool ?? false
        HX.setEnabled(hapticsEnabled)
    }

    func scheduleReminder() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let c = UNMutableNotificationContent()
            c.title = "A moment to reflect"
            c.body  = "Open your journal and speak today's thoughts."
            c.sound = .default
            var dc = DateComponents(); dc.hour = self.reminderHour; dc.minute = self.reminderMinute
            let req = UNNotificationRequest(identifier: "vj_daily", content: c,
                trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
            UNUserNotificationCenter.current().add(req)
        }
    }
    func cancelReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["vj_daily"])
    }
    var reminderDate: Date {
        get { Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date())! }
        set {
            reminderHour   = Calendar.current.component(.hour, from: newValue)
            reminderMinute = Calendar.current.component(.minute, from: newValue)
            if remindersOn { scheduleReminder() }
        }
    }
}

// MARK: - Settings screen

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: JournalStore
    @ObservedObject var transcription: TranscriptionManager
    @State private var showDeleteConfirm = false
    @State private var shareItems: [Any] = []
    @State private var showShare = false
    @State private var showImporter = false
    @State private var busy = false
    @State private var alertMessage: String?

    /// App version read from the bundle (CFBundleShortVersionString + build), so it never drifts.
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        if let build, !build.isEmpty, build != short { return "\(short) (\(build))" }
        return short
    }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {

                    // Stats card
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

                    // Transcription
                    settingsGroup("Transcription") {
                        toggleRow("Auto-transcribe recordings", "waveform.and.mic",
                                  isOn: $settings.autoTranscribe)
                        divider
                        pickerRow("Quality", icon: "dial.medium", selection: $settings.modelQuality,
                                  options: [("tiny", "Fast"), ("base", "Balanced"), ("small", "Accurate")]) {
                            transcription.reload()
                        }
                        divider
                        pickerRow("Language", icon: "globe", selection: $settings.language,
                                  options: [("en", "English"), ("es", "Spanish"), ("fr", "French"),
                                            ("de", "German"), ("auto", "Auto-detect")]) {
                            transcription.reload()
                        }
                        divider
                        row("Model status", icon: "cpu", trailing: modelStatusText)
                    }

                    // Capture
                    settingsGroup("Capture") {
                        toggleRow("Show daily prompt", "text.quote",
                                  isOn: $settings.showPromptOnCapture)
                        divider
                        toggleRow("Daily motivation", "sun.max",
                                  isOn: $settings.showMotivation)
                        divider
                        toggleRow("Live transcription (beta)", "text.viewfinder",
                                  isOn: $settings.liveTranscription)
                    }

                    // Playback
                    settingsGroup("Playback") {
                        HStack {
                            Label {
                                Text("Default speed").font(Typo.sans(15)).foregroundColor(Paper.ink)
                            } icon: {
                                Image(systemName: "gauge.with.dots.needle.50percent").foregroundColor(Paper.terra)
                            }
                            Spacer()
                            Picker("", selection: $settings.playbackSpeed) {
                                Text("0.5×").tag(0.5); Text("1×").tag(1.0)
                                Text("1.5×").tag(1.5); Text("2×").tag(2.0)
                            }
                            .pickerStyle(.menu).tint(Paper.terra)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }

                    // Reminder
                    settingsGroup("Daily reminder") {
                        toggleRow("Remind me to reflect", "bell", isOn: $settings.remindersOn)
                        if settings.remindersOn {
                            divider
                            HStack {
                                Label {
                                    Text("Time").font(Typo.sans(15)).foregroundColor(Paper.ink)
                                } icon: {
                                    Image(systemName: "clock").foregroundColor(Paper.terra)
                                }
                                Spacer()
                                DatePicker("", selection: Binding(
                                    get: { settings.reminderDate },
                                    set: { settings.reminderDate = $0; HX.tick() }),
                                    displayedComponents: .hourAndMinute)
                                .labelsHidden().tint(Paper.terra)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                        }
                    }

                    // Appearance
                    settingsGroup("Appearance") {
                        pickerRow("Theme", icon: "circle.lefthalf.filled", selection: $settings.appearance,
                                  options: [("system", "System"), ("light", "Light"), ("dark", "Dark")]) { }
                    }

                    // Feel
                    settingsGroup("Feel") {
                        toggleRow("Haptics", "hand.tap", isOn: $settings.hapticsEnabled)
                    }

                    // About
                    settingsGroup("About") {
                        linkRow("Rate Voice Journal", "star") { requestReview() }
                        divider
                        linkRow("Share the app", "square.and.arrow.up") {
                            if let url = URL(string: "https://apps.apple.com/app/id6760410000") { shareApp(url: url) }
                        }
                        divider
                        linkRow("Report a bug", "envelope") {
                            if let url = URL(string: "mailto:fenuku.kekeli8989@gmail.com?subject=Voice%20Journal%20Feedback") {
                                UIApplication.shared.open(url)
                            }
                        }
                        divider
                        row("Version", icon: "app.badge", trailing: appVersion)
                    }

                    // Your data
                    settingsGroup("Your data") {
                        linkRow("Export as Markdown", "doc.text") { exportMarkdown() }
                        divider
                        linkRow("Back up everything", "externaldrive.badge.icloud") { backup() }
                        divider
                        linkRow("Restore from backup", "arrow.down.doc") { showImporter = true }
                    }

                    Text("Back up audio + transcripts to a single file you can save to iCloud Drive or Files. Restore it on any device.")
                        .font(Typo.sans(12))
                        .foregroundColor(Paper.ink3)
                        .padding(.horizontal, 8)
                        .fixedSize(horizontal: false, vertical: true)

                    // Danger
                    Button {
                        HX.warn(); showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete all entries").font(Typo.sans(15, .medium))
                            Spacer()
                        }
                        .foregroundColor(Color(0xB03A2E))
                        .padding(.horizontal, 16).padding(.vertical, 15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .paperCard(18)
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if busy {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView().tint(Paper.terra).padding(20).background(Paper.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if !shareItems.isEmpty { ShareSheet(items: shareItems) }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.zip]) { result in
            if case .success(let url) = result {
                do { try Exporter.restore(from: url, into: store); alertMessage = "Backup restored."; HX.ok() }
                catch { alertMessage = error.localizedDescription; HX.error() }
            }
        }
        .alert("Voice Journal", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: { Text(alertMessage ?? "") }
        .confirmationDialog("Delete all entries?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) { store.deleteAll(); HX.ok() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This permanently removes every recording. It cannot be undone.") }
    }

    // MARK: Data handlers

    private func exportMarkdown() {
        guard !store.entries.isEmpty else { alertMessage = "No entries to export yet."; return }
        HX.tap()
        if let url = try? Exporter.tempFile(Exporter.allMarkdown(store.entries), name: "Voice Journal.md") {
            shareItems = [url]; showShare = true
        }
    }

    private func backup() {
        guard !store.entries.isEmpty else { alertMessage = "No entries to back up yet."; return }
        HX.tap(); busy = true
        let entries = store.entries
        Task.detached {
            let url = try? Exporter.backupZip(entries)
            await MainActor.run {
                busy = false
                if let url { shareItems = [url]; showShare = true }
                else { alertMessage = "Couldn't create the backup." }
            }
        }
    }

    private var modelStatusText: String {
        switch transcription.state {
        case .idle:         return "Ready to load"
        case .preparing:    return "Loading…"
        case .ready:        return "Whisper · loaded"
        case .transcribing: return "Working…"
        case .unavailable:  return "Not installed"
        case .failed:       return "Unavailable"
        }
    }

    // MARK: pieces

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 5) {
            Text(v).font(Typo.sans(22, .bold)).foregroundColor(Paper.ink)
            Text(l).font(Typo.sans(11, .medium)).foregroundColor(Paper.ink3)
        }
        .frame(maxWidth: .infinity)
    }
    private var vline: some View { Rectangle().fill(Paper.hair).frame(width: 1, height: 34) }
    private var divider: some View { Rectangle().fill(Paper.hair).frame(height: 1).padding(.leading, 48) }

    private func settingsGroup<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).eyebrow(Paper.ink3).padding(.leading, 6)
            VStack(spacing: 0) { content() }.paperCard(18)
        }
    }

    private func toggleRow(_ title: String, _ icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label {
                Text(title).font(Typo.sans(15)).foregroundColor(Paper.ink)
            } icon: {
                Image(systemName: icon).foregroundColor(Paper.terra).frame(width: 22)
            }
        }
        .tint(Paper.terra)
        .padding(.horizontal, 16).padding(.vertical, 13)
        .onChange(of: isOn.wrappedValue) { _, v in v ? HX.ok() : HX.tap() }
    }

    private func pickerRow(_ title: String, icon: String, selection: Binding<String>,
                           options: [(String, String)], onChange: @escaping () -> Void) -> some View {
        HStack {
            Label {
                Text(title).font(Typo.sans(15)).foregroundColor(Paper.ink)
            } icon: {
                Image(systemName: icon).foregroundColor(Paper.terra).frame(width: 22)
            }
            Spacer()
            Menu {
                ForEach(options, id: \.0) { opt in
                    Button {
                        selection.wrappedValue = opt.0; HX.tick(); onChange()
                    } label: {
                        if selection.wrappedValue == opt.0 { Label(opt.1, systemImage: "checkmark") }
                        else { Text(opt.1) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(options.first { $0.0 == selection.wrappedValue }?.1 ?? selection.wrappedValue)
                        .font(Typo.sans(14, .medium)).foregroundColor(Paper.terra)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Paper.terra)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func row(_ title: String, icon: String, trailing: String) -> some View {
        HStack {
            Label {
                Text(title).font(Typo.sans(15)).foregroundColor(Paper.ink)
            } icon: {
                Image(systemName: icon).foregroundColor(Paper.terra).frame(width: 22)
            }
            Spacer()
            Text(trailing).font(Typo.sans(14)).foregroundColor(Paper.ink3)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    private func linkRow(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { HX.tap(); action() }) {
            HStack {
                Label {
                    Text(title).font(Typo.sans(15)).foregroundColor(Paper.ink)
                } icon: {
                    Image(systemName: icon).foregroundColor(Paper.terra).frame(width: 22)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Paper.muted)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App-level helpers

func shareApp(url: URL) {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root = scene.windows.first?.rootViewController else { return }
    let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    root.present(vc, animated: true)
}

func requestReview() {
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        SKStoreReviewController.requestReview(in: scene)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    init(items: [Any]) { self.items = items }
    init(url: URL) { self.items = [url] }
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
