//
//  SmartSearchEngine.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-10-08.
//

import Foundation
import SwiftUI

/// Representerar ett dynamiskt och personligt förslag för sökskärmen
struct SmartSearchSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let accentColor: Color
    let config: SearchFilterConfig

    static func == (lhs: SmartSearchSuggestion, rhs: SmartSearchSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

/// Genererar dynamiska och intelligenta sökförslag baserat på användarens faktiska bibliotek och profil
enum SmartSearchEngine {

    /// Mappning från plattformsnamn till IGDB ID
    private static let platformNameToIGDBID: [String: Int] = [
        "playstation 5": 167,
        "ps5": 167,
        "playstation 4": 48,
        "ps4": 48,
        "playstation 3": 9,
        "ps3": 9,
        "xbox series x/s": 169,
        "xbox series x": 169,
        "xbox series": 169,
        "xbox one": 49,
        "nintendo switch": 130,
        "switch": 130,
        "pc": 6,
        "pc (windows)": 6,
        "pc (microsoft windows)": 6
    ]

    /// Genererar 4–6 skräddarsydda sökförslag
    static func generateSuggestions(games: [Game], profile: ProfileStore) -> [SmartSearchSuggestion] {
        var suggestions: [SmartSearchSuggestion] = []

        // 1. ALLTID: Hetaste just nu (dagsaktuella heta släpp)
        suggestions.append(
            SmartSearchSuggestion(
                id: "trending",
                title: "Hetaste just nu 🔥",
                subtitle: "Nyutgivna titlar med hög hype",
                iconName: "flame.fill",
                accentColor: .orange,
                config: SearchFilterConfig(sortOption: .releaseDateDesc)
            )
        )

        // 2. DYNAMISK GENRE: Baserat på vad användaren spelar mest eller har angett i profilen
        if let topGenre = resolveTopGenre(games: games, profile: profile) {
            let cleanGenreTitle = topGenre == "Role-playing (RPG)" ? "RPG" : topGenre
            suggestions.append(
                SmartSearchSuggestion(
                    id: "genre_\(topGenre.lowercased())",
                    title: "Bästa \(cleanGenreTitle)-spelen 🏆",
                    subtitle: "Topprankade titlar inom din favoritgenre",
                    iconName: "trophy.fill",
                    accentColor: .purple,
                    config: SearchFilterConfig(
                        genres: [topGenre],
                        minRating: 80,
                        sortOption: .rating
                    )
                )
            )
        }

        // 3. DYNAMISK PLATTFORM: Baserat på användarens mest ägda konsol eller primära profilplattform
        if let (platName, platID) = resolveTopPlatform(games: games, profile: profile) {
            suggestions.append(
                SmartSearchSuggestion(
                    id: "platform_\(platID)",
                    title: "Toppspel till \(platName) 🎮",
                    subtitle: "Högst betyg till din favoritplattform",
                    iconName: "gamecontroller.fill",
                    accentColor: .blue,
                    config: SearchFilterConfig(
                        platformIDs: [platID],
                        minRating: 80,
                        sortOption: .rating
                    )
                )
            )
        }

        // 4. TIDLÖSA MÄSTERVERK (90+ i betyg)
        suggestions.append(
            SmartSearchSuggestion(
                id: "masterpieces",
                title: "Mästerverk (90+) ⭐",
                subtitle: "De absolut högst rankade spelen genom tiderna",
                iconName: "star.fill",
                accentColor: .yellow,
                config: SearchFilterConfig(
                    minRating: 90,
                    sortOption: .rating
                )
            )
        )

        // 5. SNABBA UPPLEVELSER: Korta mästerverk (< 10 timmar)
        suggestions.append(
            SmartSearchSuggestion(
                id: "short_gems",
                title: "Korta pärlor (< 10h) ⏱️",
                subtitle: "Perfekt när du vill hinna spela klart i helgen",
                iconName: "timer",
                accentColor: .green,
                config: SearchFilterConfig(
                    minRating: 78,
                    sortOption: .rating,
                    playtimeFilter: .short
                )
            )
        )

        // 6. DOLDA PÄRLOR & INDIE: Hög kvalitet med lägre hype
        suggestions.append(
            SmartSearchSuggestion(
                id: "hidden_gems",
                title: "Dolda pärlor 💎",
                subtitle: "Kritikerhyllade skatter du kan ha missat",
                iconName: "sparkles",
                accentColor: .cyan,
                config: SearchFilterConfig(
                    genres: ["Indie"],
                    minRating: 80,
                    sortOption: .rating
                )
            )
        )

        return suggestions
    }

    // MARK: - Privata hjälpfunktioner för analys

    /// Hittar användarens starkaste genre från biblioteket och profilen
    private static func resolveTopGenre(games: [Game], profile: ProfileStore) -> String? {
        var counts: [String: Int] = [:]

        // Räkna genrer i ägda spel (med extra tyngd för spel med högt betyg)
        for g in games where g.isOwned {
            let weight = (g.rating ?? 0) >= 8 ? 3 : 1
            for genre in g.genres where !genre.isEmpty {
                counts[genre, default: 0] += weight
            }
        }

        // Lägg till vikt från sparade profilfavoriter
        for favGenre in profile.favoriteGenres where !favGenre.isEmpty {
            counts[favGenre, default: 0] += 5
        }

        guard let top = counts.sorted(by: { $0.value > $1.value }).first?.key else {
            return "Role-playing (RPG)" // Tidlös standardfallback
        }

        return top
    }

    /// Hittar användarens primära konsol/plattform och motsvarande IGDB ID
    private static func resolveTopPlatform(games: [Game], profile: ProfileStore) -> (name: String, id: Int)? {
        var counts: [String: Int] = [:]

        // 1. Räkna plattformar från biblioteket
        for g in games where g.isOwned {
            for plat in g.platforms where !plat.isEmpty {
                counts[plat, default: 0] += 1
            }
        }

        // 2. Om biblioteket har plattformar med IGDB ID-mappning
        let sortedPlatforms = counts.sorted { $0.value > $1.value }
        for (candidate, _) in sortedPlatforms {
            let lower = candidate.lowercased()
            if let igdbID = platformNameToIGDBID[lower] ?? platformNameToIGDBID.first(where: { lower.contains($0.key) })?.value {
                return (shortPlatformName(candidate), igdbID)
            }
        }

        // 3. Annars från profilen
        for userPlat in profile.platforms {
            let lower = userPlat.lowercased()
            if let igdbID = platformNameToIGDBID[lower] ?? platformNameToIGDBID.first(where: { lower.contains($0.key) })?.value {
                return (shortPlatformName(userPlat), igdbID)
            }
        }

        return ("PlayStation 5", 167)
    }

    private static func shortPlatformName(_ full: String) -> String {
        let lower = full.lowercased()
        if lower.contains("playstation 5") || lower == "ps5" { return "PS5" }
        if lower.contains("playstation 4") || lower == "ps4" { return "PS4" }
        if lower.contains("nintendo switch") || lower == "switch" { return "Switch" }
        if lower.contains("xbox series") { return "Xbox Series" }
        if lower.contains("xbox one") { return "Xbox One" }
        if lower.contains("pc") || lower.contains("windows") { return "PC" }
        return full
    }
}
