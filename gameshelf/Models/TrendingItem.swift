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
}

@MainActor
final class TrendingFetcher: ObservableObject {
    @Published var items: [TrendingItem] = []
    @Published var isLoading = false

    func fetch(platformFamilies: [String], news: [NewsItem]? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let games = try await IGDBService.shared.fetchTrendingGames(
                platformIDs: Self.platformIDs(forFamilies: platformFamilies)
            )
            items = games.map { game in
                TrendingItem(
                    id: game.id,
                    title: game.name,
                    platformText: game.platforms?.map(\.name).prefix(2).joined(separator: ", ") ?? "",
                    rating: (game.totalRating ?? 0) / 10,
                    image: game.coverURL
                )
            }
        } catch {
            items = []
        }
    }

    /// IGDB:s plattforms-id:n, inte de gamla RAWG-id:n.
    static func platformIDs(forFamilies families: [String]) -> [Int] {
        var ids = Set<Int>()
        for family in families.map({ $0.lowercased() }) {
            if family.contains("playstation 5") { ids.insert(167) }
            else if family.contains("playstation") { ids.formUnion([48, 167]) }
            if family.contains("xbox series") { ids.insert(169) }
            else if family.contains("xbox") { ids.formUnion([49, 169]) }
            if family.contains("nintendo") || family.contains("switch") { ids.insert(130) }
            if family.contains("pc") { ids.insert(6) }
            if family.contains("mobile") { ids.formUnion([34, 39]) }
        }
        return ids.sorted()
    }
}
