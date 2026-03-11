import StoreKit
import SwiftUI
import AVFoundation
import UserNotifications
import Combine
// MARK: - Theme

enum AppTheme: String, CaseIterable, Codable {
    case obsidian, midnight, forest, rose, slate, dusk, arctic, ember

    var name: String {
        switch self {
        case .obsidian: return "Obsidian"
        case .midnight: return "Midnight"
        case .forest:   return "Forest"
        case .rose:     return "Rose"
        case .slate:    return "Slate"
        case .dusk:     return "Dusk"
        case .arctic:   return "Arctic"
        case .ember:    return "Ember"
        }
    }

    var icon: String {
        switch self {
        case .obsidian: return "moon.stars.fill"
        case .midnight: return "sparkles"
        case .forest:   return "leaf.fill"
        case .rose:     return "heart.fill"
        case .slate:    return "cloud.fill"
        case .dusk:     return "sunset.fill"
        case .arctic:   return "snowflake"
        case .ember:    return "flame.fill"
        }
    }

    var bg: Color {
        switch self {
        case .obsidian: return Color(red:0.06,green:0.06,blue:0.08)
        case .midnight: return Color(red:0.04,green:0.05,blue:0.13)
        case .forest:   return Color(red:0.04,green:0.09,blue:0.06)
        case .rose:     return Color(red:0.11,green:0.05,blue:0.07)
        case .slate:    return Color(red:0.07,green:0.08,blue:0.11)
        case .dusk:     return Color(red:0.10,green:0.06,blue:0.12)
        case .arctic:   return Color(red:0.04,green:0.08,blue:0.13)
        case .ember:    return Color(red:0.10,green:0.05,blue:0.03)
        }
    }
    var surface: Color {
        switch self {
        case .obsidian: return Color(red:0.10,green:0.10,blue:0.13)
        case .midnight: return Color(red:0.08,green:0.10,blue:0.20)
        case .forest:   return Color(red:0.07,green:0.13,blue:0.09)
        case .rose:     return Color(red:0.16,green:0.08,blue:0.10)
        case .slate:    return Color(red:0.11,green:0.13,blue:0.16)
        case .dusk:     return Color(red:0.15,green:0.09,blue:0.18)
        case .arctic:   return Color(red:0.07,green:0.12,blue:0.20)
        case .ember:    return Color(red:0.15,green:0.08,blue:0.04)
        }
    }
    var surfaceMid: Color {
        switch self {
        case .obsidian: return Color(red:0.14,green:0.14,blue:0.18)
        case .midnight: return Color(red:0.12,green:0.15,blue:0.27)
        case .forest:   return Color(red:0.10,green:0.17,blue:0.12)
        case .rose:     return Color(red:0.21,green:0.11,blue:0.14)
        case .slate:    return Color(red:0.15,green:0.17,blue:0.21)
        case .dusk:     return Color(red:0.20,green:0.12,blue:0.24)
        case .arctic:   return Color(red:0.10,green:0.17,blue:0.27)
        case .ember:    return Color(red:0.21,green:0.11,blue:0.06)
        }
    }
    var accent: Color {
        switch self {
        case .obsidian: return Color(red:0.95,green:0.78,blue:0.46)
        case .midnight: return Color(red:0.50,green:0.75,blue:1.00)
        case .forest:   return Color(red:0.38,green:0.90,blue:0.58)
        case .rose:     return Color(red:1.00,green:0.55,blue:0.65)
        case .slate:    return Color(red:0.65,green:0.60,blue:1.00)
        case .dusk:     return Color(red:0.95,green:0.60,blue:0.85)
        case .arctic:   return Color(red:0.40,green:0.88,blue:0.95)
        case .ember:    return Color(red:1.00,green:0.55,blue:0.25)
        }
    }
    // Gradient pair for the preview swatch
    var gradientColors: [Color] {
        switch self {
        case .obsidian: return [Color(red:0.18,green:0.16,blue:0.22), Color(red:0.06,green:0.06,blue:0.08)]
        case .midnight: return [Color(red:0.10,green:0.12,blue:0.35), Color(red:0.04,green:0.05,blue:0.13)]
        case .forest:   return [Color(red:0.08,green:0.20,blue:0.12), Color(red:0.04,green:0.09,blue:0.06)]
        case .rose:     return [Color(red:0.26,green:0.10,blue:0.14), Color(red:0.11,green:0.05,blue:0.07)]
        case .slate:    return [Color(red:0.17,green:0.19,blue:0.25), Color(red:0.07,green:0.08,blue:0.11)]
        case .dusk:     return [Color(red:0.28,green:0.12,blue:0.30), Color(red:0.10,green:0.06,blue:0.12)]
        case .arctic:   return [Color(red:0.08,green:0.20,blue:0.35), Color(red:0.04,green:0.08,blue:0.13)]
        case .ember:    return [Color(red:0.30,green:0.12,blue:0.05), Color(red:0.10,green:0.05,blue:0.03)]
        }
    }

    var border:    Color { Color.white.opacity(0.07) }
    var mist:      Color { Color.white.opacity(0.55) }
    var fog:       Color { Color.white.opacity(0.28) }
    var crimson:   Color { Color(red:0.95,green:0.25,blue:0.35) }
    var heartPink: Color { Color(red:0.95,green:0.35,blue:0.55) }
}

// MARK: - Theme Picker View

struct ThemePickerView: View {
    @ObservedObject var settings: AppSettings

    let columns = [GridItem(.flexible(), spacing:12), GridItem(.flexible(), spacing:12)]

    var body: some View {
        let theme = settings.theme
        ZStack {
            // Background transitions with selected theme
            theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators:false) {
                VStack(spacing:24) {
                    // Live preview of selected theme
                    ThemeLivePreview(theme:theme)
                        .padding(.horizontal,16)
                        .padding(.top,8)

                    // Grid of theme cards
                    LazyVGrid(columns:columns, spacing:12) {
                        ForEach(AppTheme.allCases, id:\.self) { t in
                            ThemeCard(t:t, selected:settings.theme == t) {
                                withAnimation(.spring(response:0.4, dampingFraction:0.75)) {
                                    settings.theme = t
                                }
                                HX.tick()
                            }
                        }
                    }
                    .padding(.horizontal,16)

                    Spacer().frame(height:32)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.large)
        .animation(.easeInOut(duration:0.35), value:settings.theme)
    }
}

// Live preview panel showing how the selected theme looks
struct ThemeLivePreview: View {
    let theme: AppTheme

    var waveHeights: [CGFloat] { [0.3,0.55,0.8,1.0,0.7,0.45,0.9,0.6,0.4,0.75,0.5,0.85,0.35,0.65] }

    var body: some View {
        VStack(spacing:0) {
            // Mock navigation bar
            HStack {
                VStack(alignment:.leading, spacing:2) {
                    Text("Good evening")
                        .font(.system(size:10, weight:.medium)).kerning(0.5)
                        .foregroundColor(theme.fog)
                    Text("Journal")
                        .font(.system(size:18, weight:.light))
                        .foregroundColor(.white)
                }
                Spacer()
                Circle()
                    .fill(theme.surfaceMid)
                    .frame(width:28,height:28)
                    .overlay(Image(systemName:theme.icon)
                        .font(.system(size:11))
                        .foregroundColor(theme.accent))
            }
            .padding(.horizontal,16).padding(.top,14).padding(.bottom,10)
            .background(theme.surface)

            // Waveform section
            ZStack {
                theme.bg

                VStack(spacing:14) {
                    // Waveform bars
                    HStack(alignment:.center, spacing:3) {
                        ForEach(Array(waveHeights.enumerated()), id:\.offset) { _, h in
                            Capsule()
                                .fill(theme.accent.opacity(0.25 + Double(h) * 0.55))
                                .frame(width:5, height:36 * h)
                        }
                    }
                    .frame(maxWidth:.infinity)
                    .padding(.horizontal,20)

                    // Record button mock
                    ZStack {
                        Circle()
                            .fill(theme.crimson)
                            .frame(width:44,height:44)
                        RoundedRectangle(cornerRadius:3)
                            .fill(Color.white)
                            .frame(width:14,height:14)
                    }

                    // Mini stats row
                    HStack(spacing:16) {
                        ForEach(["12 entries","3h 40m","4🔥"], id:\.self) { s in
                            Text(s)
                                .font(.system(size:10,weight:.medium))
                                .foregroundColor(theme.fog)
                        }
                    }
                }
                .padding(.vertical,16)
            }
            .frame(height:140)
        }
        .clipShape(RoundedRectangle(cornerRadius:20))
        .overlay(RoundedRectangle(cornerRadius:20).stroke(theme.border.opacity(2), lineWidth:1))
    }
}

struct ThemeCard: View {
    let t: AppTheme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action:action) {
            ZStack(alignment:.bottom) {
                // Card background
                RoundedRectangle(cornerRadius:16)
                    .fill(LinearGradient(
                        colors:t.gradientColors,
                        startPoint:.topLeading,
                        endPoint:.bottomTrailing))

                // Mini waveform
                HStack(alignment:.center, spacing:2) {
                    ForEach(Array([0.4,0.7,1.0,0.6,0.85,0.5,0.9,0.45].enumerated()), id:\.offset) { _, h in
                        Capsule()
                            .fill(t.accent.opacity(0.45 + Double(h) * 0.35))
                            .frame(width:3, height:22 * CGFloat(h))
                    }
                }
                .frame(maxWidth:.infinity)
                .padding(.horizontal,14)
                .padding(.bottom,38)

                // Label bar
                HStack(spacing:6) {
                    Image(systemName:t.icon)
                        .font(.system(size:10, weight:.bold))
                        .foregroundColor(t.accent)
                    Text(t.name)
                        .font(.system(size:12, weight:.semibold))
                        .foregroundColor(.white)
                    Spacer()
                    if selected {
                        Image(systemName:"checkmark.circle.fill")
                            .font(.system(size:15))
                            .foregroundColor(t.accent)
                            .transition(.scale.combined(with:.opacity))
                    }
                }
                .padding(.horizontal,12)
                .padding(.vertical,9)
                .background(.ultraThinMaterial)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius:0, bottomLeadingRadius:16,
                    bottomTrailingRadius:16, topTrailingRadius:0))
            }
            .frame(height:110)
            .clipShape(RoundedRectangle(cornerRadius:16))
            .overlay(
                RoundedRectangle(cornerRadius:16)
                    .stroke(
                        selected ? t.accent : Color.white.opacity(0.07),
                        lineWidth: selected ? 2 : 1
                    )
            )
            .scaleEffect(selected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response:0.3, dampingFraction:0.65), value:selected)
    }
}

