//  Storage.swift — Voice Journal
//  File-based persistence, Markdown/zip export, backup & restore.

import Foundation
import Compression

// MARK: - Store (file-based persistence)

nonisolated enum Store {
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

    /// Resolve only a plain file name inside Documents. Imported/legacy JSON is untrusted: an
    /// empty name or `../` path must never turn an entry deletion into a directory deletion.
    static func safeAudioURL(_ name: String) -> URL? {
        let leaf = (name as NSString).lastPathComponent
        guard !leaf.isEmpty, leaf != ".", leaf != "..", leaf == name else { return nil }
        return docsDir.appendingPathComponent(leaf)
    }

    static func audioURL(_ name: String) -> URL {
        safeAudioURL(name) ?? docsDir.appendingPathComponent(".invalid-audio-file")
    }

    static func removeAudio(named name: String) {
        guard let url = safeAudioURL(name), fm.fileExists(atPath: url.path) else { return }
        try? fm.removeItem(at: url)
    }

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

nonisolated enum Exporter {
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
        var s = "## \(filled(L(e.title)) ?? L("Untitled entry"))\(e.isFavorite ? " ★" : "")\n\n"
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

    /// Save the same portable zip into the app's local Documents folder so it stays
    /// on this device and can be restored later.
    static func saveDeviceBackup(_ entries: [VoiceEntry]) throws -> URL {
        let zip = try backupZip(entries)
        let dir = Store.docsDir.appendingPathComponent("Voice Journal Backups", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let name = "VoiceJournal-Backup-\(formatter.string(from: Date())).zip"
        let dest = dir.appendingPathComponent(name)

        try? fm.removeItem(at: dest)
        try fm.copyItem(at: zip, to: dest)
        return dest
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

    /// Parse a backup zip and restore its audio, returning the decoded entries for the
    /// caller to merge into the store. Reads + inflates the whole archive, so this is
    /// deliberately `nonisolated` — run it off the main thread (a large backup would
    /// otherwise hang the UI). The caller merges the result via `JournalStore.mergeIn`.
    nonisolated static func importBackup(from zipURL: URL) throws -> [VoiceEntry] {
        let needsScope = zipURL.startAccessingSecurityScopedResource()
        defer { if needsScope { zipURL.stopAccessingSecurityScopedResource() } }

        let files = try Zip.read(zipURL)
        guard let entriesData = files.first(where: { $0.name.hasSuffix("entries.json") })?.data,
              let restored = try? JSONDecoder().decode([VoiceEntry].self, from: entriesData),
              restored.allSatisfy({ Store.safeAudioURL($0.fileName) != nil })
        else { throw ExportError.badBackup }

        // Restore audio files (skip any already present).
        for f in files where f.name.hasSuffix(".m4a") {
            let parent = ((f.name as NSString).deletingLastPathComponent as NSString).lastPathComponent
            guard parent == "audio" else { continue }
            let name = (f.name as NSString).lastPathComponent
            guard let dest = Store.safeAudioURL(name) else { throw ExportError.badBackup }
            if !fm.fileExists(atPath: dest.path) { try f.data.write(to: dest, options: .atomic) }
        }
        return restored
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

// MARK: - Minimal ZIP reader (no dependencies)

/// Reads STORE/DEFLATE zip entries by parsing the central directory. Enough to restore our own backups.
nonisolated enum Zip {
    struct File { let name: String; let data: Data }
    private static let maxInflatedEntrySize = 512 * 1_024 * 1_024

    static func read(_ url: URL) throws -> [File] {
        let data = try Data(contentsOf: url)
        let bytes = [UInt8](data)
        let n = bytes.count

        func u16(_ i: Int) -> Int { Int(bytes[i]) | (Int(bytes[i + 1]) << 8) }
        func u32(_ i: Int) -> Int { Int(bytes[i]) | (Int(bytes[i+1]) << 8) | (Int(bytes[i+2]) << 16) | (Int(bytes[i+3]) << 24) }

        // Locate End Of Central Directory (0x06054b50). The ZIP comment is at most 65,535
        // bytes, so avoid scanning a multi-gigabyte audio backup from end to beginning.
        guard n >= 22 else { throw Exporter.ExportError.badBackup }
        var eocd = -1
        var i = n - 22
        let lowerBound = max(0, i - 65_535)
        while i >= lowerBound {
            if u32(i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw Exporter.ExportError.badBackup }
        let count = u16(eocd + 10)
        var offset = u32(eocd + 16)   // start of central directory

        var out: [File] = []
        for _ in 0..<count {
            guard offset <= n - 46, u32(offset) == 0x02014b50 else {
                throw Exporter.ExportError.badBackup
            }
            let method = u16(offset + 10)
            let compSize = u32(offset + 20)
            let uncompSize = u32(offset + 24)
            let nameLen = u16(offset + 28)
            let extraLen = u16(offset + 30)
            let commentLen = u16(offset + 32)
            let localOffset = u32(offset + 42)
            let nameStart = offset + 46
            let nameEnd = nameStart + nameLen
            let nextOffset = nameEnd + extraLen + commentLen
            guard nameEnd <= n, nextOffset <= n,
                  let name = String(bytes: bytes[nameStart..<nameEnd], encoding: .utf8),
                  !name.isEmpty else { throw Exporter.ExportError.badBackup }
            offset = nextOffset

            // Read the local header to find where the file data begins.
            guard localOffset <= n - 30, u32(localOffset) == 0x04034b50 else {
                throw Exporter.ExportError.badBackup
            }
            let lNameLen = u16(localOffset + 26)
            let lExtraLen = u16(localOffset + 28)
            let dataStart = localOffset + 30 + lNameLen + lExtraLen
            guard dataStart <= n, compSize <= n - dataStart else {
                throw Exporter.ExportError.badBackup
            }
            let comp = Data(bytes[dataStart..<(dataStart + compSize)])

            if name.hasSuffix("/") { continue }            // directory entry
            let content: Data
            if method == 0 {
                guard comp.count == uncompSize else { throw Exporter.ExportError.badBackup }
                content = comp
            } else if method == 8 {
                guard uncompSize <= maxInflatedEntrySize,
                      let inflated = inflate(comp, expected: uncompSize),
                      inflated.count == uncompSize else { throw Exporter.ExportError.badBackup }
                content = inflated
            } else {
                continue
            }
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
