//  Cloud.swift — Voice Journal
//  Drives iCloud backup status + automatic/manual backup & restore.

import SwiftUI
import Combine

@MainActor
final class CloudBackupManager: ObservableObject {
    enum Phase: Equatable { case idle, working, done, unavailable, failed(String) }

    @Published var available = false
    @Published var lastBackup: Date?
    @Published var phase: Phase = .idle

    private var bag = Set<AnyCancellable>()
    private weak var store: JournalStore?
    private weak var settings: AppSettings?

    /// Wire up status + debounced auto-backup. Safe to call once from the app shell.
    func attach(store: JournalStore, settings: AppSettings) {
        guard self.store == nil else { return }
        self.store = store
        self.settings = settings
        refresh()
        // Auto-backup: coalesce bursts of edits into one upload a few seconds after they settle.
        store.$entries
            .dropFirst()
            .debounce(for: .seconds(8), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.settings?.iCloudBackup == true else { return }
                self.backUpNow(silent: true)
            }
            .store(in: &bag)
    }

    /// Re-check availability + last-backup time (container lookup blocks, so do it off-main).
    func refresh() {
        Task.detached {
            let ok = CloudBackup.isAvailable()
            let last = CloudBackup.lastBackupDate()
            await MainActor.run {
                self.available = ok
                self.lastBackup = last
                if self.phase == .idle || self.phase == .unavailable {
                    self.phase = ok ? .idle : .unavailable
                }
            }
        }
    }

    /// `silent` backups (from auto-sync) don't flip the visible phase or fire haptics.
    func backUpNow(silent: Bool = false) {
        guard let entries = store?.entries else { return }
        if entries.isEmpty { return }
        if !silent { phase = .working; HX.tap() }
        Task.detached {
            do {
                try CloudBackup.backUp(entries)
                let last = CloudBackup.lastBackupDate()
                await MainActor.run {
                    self.available = true
                    self.lastBackup = last
                    if !silent { self.phase = .done; HX.ok() }
                }
            } catch {
                let stillAvailable = CloudBackup.isAvailable()
                await MainActor.run {
                    self.available = stillAvailable
                    self.phase = stillAvailable ? .failed(error.localizedDescription) : .unavailable
                    if !silent { HX.error() }
                }
            }
        }
    }

    func restore() {
        guard let store else { return }
        phase = .working; HX.tap()
        Task {
            do {
                try CloudBackup.restore(into: store)
                self.phase = .done; HX.ok()
            } catch {
                self.phase = .failed(error.localizedDescription); HX.error()
            }
        }
    }

    /// User-facing one-liner for the status row.
    var statusText: String {
        switch phase {
        case .working:            return "Working…"
        case .failed(let m):      return m
        case .unavailable:        return "iCloud unavailable"
        case .idle, .done:
            guard available else { return "iCloud unavailable" }
            if let d = lastBackup {
                return "Last backup \(d.formatted(.relative(presentation: .named)))"
            }
            return "Ready — not backed up yet"
        }
    }
}