// MARK: - Settings

class AppSettings: ObservableObject {
    @Published var theme: AppTheme       = .obsidian { didSet { save() } }
    @Published var remindersOn           = false     { didSet { save(); remindersOn ? scheduleReminder() : cancelReminders() } }
    @Published var reminderHour: Int     = 20        { didSet { save() } }
    @Published var reminderMinute: Int   = 0         { didSet { save() } }
    @Published var calendarView          = false     { didSet { save() } }
    @Published var playbackSpeed: Double = 1.0       { didSet { save() } }
    @Published var sortNewestFirst       = true      { didSet { save() } }
    @Published var hapticsEnabled        = true      { didSet { save(); HX.setEnabled(hapticsEnabled) } }

    init() { load() }

    private func save() {
        UserDefaults.standard.set(theme.rawValue, forKey:"s_theme")
        UserDefaults.standard.set(remindersOn,    forKey:"s_rem")
        UserDefaults.standard.set(reminderHour,   forKey:"s_remH")
        UserDefaults.standard.set(reminderMinute, forKey:"s_remM")
        UserDefaults.standard.set(calendarView,   forKey:"s_cal")
        UserDefaults.standard.set(playbackSpeed,  forKey:"s_speed")
        UserDefaults.standard.set(sortNewestFirst,forKey:"s_sort")
        UserDefaults.standard.set(hapticsEnabled, forKey:"s_haptics")
    }
    private func load() {
        if let t = UserDefaults.standard.string(forKey:"s_theme"), let p = AppTheme(rawValue:t) { theme = p }
        remindersOn    = UserDefaults.standard.bool(forKey:"s_rem")
        reminderHour   = UserDefaults.standard.object(forKey:"s_remH")  as? Int    ?? 20
        reminderMinute = UserDefaults.standard.object(forKey:"s_remM")  as? Int    ?? 0
        calendarView   = UserDefaults.standard.object(forKey:"s_cal")   as? Bool   ?? false
        playbackSpeed  = UserDefaults.standard.object(forKey:"s_speed") as? Double ?? 1.0
        sortNewestFirst = UserDefaults.standard.object(forKey:"s_sort") as? Bool   ?? true
        hapticsEnabled  = UserDefaults.standard.object(forKey:"s_haptics") as? Bool ?? true
        HX.setEnabled(hapticsEnabled)
    }
    func scheduleReminder() {
        UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound]) { ok,_ in
            guard ok else { return }
            let c = UNMutableNotificationContent()
            c.title = "Time to reflect"
            c.body  = "Open your voice journal and capture today's thoughts."
            c.sound = .default
            var dc = DateComponents(); dc.hour = self.reminderHour; dc.minute = self.reminderMinute
            let req = UNNotificationRequest(identifier:"vj_daily",
                content:c, trigger:UNCalendarNotificationTrigger(dateMatching:dc,repeats:true))
            UNUserNotificationCenter.current().add(req)
        }
    }
    func cancelReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:["vj_daily"])
    }
    var reminderDate: Date {
        get { Calendar.current.date(bySettingHour:reminderHour, minute:reminderMinute, second:0, of:Date())! }
        set {
            reminderHour   = Calendar.current.component(.hour,   from:newValue)
            reminderMinute = Calendar.current.component(.minute, from:newValue)
            if remindersOn { scheduleReminder() }
        }
    }
}

// MARK: - Haptics

final class HX {
    static var enabled: Bool = UserDefaults.standard.object(forKey:"hx_enabled") as? Bool ?? true

    static func setEnabled(_ v: Bool) {
        enabled = v
        UserDefaults.standard.set(v, forKey:"hx_enabled")
    }

    static func tap()   { guard enabled else { return }; UIImpactFeedbackGenerator(style:.light).impactOccurred() }
    static func press() { guard enabled else { return }; UIImpactFeedbackGenerator(style:.medium).impactOccurred() }
    static func heavy() { guard enabled else { return }; UIImpactFeedbackGenerator(style:.heavy).impactOccurred() }
    static func rigid() { guard enabled else { return }; UIImpactFeedbackGenerator(style:.rigid).impactOccurred() }
    static func soft()  { guard enabled else { return }; UIImpactFeedbackGenerator(style:.soft).impactOccurred() }
    static func ok()    { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warn()  { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tick()  { guard enabled else { return }; UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Model

struct VoiceEntry: Identifiable, Codable, Equatable {
    var id          = UUID()
    var date        = Date()
    var duration:   TimeInterval
    var fileName:   String
    var title:      String
    var mood:       Mood   = .none
    var isFavorite         = false
    var colorTag:   Tag    = .none
    var note:       String = ""

    enum Mood: String, Codable, CaseIterable {
        case none, serene, joyful, pensive, tense, grateful, raw
        var glyph: String {
            switch self {
            case .none:     return "○"
            case .serene:   return "◌"
            case .joyful:   return "☀"
            case .pensive:  return "◑"
            case .tense:    return "◈"
            case .grateful: return "◇"
            case .raw:      return "◉"
            }
        }
        var label: String { rawValue.capitalized }
        var color: Color {
            switch self {
            case .none:     return Color.white.opacity(0.28)
            case .serene:   return Color(red:0.4, green:0.8, blue:0.9)
            case .joyful:   return Color(red:0.95,green:0.78,blue:0.46)
            case .pensive:  return Color(red:0.6, green:0.5, blue:0.9)
            case .tense:    return Color(red:0.95,green:0.25,blue:0.35)
            case .grateful: return Color(red:0.4, green:0.85,blue:0.65)
            case .raw:      return Color(red:0.95,green:0.55,blue:0.3)
            }
        }
    }

    enum Tag: String, Codable, CaseIterable {
        case none, amber, rose, teal, violet
        var color: Color {
            switch self {
            case .none:   return .clear
            case .amber:  return Color(red:0.95,green:0.78,blue:0.46)
            case .rose:   return Color(red:0.95,green:0.25,blue:0.35)
            case .teal:   return Color(red:0.2, green:0.75,blue:0.7)
            case .violet: return Color(red:0.55,green:0.4, blue:0.9)
            }
        }
    }

    init(duration:TimeInterval, fileName:String, title:String="",
         mood:Mood = .none, colorTag:Tag = .none, note:String="") {
        self.duration  = duration
        self.fileName  = fileName
        self.mood      = mood
        self.colorTag  = colorTag
        self.note      = note
        self.title     = title.isEmpty ? Self.smartTitle() : title
    }

    static func smartTitle() -> String {
        let h = Calendar.current.component(.hour, from:Date())
        let pool: [(Range<Int>,[String])] = [
            (5..<9,  ["First light","Dawn thought","Morning pages"]),
            (9..<12, ["Morning note","Before noon","AM reflection"]),
            (12..<14,["At midday","Lunch hour","Noon entry"]),
            (14..<17,["Afternoon drift","Mid-afternoon","Golden hour"]),
            (17..<20,["Evening entry","Winding down","Dusk"]),
            (20..<24,["Night journal","Late evening","Before sleep"]),
            (0..<5,  ["Can't sleep","3am thought","Night owl"])
        ]
        for (r,opts) in pool { if r.contains(h) { return opts.randomElement()! } }
        return "Untitled"
    }

    var durationFormatted: String {
        let m = Int(duration)/60, s = Int(duration)%60
        return m > 0 ? String(format:"%d′%02d″",m,s) : String(format:"%d″",s)
    }
    var timeLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return date.formatted(.dateTime.hour().minute()) }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let d = cal.dateComponents([.day],from:date,to:.now).day ?? 0
        if d < 7 { return date.formatted(.dateTime.weekday(.wide)) }
        return date.formatted(.dateTime.month().day())
    }
    var dayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from:date)
    }
}

// MARK: - Store

class JournalStore: ObservableObject {
    @Published var entries: [VoiceEntry] = []
    @Published var searchQuery = ""
    @Published var favOnly     = false
    @Published var moodFilter: VoiceEntry.Mood? = nil

    private let key = "vj_v5"

    func filtered(newestFirst: Bool) -> [VoiceEntry] {
        let base = entries.filter {
            (searchQuery.isEmpty
                || $0.title.localizedCaseInsensitiveContains(searchQuery)
                || $0.note.localizedCaseInsensitiveContains(searchQuery))
            && (!favOnly || $0.isFavorite)
            && (moodFilter == nil || $0.mood == moodFilter)
        }
        return newestFirst ? base.sorted { $0.date > $1.date } : base.sorted { $0.date < $1.date }
    }

