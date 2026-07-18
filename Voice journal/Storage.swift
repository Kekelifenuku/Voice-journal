//  Storage.swift — Voice Journal
//  File-based persistence, Markdown/zip export, backup & restore.

import Foundation
import Compression

// MARK: - Store (file-based persistence)

enum Store {
    private static let fm = FileManager.default
    private static let legacyKey = "vj_v5"

    static var supportDir: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("VoiceJournal", isDirectory: true)
        if !fm.fileExists(atPath: d.path) {
            try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        }
        return d
    }
    static var entriesURL: URL { supportDir.appendingPathComponent("entries.json") }
    static var docsDir: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static func audioURL(_ name: String) -> URL { docsDir.appendingPathComponent(name) }

    /// Load entries from the JSON file, migrating once from the legacy UserDefaults blob.
    static func load() -> [VoiceEntry] {
        if !fm.fileExists(atPath: entriesURL.path) {
            if let d = UserDefaults.standard.data(forKey: legacyKey),
               let v = try? JSONDecoder().decode([VoiceEntry].self, from: d) {
                save(v)                                   // migrate
                UserDefaults.standard.removeObject(forKey: legacyKey)
                return v
            }
            return []
        }
        guard let d = try? Data(contentsOf: entriesURL),
              let v = try? JSONDecoder().decode([VoiceEntry].self, from: d) else { return [] }
        return v
    }

    /// Atomic save.
    static func save(_ entries: [VoiceEntry]) {
        guard let d = try? JSONEncoder().encode(entries) else { return }
        try? d.write(to: entriesURL, options: .atomic)
    }
}

// MARK: - Export / Backup

enum Exporter {
    private static let fm = FileManager.default

    // ── Markdown ─────────────────────────────────────────────

    /// Trimmed, or nil when there's nothing but whitespace (avoids dangling section headers).
    private nonisolated static func filled(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// Markdown treats a single newline as a space, which silently reflows multi-line notes and
    /// transcripts into one blob. Two trailing spaces force the line break the user actually wrote.
    private nonisolated static func preservingBreaks(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: "  \n")
    }

    nonisolated static func entryMarkdown(_ e: VoiceEntry) -> String {
        // H2 per entry: the document title owns H1, so entries nest under it and the export
        // gets a real outline.
        var s = "## \(filled(e.title) ?? "Untitled entry")\(e.isFavorite ? " ★" : "")\n\n"
        s += "*\(e.date.formatted(date: .complete, time: .shortened))*  ·  \(e.durationLong)\n\n"
        if let prompt = filled(e.prompt) { s += "> \(prompt)\n\n" }
        var meta: [String] = []
        if e.mood != .none { meta.append("**Mood:** \(e.mood.label)") }
        if e.isFavorite { meta.append("**Favorite:** yes") }
        if !e.themes.isEmpty { meta.append("**Themes:** \(e.themes.joined(separator: ", "))") }
        if !meta.isEmpty { s += meta.joined(separator: "  ·  ") + "\n\n" }
        if let summary = filled(e.summary) { s += "### Summary\n\n\(preservingBreaks(summary))\n\n" }
        if let transcript = filled(e.transcript) { s += "### Transcript\n\n\(preservingBreaks(transcript))\n\n" }
        if let note = filled(e.note) { s += "### Note\n\n\(preservingBreaks(note))\n\n" }
        return s
    }

    static func allMarkdown(_ entries: [VoiceEntry]) -> String {
        let sorted = entries.sorted { $0.date > $1.date }
        let count = entries.count
        let noun = count == 1 ? "entry" : "entries"
        return "# Voice Journal\n\nExported \(Date().formatted(date: .abbreviated, time: .shortened)) · \(count) \(noun)\n\n---\n\n"
            + sorted.map(entryMarkdown).joined(separator: "\n---\n\n")
    }

