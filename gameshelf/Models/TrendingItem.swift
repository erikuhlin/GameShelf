//
//  TrendingItem.swift
//  Gameshelf

import Foundation
import SwiftUI
import Combine

struct TrendingItem: Identifiable, Hashable {
    let id: Int
    let title: String
    let platformText: String
    let rating: Double
    let image: URL?
}

@MainActor
final class TrendingFetcher: ObservableObject {
    @Published var items: [TrendingItem] = []
    @Published var isLoading = false

    func fetch(platformFamilies: [String], news: [NewsItem]? = nil) async {
        isLoading = true; defer { isLoading = false }

        guard let key = Bundle.main.object(forInfoDictionaryKey: "RAWG_API_KEY") as? String, !key.isEmpty else {
            self.items = []; return
        }

        func lastDaysRange(_ days: Int) -> String {
            let cal = Calendar(identifier: .gregorian)
            let now = Date()
            let from = cal.date(byAdding: .day, value: -days, to: now) ?? now
            let f = DateFormatter()
            f.calendar = cal
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"
            return "\(f.string(from: from)),\(f.string(from: now))"
        }

        func fetchRAWG(ordering: String, days: Int) async throws -> [ExploreRawgGame] {
            var comps = URLComponents(string: "https://api.rawg.io/api/games")!
            var q: [URLQueryItem] = [
                .init(name: "key", value: key),
                .init(name: "ordering", value: ordering),
                .init(name: "page_size", value: "60"),
                .init(name: "dates", value: lastDaysRange(days)),
                .init(name: "exclude_additions", value: "true"),
                .init(name: "exclude_parents", value: "true")
            ]
            let ids = Self.platformIDs(forFamilies: platformFamilies)
            if !ids.isEmpty { q.append(.init(name: "platforms", value: ids.map(String.init).joined(separator: ","))) }
            comps.queryItems = q
            let (data, _) = try await URLSession.shared.data(from: comps.url!)
            let decoded = try JSONDecoder().decode(ExploreRawgGamesResponse.self, from: data)
            return decoded.results
        }

        // Blend multiple popularity signals: recently added, ratings volume, critic score
        do {
            async let added60  = fetchRAWG(ordering: "-added",          days: 60)
            async let rated180 = fetchRAWG(ordering: "-ratings_count",  days: 180)
            async let meta365  = fetchRAWG(ordering: "-metacritic",     days: 365)
            let (a, r, m) = try await (added60, rated180, meta365)

            struct Bucket { var g: ExploreRawgGame; var fromAdded = 0; var fromRated = 0; var fromMeta = 0 }
            var dict: [Int: Bucket] = [:]

            func ingest(_ list: [ExploreRawgGame], keyPath: WritableKeyPath<Bucket, Int>) {
                for (idx, g) in list.enumerated() {
                    if dict[g.id] == nil { dict[g.id] = Bucket(g: g) }
                    dict[g.id]![keyPath: keyPath] = idx + 1 // 1-based rank
                }
            }

            ingest(a, keyPath: \Bucket.fromAdded)
            ingest(r, keyPath: \Bucket.fromRated)
            ingest(m, keyPath: \Bucket.fromMeta)

            // Score: lower rank is better → invert via (cutoff / rank)
            // Weights tuned lightly for recency > volume > critics
            func score(_ b: Bucket) -> Double {
                let wA = 1.0, wR = 0.8, wM = 0.6
                let sA = b.fromAdded > 0 ? wA * (60.0 / Double(b.fromAdded)) : 0
                let sR = b.fromRated > 0 ? wR * (60.0 / Double(b.fromRated)) : 0
                let sM = b.fromMeta  > 0 ? wM * (60.0 / Double(b.fromMeta))  : 0
                let ratingBoost = (b.g.rating ?? 0) / 10.0
                let metaBoost = Double(b.g.metacritic ?? 0) / 100.0 * 0.3
                return sA + sR + sM + ratingBoost + metaBoost
            }

            // Map to TrendingItem and clean
            var merged: [TrendingItem] = dict.values.map { b in
                TrendingItem(
                    id: b.g.id,
                    title: b.g.name,
                    platformText: b.g.platforms?.compactMap { $0.platform?.name }.prefix(2).joined(separator: ", ") ?? "",
                    rating: b.g.rating ?? 0,
                    image: URL(string: b.g.background_image ?? "")
                )
            }

            // Basic clean-up: remove entries with no image & near-zero rating
            merged.removeAll { ($0.image == nil) && ($0.rating < 0.5) }

            // Sort by computed score
            merged.sort { lhs, rhs in
                let bl = dict[lhs.id]!
                let br = dict[rhs.id]!
                return score(bl) > score(br)
            }

            self.items = Array(merged.prefix(30))
        } catch {
            self.items = []
        }
    }

    static func platformIDs(forFamilies fams: [String]) -> [Int] {
        var set = Set<Int>()
        for f in fams.map({ $0.lowercased() }) {
            if f.contains("playstation") { set.formUnion([187, 18, 16, 15]) }
            if f.contains("xbox")       { set.formUnion([186, 1, 14]) }
            if f.contains("nintendo")   { set.formUnion([7, 8, 83, 24]) }
            if f.contains("pc")         { set.insert(4) }
            if f.contains("mobile")     { set.formUnion([3, 21]) }
        }
        return Array(set)
    }
}

// Small scoped RAWG models for decoding
struct ExploreRawgGamesResponse: Decodable { let results: [ExploreRawgGame] }
struct ExploreRawgGame: Decodable {
    let id: Int
    let name: String
    let background_image: String?
    let rating: Double?
    let ratings_count: Int?
    let metacritic: Int?
    let platforms: [ExploreRawgGamePlatform]?
}
struct ExploreRawgGamePlatform: Decodable { let platform: ExploreRawgPlatform? }
struct ExploreRawgPlatform: Decodable { let id: Int; let name: String }