    func groupedByDay(newestFirst: Bool) -> [(key:String, date:Date, entries:[VoiceEntry])] {
        let sorted = filtered(newestFirst: newestFirst)
        let g = Dictionary(grouping:sorted) { $0.dayKey }
        let keys = newestFirst ? g.keys.sorted(by:>) : g.keys.sorted(by:<)
        return keys.compactMap { k in
            guard let first = g[k]?.first else { return nil }
            let dayEntries = g[k]!.sorted { newestFirst ? $0.date > $1.date : $0.date < $1.date }
            return (key:k, date:first.date, entries:dayEntries)
        }
    }

    var totalSeconds: TimeInterval { entries.reduce(0) { $0 + $1.duration } }
    var totalMinutes: Int { Int(totalSeconds) / 60 }

    var totalFormatted: String {
        let mins = totalMinutes
        if mins < 60 { return "\(mins)m" }
        return "\(mins/60)h \(mins%60)m"
    }

    var streak: Int {
        var n = 0, d = Date()
        let cal = Calendar.current
        for _ in 0..<365 {
            if entries.contains(where: { cal.isDate($0.date,inSameDayAs:d) }) { n += 1 }
            else { break }
            d = cal.date(byAdding:.day, value:-1, to:d)!
        }
        return n
    }
    var daysWithEntries: Set<String> { Set(entries.map { $0.dayKey }) }

    init() { load() }

    func add(_ e: VoiceEntry) {
        withAnimation(.spring(response:0.4,dampingFraction:0.8)) { entries.insert(e,at:0) }
        save()
    }
    func remove(_ e: VoiceEntry) {
        try? FileManager.default.removeItem(at:docURL(e.fileName))
        withAnimation(.easeOut(duration:0.25)) { entries.removeAll { $0.id == e.id } }
        save()
    }
    func update(_ e: VoiceEntry) {
        if let i = entries.firstIndex(where: { $0.id == e.id }) { entries[i] = e; save() }
    }
    func docURL(_ n: String) -> URL {
        FileManager.default.urls(for:.documentDirectory, in:.userDomainMask)[0].appendingPathComponent(n)
    }
    private func save() {
        if let d = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(d,forKey:key) }
    }
    private func load() {
        guard let d = UserDefaults.standard.data(forKey:key),
              let v = try? JSONDecoder().decode([VoiceEntry].self, from:d) else { return }
        entries = v
    }
}

// MARK: - Audio Engine

class AudioEngine: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    enum State { case idle, recording, paused, playing }

    @Published var state: State            = .idle
    @Published var elapsed: TimeInterval   = 0
    @Published var bars: [CGFloat]         = Array(repeating:0.04, count:60)
    @Published var playProgress: Double    = 0
    @Published var playingID: UUID?
    @Published var playSpeed: Float        = 1.0
    @Published var playTime: TimeInterval  = 0
    @Published var playDuration: TimeInterval = 0

    private var recorder:    AVAudioRecorder?
    private var player:      AVAudioPlayer?
    private var recClock:    Timer?
    private var meterTimer:  Timer?
    private var playTimer:   Timer?
    private var recStart:    Date?
    private var pausedAt:    TimeInterval = 0
    private var pendingFile: String?
    var onRecordFinish: ((String, TimeInterval) -> Void)?

    // MARK: Recording
    func requestAndRecord() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] ok in
            DispatchQueue.main.async { if ok { self?.startRecording() } }
        }
    }
    private func startRecording() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode:.default, options:[.defaultToSpeaker])
        try? s.setActive(true)
        let name = "vj_\(UUID().uuidString).m4a"; pendingFile = name
        let cfg: [String:Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        recorder = try? AVAudioRecorder(url:docURL(name), settings:cfg)
        recorder?.delegate = self; recorder?.isMeteringEnabled = true; recorder?.record()
        recStart = Date(); elapsed = 0; state = .recording
        recClock = Timer.scheduledTimer(withTimeInterval:0.05, repeats:true) { [weak self] _ in
            guard let self = self, let t = self.recStart else { return }
            self.elapsed = self.pausedAt + Date().timeIntervalSince(t)
        }
        meterTimer = Timer.scheduledTimer(withTimeInterval:0.06, repeats:true) { [weak self] _ in
            self?.sampleMeter()
        }
    }
    func pauseRecording() {
        recorder?.pause()
        pausedAt += Date().timeIntervalSince(recStart ?? Date())
        recClock?.invalidate(); meterTimer?.invalidate()
        state = .paused
    }
    func resumeRecording() {
        recorder?.record(); recStart = Date(); state = .recording
        recClock = Timer.scheduledTimer(withTimeInterval:0.05, repeats:true) { [weak self] _ in
            guard let self = self, let t = self.recStart else { return }
            self.elapsed = self.pausedAt + Date().timeIntervalSince(t)
        }
        meterTimer = Timer.scheduledTimer(withTimeInterval:0.06, repeats:true) { [weak self] _ in
            self?.sampleMeter()
        }
    }
    func stopRecording() {
        recorder?.stop(); recClock?.invalidate(); meterTimer?.invalidate()
        let dur = elapsed
        state = .idle; elapsed = 0; pausedAt = 0
        bars = Array(repeating:0.04, count:60)
        if let f = pendingFile { onRecordFinish?(f, dur) }
    }
    private func sampleMeter() {
        recorder?.updateMeters()
        let p = recorder?.averagePower(forChannel:0) ?? -80
        let n = CGFloat(max(0, (p + 70) / 70))
        bars.removeFirst(); bars.append(max(0.04, n * 0.96))
    }

    // MARK: Playback
    func play(entry: VoiceEntry, speed: Float? = nil) {
        player?.stop(); playTimer?.invalidate()
        let url = docURL(entry.fileName)
        guard let p = try? AVAudioPlayer(contentsOf:url) else { return }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback); try? s.setActive(true)
        let spd = speed ?? playSpeed
        player = p; player?.delegate = self; player?.enableRate = true; player?.rate = spd
        player?.play()
        state = .playing; playingID = entry.id
        playDuration = p.duration; playSpeed = spd; playProgress = 0; playTime = 0
        playTimer = Timer.scheduledTimer(withTimeInterval:0.04, repeats:true) { [weak self] _ in
            guard let self = self, let pl = self.player else { return }
            self.playTime = pl.currentTime
            self.playProgress = pl.duration > 0 ? pl.currentTime / pl.duration : 0
        }
    }
    func seek(to fraction: Double) {
        guard let p = player else { return }
        p.currentTime = p.duration * fraction
        playTime = p.currentTime; playProgress = fraction
    }
    func skip(seconds: Double) {
        guard let p = player else { return }
        let t = min(max(0, p.currentTime + seconds), p.duration)
        p.currentTime = t; playTime = t
        playProgress = p.duration > 0 ? t / p.duration : 0
    }
    func setSpeed(_ s: Float) { playSpeed = s; player?.rate = s }
    func stopPlaying() {
        player?.stop(); playTimer?.invalidate()
        state = .idle; playingID = nil; playProgress = 0; playTime = 0
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.stopPlaying() }
    }
    private func docURL(_ n: String) -> URL {
        FileManager.default.urls(for:.documentDirectory, in:.userDomainMask)[0].appendingPathComponent(n)
    }
    func elapsedFormatted() -> String { fmt(elapsed) }
    func fmt(_ t: TimeInterval) -> String { String(format:"%d:%02d", Int(t)/60, Int(t)%60) }

    // Cycle through speeds: 1x → 1.5x → 2x → 0.5x → 1x
    func cycleSpeed() {
        let speeds: [Float] = [1.0, 1.5, 2.0, 0.5]
        let current = speeds.firstIndex(of: playSpeed) ?? 0
        setSpeed(speeds[(current + 1) % speeds.count])
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var selectedTab: Int = 0
}

// MARK: ── COMPONENTS ─────────────────────────────────────────────



struct WaveVisualiser: View {
    let bars: [CGFloat]; let isRecording: Bool; let theme: AppTheme
    var body: some View {
        GeometryReader { g in
            let count = bars.count
            let bw = (g.size.width / CGFloat(count)) * 0.50
            let sp = count > 1 ? (g.size.width - bw * CGFloat(count)) / CGFloat(count - 1) : 0
            let halfH = g.size.height / 2
            ZStack {
                // Top half — main bars growing upward
                HStack(alignment:.bottom, spacing:sp) {
                    ForEach(Array(bars.enumerated()), id:\.offset) { _, h in
                        Capsule()
                            .fill(isRecording
                                ? theme.crimson.opacity(0.45 + Double(h) * 0.55)
                                : theme.accent.opacity(0.28 + Double(h) * 0.52))
                            .frame(width:bw, height:max(4, h * halfH * 0.92))
                            .animation(.easeOut(duration:0.07), value:h)
                    }
                }
                .frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.bottom)
                .frame(height:halfH)
                .frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.bottom)

                // Bottom half — mirrored reflection
                HStack(alignment:.top, spacing:sp) {
                    ForEach(Array(bars.enumerated()), id:\.offset) { _, h in
                        Capsule()
                            .fill(isRecording
                                ? theme.crimson.opacity(0.10 + Double(h) * 0.14)
                                : theme.accent.opacity(0.07 + Double(h) * 0.11))
                            .frame(width:bw, height:max(2, h * halfH * 0.4))
                            .animation(.easeOut(duration:0.07), value:h)
                    }
                }
                .frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.top)
                .frame(height:halfH)
                .frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.top)
            }
        }
    }
}