    /// Write text to a temp file with a friendly name, for the share sheet.
    static func tempFile(_ text: String, name: String) throws -> URL {
        let url = fm.temporaryDirectory.appendingPathComponent(name)
        try text.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    // ── Backup zip ───────────────────────────────────────────

    /// Full backup: entries.json + audio/*.m4a + Journal.md, zipped for the share sheet.
    static func backupZip(_ entries: [VoiceEntry]) throws -> URL {
        let stage = fm.temporaryDirectory.appendingPathComponent("VoiceJournalBackup", isDirectory: true)
        try? fm.removeItem(at: stage)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)

        try JSONEncoder().encode(entries).write(to: stage.appendingPathComponent("entries.json"), options: .atomic)

        let audioDir = stage.appendingPathComponent("audio", isDirectory: true)
        try fm.createDirectory(at: audioDir, withIntermediateDirectories: true)
        for e in entries {
            let src = Store.audioURL(e.fileName)
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: audioDir.appendingPathComponent(e.fileName))
            }
        }
        try allMarkdown(entries).data(using: .utf8)?.write(to: stage.appendingPathComponent("Journal.md"), options: .atomic)

        return try zipDirectory(stage, outputName: "VoiceJournal-Backup.zip")
    }

    /// Zip a directory using the system file coordinator (`.forUploading` produces a zip).
    private static func zipDirectory(_ dir: URL, outputName: String) throws -> URL {
        let coordinator = NSFileCoordinator()
        var coordErr: NSError?
        var copyErr: Error?
        var result: URL?
        coordinator.coordinate(readingItemAt: dir, options: .forUploading, error: &coordErr) { zippedTmp in
            let dest = fm.temporaryDirectory.appendingPathComponent(outputName)
            do {
                try? fm.removeItem(at: dest)
                try fm.copyItem(at: zippedTmp, to: dest)
                result = dest
            } catch { copyErr = error }
        }
        if let coordErr { throw coordErr }
        if let copyErr { throw copyErr }
        guard let result else { throw ExportError.zipFailed }
        return result
    }

    // ── Restore ──────────────────────────────────────────────

    /// Restore from a backup zip: bring back entries + audio, merged with existing (by id).
    @MainActor
    static func restore(from zipURL: URL, into store: JournalStore) throws {
        let needsScope = zipURL.startAccessingSecurityScopedResource()
        defer { if needsScope { zipURL.stopAccessingSecurityScopedResource() } }

        let files = try Zip.read(zipURL)
        guard let entriesData = files.first(where: { $0.name.hasSuffix("entries.json") })?.data,
              let restored = try? JSONDecoder().decode([VoiceEntry].self, from: entriesData)
        else { throw ExportError.badBackup }

        // Restore audio files.
        for f in files where f.name.contains("audio/") && f.name.hasSuffix(".m4a") {
            let name = (f.name as NSString).lastPathComponent
            let dest = Store.audioURL(name)
            if !fm.fileExists(atPath: dest.path) { try? f.data.write(to: dest, options: .atomic) }
        }

        // Merge entries (existing ids win to avoid clobbering newer edits).
        var byID = Dictionary(uniqueKeysWithValues: store.entries.map { ($0.id, $0) })
        for e in restored where byID[e.id] == nil { byID[e.id] = e }
        store.replaceAll(Array(byID.values).sorted { $0.date > $1.date })
    }

    enum ExportError: LocalizedError {
        case zipFailed, badBackup
        var errorDescription: String? {
            switch self {
            case .zipFailed: return "Couldn't create the backup file."
            case .badBackup: return "That file isn't a Voice Journal backup."
            }
        }
    }
}

// MARK: - iCloud backup (ubiquity container)

/// Automatic backup into the app's iCloud Drive container. Requires the
/// **iCloud → iCloud Documents** capability in Xcode (Signing & Capabilities).
/// Until that's enabled, `containerDocuments()` is nil and every call reports the
/// feature unavailable rather than throwing at the UI — so the app degrades cleanly.
///
/// Uses the *default* ubiquity container, so no container identifier is hardcoded:
/// whatever container you create in Xcode is the one used.
enum CloudBackup {
    private static let fm = FileManager.default
    private static let folderName = "VoiceJournal"

    /// The app's iCloud container `Documents` dir, or nil when iCloud isn't set up.
    /// - Important: this can block on first access — never call it on the main thread.
    static func containerDocuments() -> URL? {
        guard let base = fm.url(forUbiquityContainerIdentifier: nil) else { return nil }
        return base.appendingPathComponent("Documents", isDirectory: true)
    }

    static func isAvailable() -> Bool { containerDocuments() != nil }

    private static func backupRoot() -> URL? {
        containerDocuments()?.appendingPathComponent(folderName, isDirectory: true)
    }

    /// When the container's manifest was last written — i.e. the last successful backup.
    static func lastBackupDate() -> Date? {
        guard let manifest = backupRoot()?.appendingPathComponent("entries.json") else { return nil }
        return (try? fm.attributesOfItem(atPath: manifest.path)[.modificationDate]) as? Date
    }

