//
// 
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
// OnlineSearchClient.swift
// gameshelf

import Foundation

enum OnlineSearchClient {
    
    /// Söker efter spel via IGDBService. Returnerar mock-data vid nätverksfel eller saknade resultat.
    static func searchGames(matching query: String) async -> [IGDBGame] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        do {
            let results = try await IGDBService.shared.searchGames(query: trimmedQuery)
            return results.isEmpty ? mockSearch(query: trimmedQuery) : results
        } catch {
            print("⚠️ IGDB-sökning misslyckades: \(error.localizedDescription). Använder mock-data.")
            return mockSearch(query: trimmedQuery)
        }
    }
    
    /// Hjälpfunktion för att hämta det första matchande IGDB-ID:t för en titel
    static func firstID(for title: String) async -> Int? {
        let results = await searchGames(matching: title)
        return results.first?.id
    }
    
    // MARK: - Mock Fallback (Körs vid nätverksfel eller i offline-läge)
        private static func mockSearch(query: String) -> [IGDBGame] {
            let mockGames: [IGDBGame] = [
                IGDBGame(id: 1, name: "The Legend of Zelda: Tears of the Kingdom", summary: "Ett storslaget äventyr i Hyrule.", firstReleaseDate: 1683849600, cover: nil, platforms: nil, genres: nil, totalRating: 96.0),
                IGDBGame(id: 2, name: "Elden Ring", summary: "Utforska The Lands Between.", firstReleaseDate: 1645747200, cover: nil, platforms: nil, genres: nil, totalRating: 94.0),
                IGDBGame(id: 3, name: "Cyberpunk 2077", summary: "Äventyr i Night City.", firstReleaseDate: 1607558400, cover: nil, platforms: nil, genres: nil, totalRating: 82.0),
                IGDBGame(id: 4, name: "Super Mario Odyssey", summary: "Ett 3D-plattformsäventyr.", firstReleaseDate: 1509062400, cover: nil, platforms: nil, genres: nil, totalRating: 97.0),
                IGDBGame(id: 5, name: "God of War Ragnarök", summary: "Kratos och Atreus resa.", firstReleaseDate: 1667952000, cover: nil, platforms: nil, genres: nil, totalRating: 92.0)
            ]
            
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return mockGames }
            return mockGames.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        }
}