struct RecordBtn: View {
    let state: AudioEngine.State; let theme: AppTheme; let action: () -> Void
    @State private var pressed = false
    var isRecording: Bool { state == .recording }
    var isPaused:    Bool { state == .paused }

    var body: some View {
        Button(action:action) {
            ZStack {

                // Main button circle
                Circle()
                    .fill(isRecording
                        ? AnyShapeStyle(theme.crimson)
                        : isPaused
                            ? AnyShapeStyle(theme.accent)
                            : AnyShapeStyle(LinearGradient(
                                colors:[theme.surfaceMid.opacity(1.4), theme.surface],
                                startPoint:.topLeading, endPoint:.bottomTrailing)))
                    .frame(width:88, height:88)
                    .overlay(
                        Circle().stroke(
                            isRecording ? theme.crimson.opacity(0.6)
                                : isPaused ? theme.accent.opacity(0.4)
                                : theme.border,
                            lineWidth:1)
                    )
                    .scaleEffect(pressed ? 0.91 : 1.0)

                // Icon
                Group {
                    if isRecording {
                        RoundedRectangle(cornerRadius:6)
                            .fill(Color.white)
                            .frame(width:26, height:26)
                    } else {
                        Image(systemName: isPaused ? "stop.fill" : "mic.fill")
                            .font(.system(size:isPaused ? 20 : 28, weight:.medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .scaleEffect(pressed ? 0.88 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance:0)
            .onChanged { _ in if !pressed { pressed = true; HX.rigid() } }
            .onEnded   { _ in pressed = false })
        .animation(.spring(response:0.22, dampingFraction:0.55), value:pressed)
        .animation(.easeInOut(duration:0.3), value:state)
    }
}

// MARK: - Mini Player Bar (persists at bottom of History)

struct MiniPlayerBar: View {
    @ObservedObject var engine: AudioEngine
    let entry: VoiceEntry
    let theme: AppTheme

    var body: some View {
        VStack(spacing:0) {
            // Scrubbable progress strip
            GeometryReader { g in
                ZStack(alignment:.leading) {
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height:3)
                    Rectangle().fill(theme.accent)
                        .frame(width:max(0, g.size.width * engine.playProgress), height:3)
                        .animation(.linear(duration:0.04), value:engine.playProgress)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance:0)
                    .onChanged { _ in HX.soft() }
                    .onEnded { v in
                        engine.seek(to:min(max(0, v.location.x / g.size.width), 1))
                        HX.rigid()
                    })
            }
            .frame(height:3)

            HStack(spacing:14) {
                // Entry title + time
                VStack(alignment:.leading, spacing:2) {
                    Text(entry.title)
                        .font(.system(size:13,weight:.medium)).foregroundColor(.white).lineLimit(1)
                    Text(engine.fmt(engine.playTime) + " / " + engine.fmt(engine.playDuration))
                        .font(.system(size:10,design:.monospaced)).foregroundColor(theme.fog)
                }
                .frame(maxWidth:.infinity, alignment:.leading)

                Button { HX.tap(); engine.skip(seconds:-15) } label: {
                    Image(systemName:"gobackward.15").font(.system(size:18)).foregroundColor(theme.mist)
                }.buttonStyle(.plain)

                Button {
                    HX.press()
                    if engine.state == .playing { engine.stopPlaying() }
                    else { engine.play(entry:entry) }
                } label: {
                    Image(systemName:engine.state == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size:22)).foregroundColor(theme.accent)
                }.buttonStyle(.plain)

                Button { HX.tap(); engine.skip(seconds:15) } label: {
                    Image(systemName:"goforward.15").font(.system(size:18)).foregroundColor(theme.mist)
                }.buttonStyle(.plain)

                // Speed cycle button — fix: use cycleSpeed()
                Button { HX.tick(); engine.cycleSpeed() } label: {
                    Text(engine.playSpeed == 1.0 ? "1×"
                       : engine.playSpeed == 0.5 ? "½×"
                       : engine.playSpeed == 1.5 ? "1.5×" : "2×")
                        .font(.system(size:11,weight:.semibold,design:.monospaced))
                        .foregroundColor(theme.accent)
                        .frame(width:34)
                }.buttonStyle(.plain)

                Button { HX.tap(); engine.stopPlaying() } label: {
                    Image(systemName:"xmark").font(.system(size:13)).foregroundColor(theme.fog)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal,16)
            .padding(.top,10)
            .padding(.bottom,10)
        }
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(theme.border).frame(height:1), alignment:.top)
        .padding(.bottom, 0) // safeAreaInset handles safe area automatically
    }
}

// MARK: - Entry Detail View

struct EntryDetailView: View {
    @State var entry: VoiceEntry
    @ObservedObject var store:    JournalStore
    @ObservedObject var engine:   AudioEngine
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    @State private var editingTitle = false
    @State private var titleDraft   = ""
    @State private var editingNote  = false
    @State private var noteDraft    = ""
    @State private var showMood     = false
    @State private var showTag      = false
    @State private var showShare    = false
    @State private var shareURL: URL? = nil
    @FocusState private var titleFocused: Bool

    var theme: AppTheme { settings.theme }
    var isPlaying: Bool { engine.playingID == entry.id }
    // Only show this entry's progress if it's actually playing
    var displayProgress: Double { isPlaying ? engine.playProgress : 0 }
    var displayTime: TimeInterval { isPlaying ? engine.playTime : 0 }
    var displayDuration: TimeInterval { isPlaying ? engine.playDuration : entry.duration }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment:.leading, spacing:16) {

                    // ── Header card ──
                    VStack(alignment:.leading, spacing:10) {
                        HStack(alignment:.top) {
                            VStack(alignment:.leading, spacing:4) {
                                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                    .font(.system(size:12)).foregroundColor(theme.fog)
                                Text(entry.date.formatted(.dateTime.hour().minute()))
                                    .font(.system(size:11,design:.monospaced)).foregroundColor(theme.fog.opacity(0.7))
                            }
                            Spacer()
                            HStack(spacing:8) {
                                if entry.colorTag != .none {
                                    Circle().fill(entry.colorTag.color).frame(width:10,height:10)
                                }
                                Button {
                                    var e = entry; e.isFavorite.toggle()
                                    store.update(e); entry = e; HX.tap()
                                } label: {
                                    Image(systemName:entry.isFavorite ? "heart.fill" : "heart")
                                        .font(.system(size:16))
                                        .foregroundColor(entry.isFavorite ? theme.heartPink : theme.fog)
                                }.buttonStyle(.plain)
                            }
                        }

                        // Tappable title
                        if editingTitle {
                            TextField("Entry title", text:$titleDraft)
                                .font(.system(size:18,weight:.medium))
                                .foregroundColor(.white)
                                .focused($titleFocused)
                                .onSubmit { commitTitle() }
                                .submitLabel(.done)
                        } else {
                            Text(entry.title)
                                .font(.system(size:18,weight:.medium)).foregroundColor(.white)
                                .onTapGesture { titleDraft = entry.title; editingTitle = true; titleFocused = true; HX.tap() }
                        }

                        HStack(spacing:8) {
                            Image(systemName:"waveform").font(.system(size:12)).foregroundColor(theme.accent)
                            Text(entry.durationFormatted)
                                .font(.system(size:12,design:.monospaced)).foregroundColor(theme.mist)
                            if entry.mood != .none {
                                Text(entry.mood.glyph).foregroundColor(entry.mood.color)
                                Text(entry.mood.label).font(.system(size:12)).foregroundColor(entry.mood.color.opacity(0.8))
                            }
                        }
                    }
                    .padding(16)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius:14))
                    .overlay(RoundedRectangle(cornerRadius:14).stroke(theme.border,lineWidth:1))

                    // ── Playback card ──
                    VStack(spacing:14) {
                        // Scrubber
                        VStack(spacing:6) {
                            GeometryReader { g in
                                ZStack(alignment:.leading) {
                                    Capsule().fill(Color.white.opacity(0.08)).frame(height:5)
                                    Capsule()
                                        .fill(LinearGradient(
                                            colors:[theme.accent, theme.accent.opacity(0.5)],
                                            startPoint:.leading, endPoint:.trailing))
                                        .frame(width:max(5, g.size.width * displayProgress), height:5)
                                        .animation(.linear(duration:0.04), value:displayProgress)
                                    Circle().fill(theme.accent).frame(width:14,height:14)
                                        .offset(x:max(0, g.size.width * displayProgress - 7))
                                }
                                .contentShape(Rectangle())
                                .gesture(DragGesture(minimumDistance:0)
                                    .onChanged { _ in HX.soft() }
                                    .onEnded { v in
                                        guard isPlaying else { return }
                                        engine.seek(to:min(max(0, v.location.x / g.size.width), 1))
                                        HX.rigid()
                                    })
                            }
                            .frame(height:14)
                            HStack {
                                Text(engine.fmt(displayTime))
                                    .font(.system(size:11,design:.monospaced)).foregroundColor(theme.fog)
                                Spacer()
                                Text(engine.fmt(displayDuration))
                                    .font(.system(size:11,design:.monospaced)).foregroundColor(theme.fog)
                            }
                        }

                        // Transport
                        HStack(spacing:32) {
                            Button { HX.tap(); engine.skip(seconds:-15) } label: {
                                Image(systemName:"gobackward.15").font(.system(size:24)).foregroundColor(theme.mist)
                            }.buttonStyle(.plain)
                            .disabled(!isPlaying)
                            .opacity(isPlaying ? 1 : 0.4)

                            Button {
                                HX.press()
                                if isPlaying { engine.stopPlaying() }
                                else { engine.play(entry:entry, speed:Float(settings.playbackSpeed)) }
                            } label: {
                                ZStack {
                                    Circle().fill(theme.accent).frame(width:64,height:64)
                                    Image(systemName:isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size:24)).foregroundColor(theme.bg)
                                }
                            }.buttonStyle(.plain)

                            Button { HX.tap(); engine.skip(seconds:15) } label: {
                                Image(systemName:"goforward.15").font(.system(size:24)).foregroundColor(theme.mist)
                            }.buttonStyle(.plain)
                            .disabled(!isPlaying)
                            .opacity(isPlaying ? 1 : 0.4)
                        }
                        .frame(maxWidth:.infinity)

