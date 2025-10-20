//
//  LibraryStore.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//


import SwiftUI
import Combine

// MARK: - Legacy model migration (platform/developer changed to arrays)
private struct LegacyGame: Decodable {
    var id: UUID?
    var title: String
    var platform: String
    var releaseYear: Int
    var genres: [String]
    var developer: String
    var status: PlayStatus
    var rating: Int?
    var coverURL: URL?
}

private func migrateLegacy(_ legacy: [LegacyGame]) -> [Game] {
    legacy.map { old in
        Game(
            title: old.title,
            platforms: old.platform.isEmpty ? [] : [old.platform],
            releaseYear: old.releaseYear,
            genres: old.genres,
            developers: old.developer.isEmpty ? [] : [old.developer],
            status: old.status,
            rating: old.rating,
            rawgRating: nil,
            coverURL: old.coverURL,
            notes: ""
        )
    }
}

@MainActor
final class LibraryStore: ObservableObject {
    @Published var games: [Game] = [] {
        didSet {
            guard isLoaded else { return }
            try? save()
        }
    }

    private var isLoaded = false
    private let fileName = "library.json"

    init() {
        do {
            try load()
            isLoaded = true
        } catch {
            // Om laddning misslyckas, fyll med sample och spara
            self.games = []
            isLoaded = true
            try? save()
        }
    }

    // MARK: - Public API
    func add(_ game: Game) {
        games.insert(game, at: 0)
    }

    func delete(_ game: Game) {
        if let idx = games.firstIndex(of: game) {
            games.remove(at: idx)
        }
    }

    func delete(at offsets: IndexSet) {
        games.remove(atOffsets: offsets)
    }

    // MARK: - Persistence (JSON)
    private func documentsURL() throws -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let url = urls.first else { throw CocoaError(.fileNoSuchFile) }
        return url
    }

    private func dataURL() throws -> URL {
        // Use a simple path without UniformTypeIdentifiers to avoid extra imports
        return try documentsURL().appendingPathComponent(fileName)
    }

    func save() throws {
        let url = try dataURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(games)
        try data.write(to: url, options: .atomic)
    }

    func load() throws {
        let url = try dataURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            self.games = []
            return
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        do {
            self.games = try decoder.decode([Game].self, from: data)
        } catch {
            // Try legacy decode and migrate
            if let legacy = try? decoder.decode([LegacyGame].self, from: data) {
                self.games = migrateLegacy(legacy)
                // Persist immediately in new format
                try? save()
            } else {
                throw error
            }
        }
    }

    // Gruppindelning per plattform (för hyllvy)
    var shelvesByPlatform: [Shelf] {
        // Expand each game into (platform, game) pairs so multi-platform spel hamnar på flera hyllor
        let pairs: [(String, Game)] = games.flatMap { g in
            let names = g.platforms.isEmpty ? ["Unspecified"] : g.platforms
            return names.map { ($0, g) }
        }
        let groups = Dictionary(grouping: pairs, by: { $0.0 })
        let keys = groups.keys.sorted()
        return keys.map { key in
            let items = groups[key]!.map { $0.1 }.sorted { $0.title < $1.title }
            return Shelf(title: key, games: items)
        }
    }
}

struct Shelf: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var games: [Game]
}
