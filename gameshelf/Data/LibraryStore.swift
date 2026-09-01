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
            igdbRating: nil,
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
            try? saveGames()
        }
    }

    @Published var collections: [GameCollection] = [] {
        didSet {
            guard isLoaded else { return }
            try? saveCollections()
        }
    }

    private var isLoaded = false
    private let gamesFileName = "library.json"
    private let collectionsFileName = "collections.json"
    private var checkedGameIDsForDates = Set<UUID>()
    private var isEnrichingDates = false

    init() {
        do {
            try loadGames()
            try loadCollections()
            isLoaded = true
        } catch {
            self.games = []
            self.collections = []
            isLoaded = true
        }

        // Initiera anonym auth, synk och berika saknade releasedatum i bakgrunden
        Task { [weak self] in
            await SupabaseAuthManager.shared.ensureAnonymousAuth()
            await self?.syncWithRemote()
            await self?.enrichMissingReleaseDates()
        }
    }

    // MARK: - Remote Synchronization
    func syncWithRemote() async {
        guard SupabaseConfig.isSyncEnabled else { return }

        let initialMigrationKey = "has_migrated_legacy_local_games_to_supabase"
        let isFirstSync = !UserDefaults.standard.bool(forKey: initialMigrationKey)

        // Engångsmigrering av befintliga lokala spel vid allra första anslutningen
        if isFirstSync && !self.games.isEmpty {
            for game in self.games {
                try? await SupabaseSyncService.shared.upsertGame(game)
            }
            for col in self.collections {
                try? await SupabaseSyncService.shared.upsertCollection(col)
            }
            UserDefaults.standard.set(true, forKey: initialMigrationKey)
        }

        // 1. Synka spel från servern (speglar direkt tillägg och raderingar)
        do {
            let remoteGames = try await SupabaseSyncService.shared.fetchRemoteGames()
            if !remoteGames.isEmpty || self.games.isEmpty {
                self.games = remoteGames
            } else {
                for game in self.games {
                    try? await SupabaseSyncService.shared.upsertGame(game)
                }
            }
            UserDefaults.standard.set(true, forKey: initialMigrationKey)
        } catch {
            // Ignorera offline / nätverksfel så lokal data fortsätter fungera
        }

        // 2. Synka samlingar från servern
        do {
            let remoteCollections = try await SupabaseSyncService.shared.fetchRemoteCollections()
            self.collections = remoteCollections
        } catch {
            // Ignorera nätverksfel
        }

        // 3. Berika befintliga spel som saknar releasedatum i bakgrunden
        await enrichMissingReleaseDates()
    }

    // MARK: - Release Date Background Enrichment
    private func enrichMissingReleaseDates() async {
        guard !isEnrichingDates else { return }
        isEnrichingDates = true
        defer { isEnrichingDates = false }

        while true {
            let gamesNeedingDates = self.games.filter { $0.firstReleaseDate == nil && !checkedGameIDsForDates.contains($0.id) }
            guard !gamesNeedingDates.isEmpty else { break }

            var updatedBatch: [Game] = []

            // Bearbeta max 8 spel per batch med 260ms paus för att respektera IGDB:s rate limit (max 4 req/s)
            for game in gamesNeedingDates.prefix(8) {
                checkedGameIDsForDates.insert(game.id)
                do {
                    try? await Task.sleep(nanoseconds: 260_000_000)

                    if let igdbId = game.igdbID {
                        let detail = try await IGDBService.shared.fetchGameDetails(id: igdbId)
                        if let date = detail.firstReleaseDate {
                            var updated = game
                            updated.firstReleaseDate = date
                            if let year = detail.releaseYear {
                                updated.releaseYear = year
                            }
                            updatedBatch.append(updated)
                        }
                    } else {
                        var results = try await IGDBService.shared.searchGames(query: game.title)
                        if results.isEmpty {
                            let cleaned = GameAliasResolver.cleanGameTitle(game.title)
                            if cleaned != game.title && !cleaned.isEmpty {
                                results = (try? await IGDBService.shared.searchGames(query: cleaned)) ?? []
                            }
                        }
                        if let first = results.first(where: { $0.firstReleaseDate != nil }) {
                            var updated = game
                            updated.firstReleaseDate = first.firstReleaseDate
                            updated.igdbID = first.id
                            if let year = first.releaseYear {
                                updated.releaseYear = year
                            }
                            updatedBatch.append(updated)
                        }
                    }
                } catch {
                    // Fortsätt tyst till nästa
                }
            }

            // Tillämpa alla uppdateringar i batch så listan inte hoppar
            if !updatedBatch.isEmpty {
                for updated in updatedBatch {
                    if let idx = self.games.firstIndex(where: { $0.id == updated.id }) {
                        self.games[idx] = updated
                    }
                }
                for updated in updatedBatch {
                    Task {
                        try? await SupabaseSyncService.shared.upsertGame(updated)
                    }
                }
            }
        }
    }

    // MARK: - Game Public API
    func add(_ game: Game) {
        games.insert(game, at: 0)
        Task {
            try? await SupabaseSyncService.shared.upsertGame(game)
            if game.firstReleaseDate == nil {
                await enrichMissingReleaseDates()
            }
        }
    }

    func delete(_ game: Game) {
        let gameId = game.id
        if let idx = games.firstIndex(of: game) {
            games.remove(at: idx)
            removeGameFromAllCollections(gameId)
        }
        Task {
            try? await SupabaseSyncService.shared.deleteGame(id: gameId)
        }
    }

    func delete(at offsets: IndexSet) {
        let removedIDs = offsets.map { games[$0].id }
        games.remove(atOffsets: offsets)
        for id in removedIDs {
            removeGameFromAllCollections(id)
            Task {
                try? await SupabaseSyncService.shared.deleteGame(id: id)
            }
        }
    }

    func update(_ game: Game) {
        var updated = game
        if updated.status == .playing {
            updated.isBacklog = false
            if updated.lastPlayedDate == nil {
                updated.lastPlayedDate = Date()
            }
        }

        if let idx = games.firstIndex(where: { $0.id == updated.id }) {
            games[idx] = updated
            try? saveGames()
            Task {
                try? await SupabaseSyncService.shared.upsertGame(updated)
            }
        }
    }

    // MARK: - Collections Public API

    @discardableResult
    func createCollection(name: String, description: String = "", initialGameIDs: [UUID] = []) -> GameCollection {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let collection = GameCollection(
            name: trimmed.isEmpty ? "Ny samling" : trimmed,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            gameIDs: initialGameIDs
        )
        collections.insert(collection, at: 0)
        Task {
            try? await SupabaseSyncService.shared.upsertCollection(collection)
        }
        return collection
    }

    func updateCollection(_ collection: GameCollection) {
        if let idx = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[idx] = collection
            Task {
                try? await SupabaseSyncService.shared.upsertCollection(collection)
            }
        }
    }

    func deleteCollection(_ collection: GameCollection) {
        let id = collection.id
        collections.removeAll(where: { $0.id == id })
        Task {
            try? await SupabaseSyncService.shared.deleteCollection(id: id)
        }
    }

    func toggleGame(_ gameID: UUID, in collectionID: UUID) {
        guard let idx = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        var col = collections[idx]
        if col.gameIDs.contains(gameID) {
            col.gameIDs.removeAll(where: { $0 == gameID })
        } else {
            col.gameIDs.append(gameID)
        }
        collections[idx] = col
        Task {
            try? await SupabaseSyncService.shared.upsertCollection(col)
        }
    }

    func addGame(_ gameID: UUID, to collectionID: UUID) {
        guard let idx = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        if !collections[idx].gameIDs.contains(gameID) {
            collections[idx].gameIDs.append(gameID)
            let updatedCol = collections[idx]
            Task {
                try? await SupabaseSyncService.shared.upsertCollection(updatedCol)
            }
        }
    }

    func removeGame(_ gameID: UUID, from collectionID: UUID) {
        guard let idx = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        collections[idx].gameIDs.removeAll(where: { $0 == gameID })
        let updatedCol = collections[idx]
        Task {
            try? await SupabaseSyncService.shared.upsertCollection(updatedCol)
        }
    }

    func collections(for gameID: UUID) -> [GameCollection] {
        collections.filter { $0.gameIDs.contains(gameID) }
    }

    func games(in collection: GameCollection) -> [Game] {
        collection.gameIDs.compactMap { id in
            games.first(where: { $0.id == id })
        }
    }

    private func removeGameFromAllCollections(_ gameID: UUID) {
        for idx in collections.indices {
            collections[idx].gameIDs.removeAll(where: { $0 == gameID })
        }
    }

    // MARK: - Persistence (JSON)
    private func documentsURL() throws -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let url = urls.first else { throw CocoaError(.fileNoSuchFile) }
        return url
    }

    private func gamesURL() throws -> URL {
        try documentsURL().appendingPathComponent(gamesFileName)
    }

    private func collectionsURL() throws -> URL {
        try documentsURL().appendingPathComponent(collectionsFileName)
    }

    func saveGames() throws {
        let url = try gamesURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(games)
        try data.write(to: url, options: .atomic)
    }

    func saveCollections() throws {
        let url = try collectionsURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(collections)
        try data.write(to: url, options: .atomic)
    }

    func loadGames() throws {
        let url = try gamesURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            self.games = []
            return
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        do {
            self.games = try decoder.decode([Game].self, from: data)
        } catch {
            if let legacy = try? decoder.decode([LegacyGame].self, from: data) {
                self.games = migrateLegacy(legacy)
                try? saveGames()
            } else {
                throw error
            }
        }
    }

    func loadCollections() throws {
        let url = try collectionsURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            self.collections = []
            return
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        self.collections = (try? decoder.decode([GameCollection].self, from: data)) ?? []
    }

    // Gruppindelning per plattform (för hyllvy)
    var shelvesByPlatform: [Shelf] {
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
