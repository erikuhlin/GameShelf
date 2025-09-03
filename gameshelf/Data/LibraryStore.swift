//
//  LibraryStore.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI
import Combine

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
            self.games = SampleData.games
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
            self.games = SampleData.games
            return
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        self.games = try decoder.decode([Game].self, from: data)
    }

    // Gruppindelning per plattform (för hyllvy)
    var shelvesByPlatform: [Shelf] {
        let groups = Dictionary(grouping: games, by: { $0.platform })
        return groups.keys.sorted().map { key in
            Shelf(title: key, games: groups[key]!.sorted { $0.title < $1.title })
        }
    }
}

struct Shelf: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var games: [Game]
}