                        // Speed
                        HStack(spacing:8) {
                            ForEach([0.5,1.0,1.5,2.0] as [Double], id:\.self) { s in
                                Button { HX.tick(); engine.setSpeed(Float(s)) } label: {
                                    Text(s==0.5 ? "½×" : s==1.0 ? "1×" : s==1.5 ? "1.5×" : "2×")
                                        .font(.system(size:12,
                                            weight:isPlaying && Double(engine.playSpeed)==s ? .semibold : .regular,
                                            design:.monospaced))
                                        .foregroundColor(isPlaying && Double(engine.playSpeed)==s ? theme.bg : theme.mist)
                                        .padding(.horizontal,12).padding(.vertical,7)
                                        .background(isPlaying && Double(engine.playSpeed)==s
                                            ? theme.accent : theme.surfaceMid)
                                        .clipShape(Capsule())
                                }.buttonStyle(.plain)
                                .disabled(!isPlaying)
                                .opacity(isPlaying ? 1 : 0.45)
                                .animation(.easeInOut(duration:0.15), value:engine.playSpeed)
                            }
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius:14))
                    .overlay(RoundedRectangle(cornerRadius:14).stroke(theme.border,lineWidth:1))

                    // ── Notes card ──
                    VStack(alignment:.leading, spacing:10) {
                        HStack {
                            Label("Notes", systemImage:"note.text")
                                .font(.system(size:12,weight:.medium))
                                .foregroundColor(theme.fog)
                            Spacer()
                            if editingNote {
                                Button { commitNote() } label: {
                                    Text("Done")
                                        .font(.system(size:13,weight:.medium))
                                        .foregroundColor(theme.accent)
                                }.buttonStyle(.plain)
                            } else {
                                Button { noteDraft = entry.note; editingNote = true; HX.tap() } label: {
                                    Image(systemName:"pencil").font(.system(size:13)).foregroundColor(theme.accent)
                                }.buttonStyle(.plain)
                            }
                        }
                        if editingNote {
                            TextEditor(text:$noteDraft)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .font(.system(size:14)).foregroundColor(.white)
                                .frame(minHeight:100)
                        } else {
                            Text(entry.note.isEmpty ? "Tap pencil to add a note…" : entry.note)
                                .font(.system(size:14))
                                .foregroundColor(entry.note.isEmpty ? theme.fog.opacity(0.6) : .white)
                                .frame(maxWidth:.infinity, alignment:.leading)
                                .onTapGesture { noteDraft = entry.note; editingNote = true; HX.tap() }
                        }
                    }
                    .padding(16)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius:14))
                    .overlay(RoundedRectangle(cornerRadius:14).stroke(theme.border,lineWidth:1))

                    // ── Action buttons ──
                    HStack(spacing:10) {
                        actionBtn(
                            icon: entry.mood == .none ? "face.smiling" : "face.smiling.fill",
                            label: entry.mood == .none ? "Mood" : entry.mood.label,
                            tint: entry.mood == .none ? theme.mist : entry.mood.color
                        ) { showMood = true }

                        actionBtn(
                            icon: "circle.fill",
                            label: entry.colorTag == .none ? "Tag" : entry.colorTag.rawValue.capitalized,
                            tint: entry.colorTag == .none ? theme.mist : entry.colorTag.color
                        ) { showTag = true }

                        actionBtn(icon:"square.and.arrow.up", label:"Share", tint:theme.mist) { prepareShare() }
                    }

                    Spacer().frame(height:40)
                }
                .padding(16)
            }
        }
        .navigationTitle(editingTitle ? "" : entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement:.navigationBarTrailing) {
                Menu {
                    Button { titleDraft = entry.title; editingTitle = true; titleFocused = true } label: {
                        Label("Rename Entry", systemImage:"pencil")
                    }
                    Button { showMood = true } label: { Label("Set Mood",systemImage:"face.smiling") }
                    Button { showTag  = true } label: { Label("Set Tag", systemImage:"circle.fill") }
                    Button { prepareShare()  } label: { Label("Share Recording",systemImage:"square.and.arrow.up") }
                    Divider()
                    Button(role:.destructive) { store.remove(entry); dismiss() } label: {
                        Label("Delete Entry", systemImage:"trash")
                    }
                } label: { Image(systemName:"ellipsis.circle") }
            }
        }
        .sheet(isPresented:$showMood) {
            MoodSheet(entry:entry, store:store, theme:theme) { e in entry = e }
                .presentationDetents([.height(220)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented:$showTag) {
            TagSheet(entry:entry, store:store, theme:theme) { e in entry = e }
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented:$showShare) {
            if let url = shareURL { ShareSheet(url:url) }
        }
    }

    func commitTitle() {
        let trimmed = titleDraft.trimmingCharacters(in:.whitespaces)
        var e = entry; e.title = trimmed.isEmpty ? entry.title : trimmed
        store.update(e); entry = e; editingTitle = false; HX.soft()
    }
    func commitNote() {
        var e = entry; e.note = noteDraft
        store.update(e); entry = e; editingNote = false; HX.soft()
    }
    func actionBtn(icon:String, label:String, tint:Color, action:@escaping()->Void) -> some View {
        Button(action:action) {
            VStack(spacing:5) {
                Image(systemName:icon).font(.system(size:18)).foregroundColor(tint)
                Text(label).font(.system(size:10)).foregroundColor(theme.fog)
            }
            .frame(maxWidth:.infinity).padding(.vertical,12)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(theme.border,lineWidth:1))
        }.buttonStyle(.plain)
    }
    func prepareShare() {
        let url = store.docURL(entry.fileName)
        if FileManager.default.fileExists(atPath:url.path) { shareURL = url; showShare = true }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context:Context) -> UIActivityViewController {
        UIActivityViewController(activityItems:[url], applicationActivities:nil)
    }
    func updateUIViewController(_ vc:UIActivityViewController, context:Context) {}
}

// MARK: ── TAB: RECORD ────────────────────────────────────────────

struct RecordTab: View {
    @ObservedObject var engine:   AudioEngine
    @ObservedObject var store:    JournalStore
    @ObservedObject var settings: AppSettings

    @State private var showSave    = false
    @State private var pendingFile = ""
    @State private var pendingDur: TimeInterval = 0
    @State private var saveTitle   = ""
    @State private var saveMood:   VoiceEntry.Mood = .none

    var theme: AppTheme { settings.theme }
    var isRecording: Bool { engine.state == .recording }
    var isPaused:    Bool { engine.state == .paused }
    var isActive:    Bool { isRecording || isPaused }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Background ──
                theme.bg.ignoresSafeArea()

                VStack(spacing:0) {

                    // ── Top: greeting ──
                    VStack(spacing:6) {
                        Text(greetingLabel())
                            .font(.system(size:11, weight:.semibold)).kerning(2)
                            .foregroundColor(theme.fog)
                            .textCase(.uppercase)
                        Text("Voice Journal")
                            .font(.system(size:28, weight:.light, design:.serif))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth:.infinity)
                    .padding(.top, geo.size.height * 0.07)

                    Spacer()

                    // ── Hero: waveform ──
                    ZStack {
                        // Card
                        RoundedRectangle(cornerRadius:32)
                            .fill(isRecording
                                ? theme.crimson.opacity(0.07)
                                : theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius:32)
                                    .stroke(isRecording
                                        ? theme.crimson.opacity(0.25)
                                        : theme.border, lineWidth:1)
                            )
                            .animation(.easeInOut(duration:0.45), value:isRecording)

                        VStack(spacing:0) {
                            // Waveform
                            WaveVisualiser(bars:engine.bars, isRecording:isRecording, theme:theme)
                                .frame(height:geo.size.height * 0.14)
                                .padding(.horizontal, 28)

                            // Timer / idle hint
                            Group {
                                if isActive {
                                    HStack(spacing:10) {
                                        // REC dot or pause icon
                                        if isRecording {
                                            Circle().fill(theme.crimson)
                                                .frame(width:8, height:8)
                                        } else {
                                            Image(systemName:"pause.fill")
                                                .font(.system(size:10, weight:.bold))
                                                .foregroundColor(theme.accent)
                                        }
                                        Text(engine.elapsedFormatted())
                                            .font(.system(size:22, weight:.thin, design:.monospaced))
                                            .foregroundColor(isRecording ? theme.crimson : theme.accent)
                                            .contentTransition(.numericText())
                                    }
                                } else {
                                    Text("Ready to record")
                                        .font(.system(size:13))
                                        .foregroundColor(theme.fog.opacity(0.6))
                                }
                            }
                            .padding(.top, 16)
                            .animation(.spring(response:0.4, dampingFraction:0.8), value:isActive)
                        }
                        .padding(.vertical, 32)
                    }
                    .frame(height: geo.size.height * 0.28)
                    .padding(.horizontal, 22)

                    Spacer()

