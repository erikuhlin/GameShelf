//
//  TrendingItem.swift
//  Gameshelf
//

import SwiftUI
import Combine

struct TrendingItem: Identifiable, Hashable {
    let id: Int
    let title: String
    let platformText: String
    /// IGDB:s betyg på skalan 0–10.
    let rating: Double
    let image: URL?
    var badgeText: String? = nil
}

@MainActor
final class TrendingFetcher: ObservableObject {
    @Published var items: [TrendingItem] = []
    @Published var isLoading = false
    private var lastFetched: Date? = nil
    private var lastPlatforms: [String] = []

    func fetch(platformFamilies: [String], news: [NewsItem]? = nil, forceReload: Bool = false) async {
        // Om vi hämtat nyligen (inom 5 minuter) för samma plattformar och inte forcerar omladdning, behåll cachen
        if !forceReload, let last = lastFetched, Date().timeIntervalSince(last) < 300, lastPlatforms == platformFamilies, !items.isEmpty {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let results = try await IGDBService.shared.fetchTrendingGamesWithDetails(
                platformIDs: Self.platformIDs(forFamilies: platformFamilies)
            )

            // Extrahera spel som omnämns i färska nyheter / recensioner
            let newsTitles = Set(news?.compactMap { $0.matchedGameTitle?.lowercased() } ?? [])
            let reviewTitles = Set(news?.filter { $0.kind == .review }.compactMap { $0.matchedGameTitle?.lowercased() } ?? [])

            let now = Int(Date().timeIntervalSince1970)

            items = results.map { res in
                let game = res.game
                let normTitle = game.name.lowercased()
                let ratingVal = (game.totalRating ?? 0) / 10
                let isUpcoming = (game.firstReleaseDate ?? 0) > now

                // Dagsaktuella, informativa badges baserat på faktiska realtids-mätpunkter
                let badge: String
                if reviewTitles.contains(where: { normTitle.contains($0) || $0.contains(normTitle) }) {
                    badge = "⭐ Topprecension"
                } else if newsTitles.contains(where: { normTitle.contains($0) || $0.contains(normTitle) }) {
                    badge = "📰 I Mediefokus"
                } else if isUpcoming || res.primarySourceType == 10 {
                    badge = "🚀 Efterlängtat"
                } else {
                    switch res.primarySourceType {
                    case 9:
                        badge = "🏆 Toppsäljare"
                    case 10:
                        badge = "🚀 Efterlängtat"
                    case 34:
                        badge = "🔴 Het på Twitch"
                    case 1:
                        badge = "🔥 Söktrend idag"
                    case 5:
                        badge = "👥 Mest spelat idag"
                    case 2:
                        badge = "✨ Önskelistas"
                    case 3:
                        badge = "🎮 Spelas nu"
                    default:
                        if ratingVal >= 8.5 {
                            badge = "⭐ \(String(format: "%.1f", ratingVal)) Betyg"
                        } else {
                            badge = "🔥 Trendar just nu"
                        }
                    }
                }

                return TrendingItem(
                    id: game.id,
                    title: game.name,
                    platformText: game.platforms?.map(\.name).prefix(2).joined(separator: ", ") ?? "",
                    rating: ratingVal,
                    image: game.coverURL,
                    badgeText: badge
                )
            }
            lastFetched = Date()
            lastPlatforms = platformFamilies
        } catch {
            items = []
        }
    }

    /// IGDB:s plattforms-id:n, inte de gamla RAWG-id:n.
    static func platformIDs(forFamilies families: [String]) -> [Int] {
        var ids = Set<Int>()
        for raw in families {
            let family = raw.lowercased()
            if family.contains("playstation 5") || family.contains("ps5") {
                ids.insert(167)
            } else if family.contains("playstation 4") || family.contains("ps4") {
                ids.insert(48)
            } else if family.contains("playstation") {
                ids.formUnion([167, 48, 9, 8, 7])
            }

            if family.contains("xbox series") || family.contains("series x") || family.contains("series s") {
                ids.insert(169)
            } else if family.contains("xbox one") {
                ids.insert(49)
            } else if family.contains("xbox") {
                ids.formUnion([169, 49, 12, 11])
            }

            if family.contains("switch 2") {
                ids.insert(508)
            }
            if family.contains("nintendo") || family.contains("switch") {
                ids.formUnion([130, 508, 4, 18, 19, 21, 37])
            }

            if family.contains("pc") || family.contains("windows") || family.contains("steam") {
                ids.insert(6)
            }
            if family.contains("mac") {
                ids.insert(14)
            }
            if family.contains("ios") || family.contains("iphone") || family.contains("ipad") {
                ids.insert(39)
            }
        }
        return ids.sorted()
    }
}
