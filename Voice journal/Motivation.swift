//  Motivation.swift — Voice Journal
//  Daily motivation via the ZenQuotes API (https://zenquotes.io) with an offline local fallback.
//
//  Only a plain GET is sent — no journal data ever leaves the device. If the network is
//  unavailable the card falls back to the bundled `Motivation` pack.

import SwiftUI
import Combine

struct MotivationQuote: Codable, Equatable {
    var text: String
    var author: String

    /// Offline fallback drawn from the bundled pack.
    static var fallback: MotivationQuote { MotivationQuote(text: Motivation.today(), author: "") }
}

@MainActor
final class MotivationService: ObservableObject {
    @Published var quote: MotivationQuote = .fallback
    @Published var loading = false
    @Published var isOffline = false

    private let cacheKey = "vj_motiv_cache"
    private let dateKey  = "vj_motiv_date"
    private let base = "https://zenquotes.io/api"

    /// Load today's quote: cached copy if we already fetched today, otherwise the API's "quote of the day".
    func loadDaily() {
        if UserDefaults.standard.string(forKey: dateKey) == Self.dayString(),
           let data = UserDefaults.standard.data(forKey: cacheKey),
           let q = try? JSONDecoder().decode(MotivationQuote.self, from: data) {
            quote = q
            return
        }
        fetch(path: "today", persistForToday: true)
    }

    /// User tapped refresh → a fresh random quote (not persisted as today's).
    func shuffle() { fetch(path: "random", persistForToday: false) }

    private func fetch(path: String, persistForToday: Bool) {
        guard !loading, let url = URL(string: "\(base)/\(path)") else { return }
        loading = true
        Task {
            defer { loading = false }
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 10
                let (data, _) = try await URLSession.shared.data(for: req)
                guard let first = try? JSONDecoder().decode([ZenQuote].self, from: data).first,
                      !first.q.isEmpty else { throw URLError(.cannotParseResponse) }
                let q = MotivationQuote(text: first.q.trimmingCharacters(in: .whitespaces), author: first.a)
                self.quote = q
                self.isOffline = false
                if persistForToday {
                    UserDefaults.standard.set(Self.dayString(), forKey: dateKey)
                    if let d = try? JSONEncoder().encode(q) { UserDefaults.standard.set(d, forKey: cacheKey) }
                }
            } catch {
                self.isOffline = true
                if self.quote.text.isEmpty { self.quote = .fallback }
            }
        }
    }

    private struct ZenQuote: Codable { let q: String; let a: String }

    private static func dayString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
}

// MARK: - Card

struct MotivationCard: View {
    @ObservedObject var service: MotivationService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max").font(.system(size: 12, weight: .semibold)).foregroundColor(Paper.terra)
                    Text("Daily motivation").eyebrow()
                }
                Spacer()
                Button {
                    HX.tap(); service.shuffle()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Paper.terra)
                        .rotationEffect(.degrees(service.loading ? 360 : 0))
                        .animation(service.loading ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default,
                                   value: service.loading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New motivation")
            }

            Text("\u{201C}\(service.quote.text)\u{201D}")
                .font(Typo.serifItalic(18))
                .foregroundColor(Paper.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !service.quote.author.isEmpty {
                Text("— \(service.quote.author)")
                    .font(Typo.sans(13, .medium))
                    .foregroundColor(Paper.ink3)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(22, fill: Paper.cardAlt)
    }
}