                    // ── Controls ──
                    VStack(spacing:0) {
                        // Pause / Resume — slides in above button
                        if isActive {
                            Button {
                                HX.press()
                                if isRecording { engine.pauseRecording() }
                                else { engine.resumeRecording() }
                            } label: {
                                HStack(spacing:8) {
                                    Image(systemName:isPaused ? "play.fill" : "pause.fill")
                                        .font(.system(size:12, weight:.bold))
                                    Text(isPaused ? "Resume" : "Pause")
                                        .font(.system(size:14, weight:.semibold))
                                }
                                .foregroundColor(theme.accent)
                                .padding(.horizontal,26).padding(.vertical,12)
                                .background(theme.accent.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(theme.accent.opacity(0.25), lineWidth:1))
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 28)
                            .transition(.move(edge:.bottom).combined(with:.opacity))
                        }

                        // Main record button
                        RecordBtn(state:engine.state, theme:theme) {
                            if isActive { HX.ok(); engine.stopRecording() }
                            else { HX.heavy(); engine.requestAndRecord() }
                        }

                        // Hint label
                        Text(isRecording ? "tap to stop"
                           : isPaused   ? "tap to finish"
                           :               "tap to begin")
                            .font(.system(size:11, weight:.medium)).kerning(1.8)
                            .foregroundColor(theme.fog.opacity(0.7))
                            .textCase(.uppercase)
                            .padding(.top, 18)
                    }
                    .animation(.spring(response:0.38, dampingFraction:0.78), value:isActive)
                    .animation(.spring(response:0.38, dampingFraction:0.78), value:isPaused)

                    Spacer()

                    // ── Stats strip (always visible, shows dashes when empty) ──
                    HStack(spacing:0) {
                        statPill(
                            store.entries.isEmpty ? "—" : "\(store.entries.count)",
                            "entries"
                        )
                        divider()
                        statPill(
                            store.entries.isEmpty ? "—" : store.totalFormatted,
                            "recorded"
                        )
                        divider()
                        statPill(
                            store.streak == 0 ? "—" : "\(store.streak)🔥",
                            "streak"
                        )
                    }
                    .padding(.vertical, 16)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius:20))
                    .overlay(RoundedRectangle(cornerRadius:20).stroke(theme.border, lineWidth:1))
                    .padding(.horizontal, 22)
                    .padding(.bottom, geo.size.height * 0.04)
                }
            }
        }
        .sheet(isPresented:$showSave) {
            SaveSheet(title:$saveTitle, mood:$saveMood, duration:pendingDur, theme:theme) {
                let e = VoiceEntry(duration:pendingDur, fileName:pendingFile, title:saveTitle, mood:saveMood)
                store.add(e); HX.ok()
                saveTitle = ""; saveMood = .none; showSave = false
            }
        }
        .onAppear {
            engine.onRecordFinish = { file, dur in
                pendingFile = file; pendingDur = dur
                saveTitle = VoiceEntry.smartTitle()
                DispatchQueue.main.asyncAfter(deadline:.now()+0.2) { showSave = true }
            }
        }
    }

    func statPill(_ v:String, _ l:String) -> some View {
        VStack(spacing:3) {
            Text(v)
                .font(.system(size:17, weight:.semibold, design:.rounded))
                .foregroundColor(v == "—" ? theme.fog.opacity(0.4) : .white)
            Text(l)
                .font(.system(size:10, weight:.medium))
                .foregroundColor(theme.fog)
        }
        .frame(maxWidth:.infinity)
    }

    func divider() -> some View {
        Rectangle().fill(theme.border).frame(width:1, height:30)
    }

    func greetingLabel() -> String {
        let h = Calendar.current.component(.hour, from:.now)
        switch h {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }
}

// MARK: ── TAB: HISTORY ───────────────────────────────────────────

struct HistoryTab: View {
    @ObservedObject var store:    JournalStore
    @ObservedObject var engine:   AudioEngine
    @ObservedObject var settings: AppSettings

    var theme: AppTheme { settings.theme }
    var playingEntry: VoiceEntry? { store.entries.first { $0.id == engine.playingID } }

    var body: some View {
        VStack(spacing:0) {
            MoodFilterBar(store:store, theme:theme).padding(.vertical,6)
            Divider().background(theme.border)

            if store.entries.isEmpty {
                emptyState
            } else if store.filtered(newestFirst:settings.sortNewestFirst).isEmpty {
                emptySearchState
            } else if settings.calendarView {
                CalendarView(store:store, engine:engine, settings:settings)
            } else {
                TimelineView(store:store, engine:engine, settings:settings)
            }
        }
        .safeAreaInset(edge:.bottom, spacing:0) {
            if let e = playingEntry {
                MiniPlayerBar(engine:engine, entry:e, theme:theme)
                    .transition(.move(edge:.bottom).combined(with:.opacity))
            }
        }
        .animation(.spring(response:0.35, dampingFraction:0.8), value:playingEntry?.id)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text:$store.searchQuery, prompt:"Search entries")
        .toolbar {
            ToolbarItemGroup(placement:.navigationBarTrailing) {
                Button { store.favOnly.toggle(); HX.tap() } label: {
                    Image(systemName:store.favOnly ? "heart.fill" : "heart")
                        .foregroundColor(store.favOnly ? theme.heartPink : theme.mist)
                }
                Menu {
                    Button { settings.calendarView = false; HX.tick() } label: {
                        Label("Timeline", systemImage:"list.bullet")
                    }
                    Button { settings.calendarView = true; HX.tick() } label: {
                        Label("Calendar", systemImage:"calendar")
                    }
                    Divider()
                    Button { settings.sortNewestFirst = true;  HX.tick() } label: {
                        Label("Newest First", systemImage:"arrow.down")
                    }
                    Button { settings.sortNewestFirst = false; HX.tick() } label: {
                        Label("Oldest First", systemImage:"arrow.up")
                    }
                } label: {
                    Image(systemName:"ellipsis.circle")
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing:12) {
            Spacer()
            Image(systemName:"waveform").font(.system(size:42)).foregroundColor(theme.fog.opacity(0.25))
            Text("No entries yet").font(.system(size:16,weight:.medium)).foregroundColor(theme.fog.opacity(0.6))
            Text("Head to Record to begin.").font(.system(size:13)).foregroundColor(theme.fog.opacity(0.4))
            Spacer()
        }
    }

    var emptySearchState: some View {
        VStack(spacing:12) {
            Spacer()
            Image(systemName:"magnifyingglass").font(.system(size:36)).foregroundColor(theme.fog.opacity(0.25))
            Text("No results").font(.system(size:16,weight:.medium)).foregroundColor(theme.fog.opacity(0.6))
            Text("Try a different search or filter.").font(.system(size:13)).foregroundColor(theme.fog.opacity(0.4))
            Spacer()
        }
    }
}

// MARK: - Timeline

struct TimelineView: View {
    @ObservedObject var store:    JournalStore
    @ObservedObject var engine:   AudioEngine
    @ObservedObject var settings: AppSettings
    var theme: AppTheme { settings.theme }

