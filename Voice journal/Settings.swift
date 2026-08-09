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
    @Published var appLanguage        = "system" { didSet { saveAppLanguage() } } // system | en | es | fr | ...
    @Published var iCloudBackup       = false  { didSet { save() } }  // auto-mirror to iCloud Drive
    /// Flips true when the user enables reminders but notifications are denied — the view
    /// observes it to surface guidance, then resets it.
    @Published var reminderAuthDenied = false

    /// English-only models are faster & more accurate for English; other languages need multilingual.
    var effectiveModelName: String { language == "en" ? "\(modelQuality).en" : modelQuality }

    /// The app-language options offered in Settings.
    /// `native` is the endonym (shown as the primary label); `english` is the
    /// English name shown underneath as a secondary hint.
    static let appLanguageOptions: [(code: String, native: String, english: String)] = [
        ("system",  "System",       "Match device"),
        ("en",      "English",      "English"),
        ("es",      "Español",      "Spanish"),
        ("fr",      "Français",     "French"),
        ("de",      "Deutsch",      "German"),
        ("pt-BR",   "Português",    "Portuguese (Brazil)"),
        ("it",      "Italiano",     "Italian"),
        ("nl",      "Nederlands",   "Dutch"),
        ("ja",      "日本語",         "Japanese"),
        ("ko",      "한국어",         "Korean"),
        ("zh-Hans", "中文",          "Chinese (Simplified)")
    ]

    /// The endonym for the currently selected app language (for the Settings row).
    static func appLanguageNative(_ code: String) -> String {
        appLanguageOptions.first { $0.code == code }?.native ?? code
    }

    private func saveAppLanguage() {
        guard !isLoading else { return }
        let d = UserDefaults.standard
        d.set(appLanguage, forKey: "s_applang")
        if appLanguage == "system" {
            d.removeObject(forKey: "AppleLanguages")
        } else {
            d.set([appLanguage], forKey: "AppleLanguages")
        }
    }

    /// True while `load()` is populating properties, so the `didSet` observers don't
    /// call `save()` and persist half-loaded (default) values over the real ones.
    private var isLoading = false

    init() { load() }

    private func save() {
        guard !isLoading else { return }
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
        d.set(iCloudBackup,       forKey: "s_icloud")
    }
    private func load() {
        isLoading = true
        defer { isLoading = false }
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
        appLanguage        = d.string(forKey: "s_applang") ?? "system"
        liveTranscription  = d.object(forKey: "s_live") as? Bool ?? false
        iCloudBackup       = d.object(forKey: "s_icloud") as? Bool ?? false
        HX.setEnabled(hapticsEnabled)
    }

    func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            // Already denied at the system level: reflect that instead of pretending it's on.
            if settings.authorizationStatus == .denied {
                Task { @MainActor in self.denyReminders() }
                return
            }
            center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
                Task { @MainActor in
                    guard ok else { self.denyReminders(); return }
                    self.addReminderRequest()
                }
            }
        }
    }

    private func addReminderRequest() {
        let c = UNMutableNotificationContent()
        c.title = String(localized: "A moment to reflect", bundle: AppLocale.bundle)
        c.body  = String(localized: "Open your journal and speak today's thoughts.", bundle: AppLocale.bundle)
        c.sound = .default
        var dc = DateComponents(); dc.hour = reminderHour; dc.minute = reminderMinute
        let req = UNNotificationRequest(identifier: "vj_daily", content: c,
            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
        UNUserNotificationCenter.current().add(req)
    }

    /// Turn the toggle back off (so the UI is truthful) and signal the view to guide the user.
    private func denyReminders() {
        if remindersOn { remindersOn = false }
        reminderAuthDenied = true
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

// MARK: - Runtime locale override

/// SwiftUI's `Text(L("literal"))` resolves against the bundle's *launch-time* language
/// and can't be redirected at runtime by the environment locale or a bundle swizzle.
/// So every user-facing string is resolved explicitly against the selected language's
/// `.lproj` via `L(_:)`, and `RootTabView` carries `.id(appLang)` so the tree rebuilds
/// (re-running `L`) the instant the language changes — no relaunch.
enum AppLocale {
    static var code: String { UserDefaults.standard.string(forKey: "s_applang") ?? "system" }

    static var locale: Locale {
        code == "system" ? .autoupdatingCurrent : Locale(identifier: code)
    }

    /// Whether the app is effectively showing English — used to decide whether the
    /// motivation card fetches English ZenQuotes or falls back to the localized pack.
    static var isEnglish: Bool {
        switch code {
        case "en":     return true
        case "system": return (Locale.preferredLanguages.first ?? "en").hasPrefix("en")
        default:       return false
        }
    }

    // Cache the resolved `.lproj` bundle so we don't re-create it on every `L(_:)` call.
    private static var cached: (code: String, bundle: Bundle)?

    /// The `.lproj` bundle for the selected language (or `.main` for "system").
    static var bundle: Bundle {
        let c = code
        if c == "system" { return .main }
        if let cached, cached.code == c { return cached.bundle }
        guard let path = Bundle.main.path(forResource: c, ofType: "lproj"),
              let b = Bundle(path: path) else { return .main }
        cached = (c, b)
        return b
    }
}

/// Resolve a UI string against the currently selected app language. Works for both
/// literal keys and runtime values; falls back to the key itself if untranslated.
func L(_ key: String) -> String {
    AppLocale.bundle.localizedString(forKey: key, value: key, table: nil)
}

// MARK: - Settings screen

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: JournalStore
    @ObservedObject var transcription: TranscriptionManager
    @ObservedObject var cloud: CloudBackupManager
    @ObservedObject var purchases: PurchaseManager
    @Environment(\.presentPaywall) private var presentPaywall
    @State private var showDeleteConfirm = false
    @State private var shareItems: [Any] = []
    @State private var showShare = false
    @State private var showRestoreConfirm = false
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

                    // Membership
                    proCard

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
                                Text(L("Default speed")).font(Typo.sans(15)).foregroundColor(Paper.ink)
                            } icon: {
                                Image(systemName: "gauge.with.dots.needle.50percent").foregroundColor(Paper.terra)
                            }
                            Spacer()
                            Picker("", selection: $settings.playbackSpeed) {
                                Text(L("0.5×")).tag(0.5); Text(L("1×")).tag(1.0)
                                Text(L("1.5×")).tag(1.5); Text(L("2×")).tag(2.0)
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
                                    Text(L("Time")).font(Typo.sans(15)).foregroundColor(Paper.ink)
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

                    // Language
                    settingsGroup("Language") {
                        NavigationLink {
                            LanguageSelectorView(settings: settings)
                        } label: {
                            HStack {
                                Label {
                                    Text(L("App language")).font(Typo.sans(15)).foregroundColor(Paper.ink)
                                } icon: {
                                    Image(systemName: "globe.americas").foregroundColor(Paper.terra).frame(width: 22)
                                }
                                Spacer()
                                Text(AppSettings.appLanguageNative(settings.appLanguage))
                                    .font(Typo.sans(14, .medium)).foregroundColor(Paper.terra)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Paper.ink3)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Text(L("Choose the language the app uses."))
                        .font(Typo.sans(12))
                        .foregroundColor(Paper.ink3)
                        .padding(.horizontal, 8)
                        .fixedSize(horizontal: false, vertical: true)

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

                    // Backup — iCloud is Pro-gated
                    settingsGroup("Backup") {
                        HStack {
                            Label {
                                Text(L("Back up to iCloud")).font(Typo.sans(15)).foregroundColor(Paper.ink)
                            } icon: {
                                Image(systemName: "icloud").foregroundColor(Paper.terra).frame(width: 22)
                            }
                            Spacer()
                            if purchases.isPro {
                                Toggle("", isOn: $settings.iCloudBackup)
                                    .labelsHidden().tint(Paper.terra)
                            } else {
                                Button { presentPaywall() } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                                        Text(L("Pro")).font(Typo.sans(11, .bold))
                                    }
                                    .foregroundColor(Paper.white)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Paper.terra).clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                        if purchases.isPro { cloudStatusRow }
                        divider
                        linkRow("Back up now", "arrow.up.to.line.compact") {
                            purchases.isPro ? cloud.backUpNow() : presentPaywall()
                        }
                        divider
                        linkRow("Restore from iCloud", "arrow.down.to.line.compact") {
                            purchases.isPro ? (showRestoreConfirm = true) : presentPaywall()
                        }
                        divider
                        linkRow("Export as Markdown", "doc.text") { exportMarkdown() }
                    }

                    Text(L("Your entries and audio mirror to your private iCloud Drive, so they survive a lost phone and come back when you sign in on a new one. Nothing is shared with anyone."))
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
                            Text(L("Delete all entries")).font(Typo.sans(15, .medium))
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
        .navigationTitle(L("Settings"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear { cloud.refresh() }
        .onChange(of: settings.iCloudBackup) { _, on in
            if on { cloud.refresh(); cloud.backUpNow() }
        }
        .sheet(isPresented: $showShare) {
            if !shareItems.isEmpty { ShareSheet(items: shareItems) }
        }
        .confirmationDialog(L("Restore from iCloud?"), isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button(L("Restore")) { cloud.restore() }
            Button(L("Cancel"), role: .cancel) {}
        } message: { Text(L("Adds any entries and audio found in your iCloud backup. Your current entries are kept.")) }
        .alert("Voice Journal", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button(L("OK"), role: .cancel) { alertMessage = nil }
        } message: { Text(alertMessage ?? "") }
        .confirmationDialog(L("Delete all entries?"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(L("Delete All"), role: .destructive) { store.deleteAll(); HX.ok() }
            Button(L("Cancel"), role: .cancel) {}
        } message: { Text(L("This permanently removes every recording. It cannot be undone.")) }
        .onChange(of: settings.reminderAuthDenied) { _, denied in
            if denied {
                HX.warn()
                alertMessage = L("Notifications are off for Voice Journal. Turn them on in iOS Settings › Notifications to get your daily reminder.")
                settings.reminderAuthDenied = false
            }
        }


    }

    // MARK: Pro card

    @ViewBuilder
    private var proCard: some View {
        if purchases.isPro {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Paper.terra.opacity(0.14)).frame(width: 44, height: 44)
                    Image(systemName: "sparkles").font(.system(size: 18, weight: .semibold)).foregroundColor(Paper.terra)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Voice Journal Pro")).font(Typo.sans(15, .semibold)).foregroundColor(Paper.ink)
                    Text(purchases.activePlan.map { "\($0) plan · thank you" } ?? "Active · thank you")
                        .font(Typo.sans(12)).foregroundColor(Paper.ink3)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20)).foregroundColor(Paper.terra)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .paperCard(20, fill: Paper.cardAlt)
        } else {
            Button { presentPaywall() } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Paper.terra).frame(width: 44, height: 44)
                        Image(systemName: "sparkles").font(.system(size: 18, weight: .semibold)).foregroundColor(Paper.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("Unlock Voice Journal Pro")).font(Typo.sans(15, .semibold)).foregroundColor(Paper.ink)
                        Text(L("AI summaries, insights, iCloud backup")).font(Typo.sans(12)).foregroundColor(Paper.ink3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(Paper.terra)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .paperCard(20, fill: Paper.cardAlt)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Data handlers

    private func exportMarkdown() {
        guard !store.entries.isEmpty else { alertMessage = "No entries to export yet."; return }
        HX.tap()
        if let url = try? Exporter.tempFile(Exporter.allMarkdown(store.entries), name: "Voice Journal.md") {
            shareItems = [url]; showShare = true
        }
    }

    private var modelStatusText: String {
        switch transcription.state {
        case .idle:         return String(localized: "Ready to load", bundle: AppLocale.bundle)
        case .preparing:    return String(localized: "Loading…", bundle: AppLocale.bundle)
        case .ready:        return String(localized: "Whisper · loaded", bundle: AppLocale.bundle)
        case .transcribing: return String(localized: "Working…", bundle: AppLocale.bundle)
        case .unavailable:  return String(localized: "Not installed", bundle: AppLocale.bundle)
        case .failed:       return String(localized: "Unavailable", bundle: AppLocale.bundle)
        }
    }

    // MARK: pieces

    private var cloudStatusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: cloud.available ? "checkmark.icloud" : "exclamationmark.icloud")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(cloud.available ? Paper.terra : Paper.ink3)
                .frame(width: 22)
            Text(cloud.statusText)
                .font(Typo.sans(12))
                .foregroundColor(Paper.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if cloud.phase == .working {
                ProgressView().scaleEffect(0.7).tint(Paper.terra)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("iCloud status: \(cloud.statusText)")
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 5) {
            Text(v).font(Typo.sans(22, .bold)).foregroundColor(Paper.ink)
            Text(L(l)).font(Typo.sans(11, .medium)).foregroundColor(Paper.ink3)
        }
        .frame(maxWidth: .infinity)
    }
    private var vline: some View { Rectangle().fill(Paper.hair).frame(width: 1, height: 34) }
    private var divider: some View { Rectangle().fill(Paper.hair).frame(height: 1).padding(.leading, 48) }

    private func settingsGroup<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(title)).eyebrow(Paper.ink3).padding(.leading, 6)
            VStack(spacing: 0) { content() }.paperCard(18)
        }
    }

    private func toggleRow(_ title: String, _ icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label {
                Text(L(title)).font(Typo.sans(15)).foregroundColor(Paper.ink)
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
                Text(L(title)).font(Typo.sans(15)).foregroundColor(Paper.ink)
            } icon: {
                Image(systemName: icon).foregroundColor(Paper.terra).frame(width: 22)
            }
            Spacer()
            Menu {
                ForEach(options, id: \.0) { opt in
                    Button {
                        selection.wrappedValue = opt.0; HX.tick(); onChange()
                    } label: {
                        if selection.wrappedValue == opt.0 { Label(L(opt.1), systemImage: "checkmark") }
                        else { Text(L(opt.1)) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(L(options.first { $0.0 == selection.wrappedValue }?.1 ?? selection.wrappedValue))
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
                Text(L(title)).font(Typo.sans(15)).foregroundColor(Paper.ink)
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
                    Text(L(title)).font(Typo.sans(15)).foregroundColor(Paper.ink)
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

// MARK: - Language selector (pushed list, applies instantly)

/// A full-screen list of app languages. Tapping a row sets `settings.appLanguage`,
/// which switches the whole UI instantly via the `.environment(\.locale, …)` on the
/// root view — no relaunch. The selected row shows a terracotta checkmark.
struct LanguageSelectorView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    private var options: [(code: String, native: String, english: String)] {
        AppSettings.appLanguageOptions
    }

    var body: some View {
        ZStack {
            Paper.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // "System" sits on its own, like the device Settings pattern.
                    VStack(spacing: 0) {
                        if let sys = options.first(where: { $0.code == "system" }) {
                            row(sys)
                        }
                    }
                    .paperCard(18)

                    VStack(spacing: 0) {
                        let langs = options.filter { $0.code != "system" }
                        ForEach(Array(langs.enumerated()), id: \.element.code) { i, opt in
                            row(opt)
                            if i < langs.count - 1 {
                                Rectangle().fill(Paper.hair).frame(height: 1).padding(.leading, 16)
                            }
                        }
                    }
                    .paperCard(18)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(L("App language"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Secondary label: the language's name in the *current* UI language (iOS-native
    /// pattern — endonym on top, your-language name beneath). "System" uses its own hint.
    private func secondary(_ opt: (code: String, native: String, english: String)) -> String {
        if opt.code == "system" { return L(opt.english) }
        let uiLoc = AppLocale.code == "system" ? Locale.autoupdatingCurrent : Locale(identifier: AppLocale.code)
        return uiLoc.localizedString(forIdentifier: opt.code) ?? opt.english
    }

    private func row(_ opt: (code: String, native: String, english: String)) -> some View {
        let selected = settings.appLanguage == opt.code
        return Button {
            guard settings.appLanguage != opt.code else { dismiss(); return }
            settings.appLanguage = opt.code
            HX.tick()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(opt.native))
                        .font(Typo.sans(16, selected ? .semibold : .regular))
                        .foregroundColor(Paper.ink)
                    Text(secondary(opt))
                        .font(Typo.sans(12))
                        .foregroundColor(Paper.ink3)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Paper.terra)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L(opt.native)))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