    /// Mirror entries.json + referenced audio into iCloud (incremental copy, prunes deletions).
    static func backUp(_ entries: [VoiceEntry]) throws {
        guard let root = backupRoot() else { throw CloudError.unavailable }
        let audioDir = root.appendingPathComponent("audio", isDirectory: true)
        try fm.createDirectory(at: audioDir, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(entries)
        try coordinatedWrite(data, to: root.appendingPathComponent("entries.json"))

        // Copy any audio not already uploaded; drop audio no longer referenced.
        let wanted = Set(entries.map { $0.fileName })
        for e in entries {
            let src = Store.audioURL(e.fileName)
            let dst = audioDir.appendingPathComponent(e.fileName)
            if fm.fileExists(atPath: src.path), !fm.fileExists(atPath: dst.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
        if let existing = try? fm.contentsOfDirectory(atPath: audioDir.path) {
            for name in existing where !wanted.contains(name) {
                try? fm.removeItem(at: audioDir.appendingPathComponent(name))
            }
        }
    }

    /// Restore entries + audio from iCloud, merged by id (local edits win, cloud-only entries added).
    @MainActor
    static func restore(into store: JournalStore) throws {
        guard let root = backupRoot() else { throw CloudError.unavailable }
        let manifest = root.appendingPathComponent("entries.json")
        try? fm.startDownloadingUbiquitousItem(at: manifest)     // materialize if evicted
        guard let data = try? Data(contentsOf: manifest),
              let restored = try? JSONDecoder().decode([VoiceEntry].self, from: data) else {
            throw CloudError.noBackup
        }
        let audioDir = root.appendingPathComponent("audio", isDirectory: true)
        for e in restored {
            let src = audioDir.appendingPathComponent(e.fileName)
            try? fm.startDownloadingUbiquitousItem(at: src)
            let dst = Store.audioURL(e.fileName)
            if fm.fileExists(atPath: src.path), !fm.fileExists(atPath: dst.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
        var byID = Dictionary(uniqueKeysWithValues: store.entries.map { ($0.id, $0) })
        for e in restored where byID[e.id] == nil { byID[e.id] = e }
        store.replaceAll(Array(byID.values).sorted { $0.date > $1.date })
    }

    private static func coordinatedWrite(_ data: Data, to url: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordErr: NSError?
        var writeErr: Error?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordErr) { dst in
            do { try data.write(to: dst, options: .atomic) } catch { writeErr = error }
        }
        if let coordErr { throw coordErr }
        if let writeErr { throw writeErr }
    }

    enum CloudError: LocalizedError {
        case unavailable, noBackup
        var errorDescription: String? {
            switch self {
            case .unavailable: return "iCloud isn't set up for Voice Journal. Turn on iCloud Drive in Settings, then enable iCloud for this app."
            case .noBackup:    return "No iCloud backup found yet. Back up first, then you can restore."
            }
        }
    }
}

// MARK: - Minimal ZIP reader (no dependencies)

/// Reads STORE/DEFLATE zip entries by parsing the central directory. Enough to restore our own backups.
enum Zip {
    struct File { let name: String; let data: Data }

    static func read(_ url: URL) throws -> [File] {
        let data = try Data(contentsOf: url)
        let bytes = [UInt8](data)
        let n = bytes.count

        func u16(_ i: Int) -> Int { Int(bytes[i]) | (Int(bytes[i + 1]) << 8) }
        func u32(_ i: Int) -> Int { Int(bytes[i]) | (Int(bytes[i+1]) << 8) | (Int(bytes[i+2]) << 16) | (Int(bytes[i+3]) << 24) }

        // Locate End Of Central Directory (0x06054b50), scanning backwards.
        var eocd = -1
        var i = n - 22
        while i >= 0 {
            if u32(i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw Exporter.ExportError.badBackup }
        let count = u16(eocd + 10)
        var offset = u32(eocd + 16)   // start of central directory

        var out: [File] = []
        for _ in 0..<count {
            guard offset + 46 <= n, u32(offset) == 0x02014b50 else { break }
            let method = u16(offset + 10)
            let compSize = u32(offset + 20)
            let uncompSize = u32(offset + 24)
            let nameLen = u16(offset + 28)
            let extraLen = u16(offset + 30)
            let commentLen = u16(offset + 32)
            let localOffset = u32(offset + 42)
            let nameStart = offset + 46
            let name = String(bytes: bytes[nameStart..<nameStart + nameLen], encoding: .utf8) ?? ""
            offset = nameStart + nameLen + extraLen + commentLen

            // Read the local header to find where the file data begins.
            guard localOffset + 30 <= n, u32(localOffset) == 0x04034b50 else { continue }
            let lNameLen = u16(localOffset + 26)
            let lExtraLen = u16(localOffset + 28)
            let dataStart = localOffset + 30 + lNameLen + lExtraLen
            guard dataStart + compSize <= n else { continue }
            let comp = Data(bytes[dataStart..<dataStart + compSize])

            if name.hasSuffix("/") { continue }            // directory entry
            let content: Data
            if method == 0 { content = comp }               // stored
            else if method == 8 { content = inflate(comp, expected: uncompSize) ?? Data() }
            else { continue }
            out.append(File(name: name, data: content))
        }
        return out
    }

    /// Raw DEFLATE decode (ZIP method 8) via the Compression framework.
    private static func inflate(_ data: Data, expected: Int) -> Data? {
        guard expected > 0 else { return Data() }
        return data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Data? in
            guard let base = src.bindMemory(to: UInt8.self).baseAddress else { return nil }
            let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: expected)
            defer { dst.deallocate() }
            let written = compression_decode_buffer(dst, expected, base, data.count, nil, COMPRESSION_ZLIB)
            guard written > 0 else { return nil }
            return Data(bytes: dst, count: written)
        }
    }
}