    var body: some View {
        List {
            ForEach(store.groupedByDay(newestFirst:settings.sortNewestFirst), id:\.key) { group in
                Section {
                    ForEach(group.entries) { entry in
                        NavigationLink {
                            EntryDetailView(entry:entry, store:store, engine:engine, settings:settings)
                        } label: {
                            EntryRow(entry:entry, engine:engine, theme:theme)
                        }
                        .listRowBackground(theme.surface)
                        .listRowSeparatorTint(theme.border)
                        .swipeActions(edge:.trailing, allowsFullSwipe:true) {
                            Button(role:.destructive) { HX.warn(); DispatchQueue.main.asyncAfter(deadline:.now()+0.1) { HX.error() }; store.remove(entry) } label: {
                                Label("Delete", systemImage:"trash")
                            }
                        }
                        .swipeActions(edge:.leading) {
                            Button {
                                entry.isFavorite ? HX.warn() : HX.ok()
                                var e = entry; e.isFavorite.toggle(); store.update(e)
                            } label: {
                                Label(entry.isFavorite ? "Unfave" : "Favorite",
                                      systemImage:entry.isFavorite ? "heart.slash" : "heart.fill")
                            }
                            .tint(theme.heartPink)
                        }
                    }
                } header: {
                    HStack {
                        Text(dayLabel(group.date))
                            .font(.system(size:12,weight:.semibold)).foregroundColor(theme.fog)
                        Spacer()
                        Text("\(group.entries.count) entry".pluralized(group.entries.count))
                            .font(.system(size:11)).foregroundColor(theme.fog.opacity(0.6))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.bg)
    }

    func dayLabel(_ d:Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d)     { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        return d.formatted(.dateTime.weekday(.wide).month().day())
    }
}

// MARK: - String pluralize helper

extension String {
    func pluralized(_ n:Int) -> String { n == 1 ? self : self.replacingOccurrences(of:"entry",with:"entries") }
}

// MARK: - Entry Row

struct EntryRow: View {
    let entry: VoiceEntry
    @ObservedObject var engine: AudioEngine
    let theme: AppTheme
    var isPlaying: Bool { engine.playingID == entry.id }

    var body: some View {
        HStack(spacing:12) {
            // Play/stop button
            Button {
                HX.press()
                if isPlaying { engine.stopPlaying() }
                else { engine.play(entry:entry) }
            } label: {
                ZStack {
                    Circle()
                        .fill(isPlaying ? theme.accent.opacity(0.15) : Color.white.opacity(0.05))
                        .frame(width:40,height:40)
                    Circle()
                        .stroke(isPlaying ? theme.accent.opacity(0.4) : Color.white.opacity(0.07), lineWidth:1)
                        .frame(width:40,height:40)
                    Image(systemName:isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size:12))
                        .foregroundColor(isPlaying ? theme.accent : theme.mist)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment:.leading, spacing:4) {
                HStack(spacing:6) {
                    if entry.colorTag != .none {
                        RoundedRectangle(cornerRadius:1.5)
                            .fill(entry.colorTag.color)
                            .frame(width:3,height:14)
                    }
                    Text(entry.title)
                        .font(.system(size:14,weight:.medium)).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    if entry.isFavorite {
                        Image(systemName:"heart.fill").font(.system(size:10)).foregroundColor(theme.heartPink)
                    }
                }
                HStack(spacing:6) {
                    Text(entry.timeLabel)
                        .font(.system(size:11,design:.monospaced)).foregroundColor(theme.fog)
                    Text("·").foregroundColor(theme.fog)
                    Text(entry.durationFormatted)
                        .font(.system(size:11,design:.monospaced)).foregroundColor(theme.fog)
                    if entry.mood != .none {
                        Text(entry.mood.glyph).font(.system(size:11)).foregroundColor(entry.mood.color)
                    }
                    if !entry.note.isEmpty {
                        Image(systemName:"note.text").font(.system(size:10)).foregroundColor(theme.fog.opacity(0.5))
                    }
                }
            }
        }
        .padding(.vertical,4)
    }
}

// MARK: - Calendar View

struct CalendarView: View {
    @ObservedObject var store:    JournalStore
    @ObservedObject var engine:   AudioEngine
    @ObservedObject var settings: AppSettings
    @State private var displayed = Date()
    @State private var selected:  Date? = nil
    var theme: AppTheme { settings.theme }

    var entriesForSelected: [VoiceEntry] {
        guard let s = selected else { return [] }
        return store.entries
            .filter { Calendar.current.isDate($0.date, inSameDayAs:s) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView(showsIndicators:false) {
            VStack(spacing:16) {
                // Month nav
                HStack {
                    Button {
                        HX.rigid()
                        displayed = Calendar.current.date(byAdding:.month, value:-1, to:displayed)!
                    } label: {
                        Image(systemName:"chevron.left").foregroundColor(theme.mist).font(.system(size:18))
                    }.buttonStyle(.plain)
                    Spacer()
                    Text(displayed.formatted(.dateTime.month(.wide).year()))
                        .font(.system(size:16,weight:.semibold)).foregroundColor(.white)
                    Spacer()
                    Button {
                        HX.rigid()
                        displayed = Calendar.current.date(byAdding:.month, value:1, to:displayed)!
                    } label: {
                        Image(systemName:"chevron.right").foregroundColor(theme.mist).font(.system(size:18))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal,22)

                // Weekday headers — use index to avoid duplicate key crash
                let weekdays = ["S","M","T","W","T","F","S"]
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:4),count:7), spacing:4) {
                    ForEach(Array(weekdays.enumerated()), id:\.offset) { _, d in
                        Text(d).font(.system(size:11,weight:.medium)).foregroundColor(theme.fog).frame(height:24)
                    }
                    ForEach(Array(daysInMonth().enumerated()), id:\.offset) { _, day in
                        if let day = day {
                            let k   = dayKey(day)
                            let has = store.daysWithEntries.contains(k)
                            let isSel = selected.map { Calendar.current.isDate(day,inSameDayAs:$0) } ?? false
                            let isToday = Calendar.current.isDateInToday(day)
                            Button {
                                isSel ? HX.tap() : HX.press()
                                withAnimation(.spring(response:0.3,dampingFraction:0.8)) {
                                    selected = isSel ? nil : day
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(isSel ? theme.accent : .clear)
                                        .frame(width:34,height:34)
                                    if has && !isSel {
                                        Circle()
                                            .fill(theme.accent.opacity(0.18))
                                            .frame(width:34,height:34)
                                    }
                                    Text("\(Calendar.current.component(.day,from:day))")
                                        .font(.system(size:13, weight: has || isToday ? .semibold : .regular))
                                        .foregroundColor(isSel ? theme.bg : has ? theme.accent : isToday ? .white : theme.fog)
                                }
                                .frame(height:36)
                            }.buttonStyle(.plain)
                        } else {
                            Color.clear.frame(height:36)
                        }
                    }
                }
                .padding(.horizontal,16)

                // Entries for selected day
                if selected != nil {
                    if entriesForSelected.isEmpty {
                        Text("No entries this day")
                            .font(.system(size:13)).foregroundColor(theme.fog).padding(.top,4)
                    } else {
                        VStack(spacing:8) {
                            ForEach(entriesForSelected) { entry in
                                NavigationLink {
                                    EntryDetailView(entry:entry, store:store, engine:engine, settings:settings)
                                } label: {
                                    EntryRow(entry:entry, engine:engine, theme:theme)
                                        .padding(.horizontal,14).padding(.vertical,10)
                                        .background(theme.surface)
                                        .clipShape(RoundedRectangle(cornerRadius:12))
                                        .overlay(RoundedRectangle(cornerRadius:12).stroke(theme.border,lineWidth:1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal,16)
                    }
                }
                Spacer().frame(height:40)
            }
            .padding(.top,8)
        }
    }

    func daysInMonth() -> [Date?] {
        let cal     = Calendar.current
        let range   = cal.range(of:.day, in:.month, for:displayed)!
        let comps   = cal.dateComponents([.year,.month], from:displayed)
        let first   = cal.date(from:comps)!
        let weekday = cal.component(.weekday, from:first) - 1
        var days: [Date?] = Array(repeating:nil, count:weekday)
        for d in range { days.append(cal.date(byAdding:.day, value:d-1, to:first)) }
        return days
    }
    func dayKey(_ d:Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from:d)
    }
}

// MARK: - Mood Filter Bar

struct MoodFilterBar: View {
    @ObservedObject var store: JournalStore
    let theme: AppTheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators:false) {
            HStack(spacing:8) {
                chip("All", store.moodFilter == nil, .white) {
                    store.moodFilter = nil; HX.tick()
                }
                ForEach(VoiceEntry.Mood.allCases.filter { $0 != .none }, id:\.self) { m in
                    chip(m.glyph + " " + m.label, store.moodFilter == m, m.color) {
                        store.moodFilter = store.moodFilter == m ? nil : m; HX.tick()
                    }
                }
            }
            .padding(.horizontal,16)
        }
    }

    func chip(_ label:String, _ active:Bool, _ color:Color, _ action:@escaping()->Void) -> some View {
        Button(action:action) {
            Text(label).font(.system(size:12))
                .foregroundColor(active ? (color == .white ? theme.bg : color) : theme.fog)
                .padding(.horizontal,12).padding(.vertical,7)
                .background(active ? (color == .white ? Color.white : color.opacity(0.15)) : theme.surfaceMid)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(active ? color.opacity(0.35) : theme.border, lineWidth:1))
        }.buttonStyle(.plain)
    }
}

// MARK: ── TAB: SETTINGS ─────────────────────────────────────────

struct SettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store:    JournalStore
    @State private var showDeleteConfirm = false
    var theme: AppTheme { settings.theme }

    var body: some View {
        Form {
            Section("Appearance") {
                NavigationLink {
                    ThemePickerView(settings:settings)
                } label: {
                    HStack(spacing:12) {
                        Image(systemName:settings.theme.icon)
                            .font(.system(size:14))
                            .foregroundColor(settings.theme.accent)
                            .frame(width:24)
                        Text("Theme")
                        Spacer()
                        Text(settings.theme.name)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Playback") {
                Picker("Default Speed", selection:$settings.playbackSpeed) {
                    Text("0.5×").tag(0.5)
                    Text("1×").tag(1.0)
                    Text("1.5×").tag(1.5)
                    Text("2×").tag(2.0)
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.playbackSpeed) { _ in HX.tick() }
            }

            Section("History") {
                Toggle(isOn:$settings.calendarView) {
                    Label("Calendar View", systemImage:"calendar")
                }
                .onChange(of: settings.calendarView) { _ in HX.soft() }

                Toggle(isOn:$settings.sortNewestFirst) {
                    Label("Newest First", systemImage:"arrow.down.circle")
                }
                .onChange(of: settings.sortNewestFirst) { _ in HX.soft() }
            }

            Section("Daily Reminder") {
                Toggle(isOn:$settings.remindersOn) {
                    Label("Enable Reminder", systemImage:"bell")
                }
                .onChange(of: settings.remindersOn) { v in v ? HX.ok() : HX.tap() }

                if settings.remindersOn {
                    DatePicker("Time",
                        selection: Binding(
                            get: { settings.reminderDate },
                            set: { settings.reminderDate = $0; HX.tick() }
                        ),
                        displayedComponents:.hourAndMinute)
                }
            }

            Section("Stats") {
                LabeledContent("Total Entries",  value:"\(store.entries.count)")
                LabeledContent("Total Recorded", value:store.totalFormatted)
                LabeledContent("Day Streak",     value:"\(store.streak) 🔥")
                LabeledContent("Favorites",      value:"\(store.entries.filter{$0.isFavorite}.count) ♥")
            }

            Section("Haptics") {
                Toggle(isOn:$settings.hapticsEnabled) {
                    Label("Enable Haptics", systemImage:"hand.tap.fill")
                }
                .onChange(of: settings.hapticsEnabled) { v in
                    // fire one confirmation tap if turning ON; silent if turning off
                    if v { HX.ok() }
                }
            }

            Section("Data") {
                Button(role: .destructive) {
                    HX.warn()
                    showDeleteConfirm = true
                } label: {
                    Label("Delete All Entries", systemImage: "trash")
                }
            }

            Section("App") {
               
                    HStack {
                        Label("About", systemImage: "app.badge")
                        Spacer()
                        Text("1.0.1")
                            .foregroundColor(.secondary)
                    
                }

                Link(
                    destination: URL(string: "mailto:fenuku.kekeli8989@gmail.com?subject=Bug%20Report")!
                ) {
                    Label("Report a Bug", systemImage: "envelope.fill")
                }

                Button {
                    if let url = URL(string: "https://appgallery.io/Keli") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Label("Website", systemImage: "globe")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Support") {

                Button {
                    if let url = URL(string: "https://apps.apple.com/app/id6760410000") {
                        shareApp(url: url)
                    }
                } label: {
                    HStack {
                        Label("Share App", systemImage: "square.and.arrow.up")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    requestReview()
                } label: {
                    HStack {
                        Label("Rate App", systemImage: "star.fill")
                        Spacer()
                        Image(systemName: "hand.thumbsup.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Delete all entries?", isPresented:$showDeleteConfirm, titleVisibility:.visible) {
            Button("Delete All", role:.destructive) {
                store.entries.forEach { try? FileManager.default.removeItem(at:store.docURL($0.fileName)) }
                withAnimation { store.entries.removeAll() }
                HX.ok()
            }
            Button("Cancel", role:.cancel) {}
        } message: { Text("This cannot be undone.") }
    }
}


func shareApp(url: URL) {
    guard
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
        let root = scene.windows.first?.rootViewController
    else { return }

    let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    root.present(vc, animated: true)
}

func requestReview() {
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        SKStoreReviewController.requestReview(in: scene)
    }
}
// MARK: ── SHEETS ─────────────────────────────────────────────────

struct SaveSheet: View {
    @Binding var title: String
    @Binding var mood:  VoiceEntry.Mood
    let duration: TimeInterval
    let theme: AppTheme
    let onSave: () -> Void

    @FocusState private var titleFocused: Bool

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing:0) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width:36, height:4)
                    .padding(.top,12)

                // Duration hero
                VStack(spacing:6) {
                    Text(fmt(duration))
                        .font(.system(size:52, weight:.ultraLight, design:.monospaced))
                        .foregroundColor(.white)
                    HStack(spacing:6) {
                        Circle().fill(theme.crimson).frame(width:6, height:6)
                        Text("recorded")
                            .font(.system(size:12, weight:.medium)).kerning(1)
                            .foregroundColor(theme.fog)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 28)

                // Title field
                VStack(alignment:.leading, spacing:6) {
                    Text("NAME THIS ENTRY")
                        .font(.system(size:10, weight:.semibold)).kerning(1.5)
                        .foregroundColor(theme.fog.opacity(0.7))
                        .padding(.horizontal, 4)

                    TextField("", text:$title)
                        .font(.system(size:17, weight:.medium))
                        .foregroundColor(.white)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { onSave() }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(theme.surfaceMid)
                        .clipShape(RoundedRectangle(cornerRadius:14))
                        .overlay(
                            RoundedRectangle(cornerRadius:14)
                                .stroke(titleFocused ? theme.accent.opacity(0.5) : theme.border, lineWidth:1)
                        )
                }
                .padding(.horizontal, 22)

                // Mood label
                Text("MOOD")
                    .font(.system(size:10, weight:.semibold)).kerning(1.5)
                    .foregroundColor(theme.fog.opacity(0.7))
                    .frame(maxWidth:.infinity, alignment:.leading)
                    .padding(.horizontal, 26)
                    .padding(.top, 22)
                    .padding(.bottom, 10)

                // Mood chips
                ScrollView(.horizontal, showsIndicators:false) {
                    HStack(spacing:8) {
                        ForEach(VoiceEntry.Mood.allCases.filter { $0 != .none }, id:\.self) { m in
                            Button { mood == m ? HX.tap() : HX.press(); mood = mood == m ? .none : m } label: {
                                VStack(spacing:5) {
                                    Text(m.glyph)
                                        .font(.system(size:18))
                                        .foregroundColor(mood == m ? m.color : m.color.opacity(0.45))
                                    Text(m.label)
                                        .font(.system(size:10, weight:.medium))
                                        .foregroundColor(mood == m ? .white : theme.fog)
                                }
                                .frame(width:58, height:56)
                                .background(mood == m ? m.color.opacity(0.14) : theme.surfaceMid)
                                .clipShape(RoundedRectangle(cornerRadius:14))
                                .overlay(RoundedRectangle(cornerRadius:14)
                                    .stroke(mood == m ? m.color.opacity(0.45) : theme.border, lineWidth:1))
                                .scaleEffect(mood == m ? 1.05 : 1.0)
                                .animation(.spring(response:0.3, dampingFraction:0.65), value:mood)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22)
                }

                // Save button
                Button(action:onSave) {
                    HStack(spacing:8) {
                        Image(systemName:"checkmark")
                            .font(.system(size:14, weight:.bold))
                        Text("Save Entry")
                            .font(.system(size:16, weight:.semibold))
                    }
                    .foregroundColor(theme.bg)
                    .frame(maxWidth:.infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(
                            colors:[theme.accent, theme.accent.opacity(0.8)],
                            startPoint:.topLeading, endPoint:.bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius:16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
        }
        .presentationDetents([.height(460)])
        .presentationDragIndicator(.hidden) // we draw our own
        .onAppear { titleFocused = true }
    }
    func fmt(_ t:TimeInterval) -> String { String(format:"%d:%02d", Int(t)/60, Int(t)%60) }
}

struct MoodSheet: View {
    var entry: VoiceEntry
    @ObservedObject var store: JournalStore
    let theme: AppTheme
    var onUpdate: ((VoiceEntry) -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @State private var selected: VoiceEntry.Mood

    init(entry:VoiceEntry, store:JournalStore, theme:AppTheme, onUpdate:((VoiceEntry)->Void)?=nil) {
        self.entry = entry; self.store = store; self.theme = theme; self.onUpdate = onUpdate
        _selected = State(initialValue:entry.mood)
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(spacing:20) {
                Capsule().fill(Color.white.opacity(0.2)).frame(width:36,height:4).padding(.top,8)
                Text("How are you feeling?")
                    .font(.system(size:15,weight:.medium)).foregroundColor(.white)
                HStack(spacing:10) {
                    ForEach(VoiceEntry.Mood.allCases.filter { $0 != .none }, id:\.self) { m in
                        Button {
                            HX.tick()
                            selected = selected == m ? .none : m
                            var e = entry; e.mood = selected
                            store.update(e); onUpdate?(e)
                            DispatchQueue.main.asyncAfter(deadline:.now()+0.25) { dismiss() }
                        } label: {
                            VStack(spacing:6) {
                                Text(m.glyph).font(.system(size:22)).foregroundColor(m.color)
                                Text(m.label).font(.system(size:9,weight:.medium)).foregroundColor(theme.fog)
                            }
                            .frame(width:48,height:60)
                            .background(selected == m ? m.color.opacity(0.14) : theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius:12))
                            .overlay(RoundedRectangle(cornerRadius:12).stroke(
                                selected == m ? m.color.opacity(0.45) : theme.border, lineWidth:1))
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
            }
            .padding(.horizontal,16)
        }
    }
}

struct TagSheet: View {
    var entry: VoiceEntry
    @ObservedObject var store: JournalStore
    let theme: AppTheme
    var onUpdate: ((VoiceEntry) -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(spacing:20) {
                Capsule().fill(Color.white.opacity(0.2)).frame(width:36,height:4).padding(.top,8)
                Text("Colour tag").font(.system(size:15,weight:.medium)).foregroundColor(.white)
                HStack(spacing:14) {
                    ForEach(VoiceEntry.Tag.allCases, id:\.self) { tag in
                        Button {
                            HX.tick()
                            var e = entry; e.colorTag = tag
                            store.update(e); onUpdate?(e); dismiss()
                        } label: {
                            VStack(spacing:6) {
                                Circle()
                                    .fill(tag == .none ? Color.white.opacity(0.2) : tag.color)
                                    .frame(width:30,height:30)
                                    .overlay(Circle().stroke(
                                        entry.colorTag == tag ? Color.white.opacity(0.5) : .clear, lineWidth:2))
                                Text(tag == .none ? "None" : tag.rawValue.capitalized)
                                    .font(.system(size:10)).foregroundColor(theme.fog)
                            }
                            .frame(width:56,height:64)
                            .background(entry.colorTag == tag ? Color.white.opacity(0.07) : theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius:12))
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
            }
        }
        .presentationDetents([.height(200)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Root

struct VoiceJournalView: View {
    @StateObject private var store    = JournalStore()
    @StateObject private var engine   = AudioEngine()
    @StateObject private var settings = AppSettings()
    @StateObject private var appState = AppState()

    var body: some View {
        TabView(selection:$appState.selectedTab) {

            // Record tab — no NavigationStack needed; it's self-contained
            RecordTab(engine:engine, store:store, settings:settings)
                .tabItem { Label("Record", systemImage:"mic") }
                .tag(0)

            NavigationStack {
                HistoryTab(store:store, engine:engine, settings:settings)
            }
            .tabItem { Label("History", systemImage:"clock") }
            .tag(1)

            NavigationStack {
                SettingsTab(settings:settings, store:store)
            }
            .tabItem { Label("Settings", systemImage:"gearshape") }
            .tag(2)
        }
        .environmentObject(appState)
        .tint(settings.theme.accent)
        .preferredColorScheme(.dark)
    }
}

