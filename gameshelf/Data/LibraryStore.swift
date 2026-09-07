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

            // Engångssanering av tidigare auto-tilldelade completedYear (2026) på genomspelade spel
            let cleanupKey = "has_cleaned_legacy_auto_completed_year_v1"
            if !UserDefaults.standard.bool(forKey: cleanupKey) {
                let currentY = Calendar.current.component(.year, from: Date())
                var modified = false
                self.games = self.games.map { g in
                    var copy = g
                    if copy.completedYear == currentY && copy.title.lowercased() != "007 first light" {
                        copy.completedYear = nil
                        copy.completedDate = nil
                        modified = true
                    }
                    return copy
                }
                if modified {
                    try? saveGames()
                }
                UserDefaults.standard.set(true, forKey: cleanupKey)
            }
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
            try? await SupabaseSyncService.shared.upsertGames(self.games)
            for col in self.collections {
                try? await SupabaseSyncService.shared.upsertCollection(col)
            }
            UserDefaults.standard.set(true, forKey: initialMigrationKey)
        }

        // 1. Synka spel från servern (speglar ändringar och bevarar lokala spel)
        do {
            let remoteGames = try await SupabaseSyncService.shared.fetchRemoteGames()
            if !remoteGames.isEmpty {
                // Bevara kända lanseringsdatum från befintliga lokala spel så de inte skrivs över
                let localDateMap = Dictionary(uniqueKeysWithValues: self.games.compactMap { g in
                    g.firstReleaseDate.map { (g.id, $0) }
                })
                let remoteMap = Dictionary(uniqueKeysWithValues: remoteGames.map { ($0.id, $0) })

                // Identifiera eventuella lokala spel som inte finns på servern än
                let localOnlyGames = self.games.filter { remoteMap[$0.id] == nil }

                // Skapa en sammanslagen lista: remote-spel först, plus eventuella lokala spel som saknas i molnet
                var mergedGames = remoteGames.map { r in
                    var merged = r
                    if merged.firstReleaseDate == nil, let cachedDate = localDateMap[merged.id] {
                        merged.firstReleaseDate = cachedDate
                    }
                    return merged
                }
                if !localOnlyGames.isEmpty {
                    mergedGames.append(contentsOf: localOnlyGames)
                    Task {
                        try? await SupabaseSyncService.shared.upsertGames(localOnlyGames)
                    }
                }

                self.games = mergedGames
                try? saveGames()
            } else if !self.games.isEmpty {
                // Om servern var tom men vi har lokala spel: ladda upp alla lokala spel till servern i batch
                try? await SupabaseSyncService.shared.upsertGames(self.games)
            }
            UserDefaults.standard.set(true, forKey: initialMigrationKey)
        } catch {
            // Ignorera offline / nätverksfel så lokal data fortsätter fungera
        }

        // 2. Synka samlingar från servern
        do {
            let remoteCollections = try await SupabaseSyncService.shared.fetchRemoteCollections()
            if !remoteCollections.isEmpty {
                self.collections = remoteCollections
                try? saveCollections()
            }
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

        let currentYear = Calendar.current.component(.year, from: Date())

        while true {
            let gamesNeedingDates = self.games
                .filter { $0.firstReleaseDate == nil && !checkedGameIDsForDates.contains($0.id) }
                .sorted { g1, g2 in
                    // Prioritera spel från innevarande och framtida år så "Kommande"-taggar sätts rätt direkt
                    let g1Prio = g1.releaseYear >= currentYear ? 1 : 0
                    let g2Prio = g2.releaseYear >= currentYear ? 1 : 0
                    return g1Prio > g2Prio
                }
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
                    checkedGameIDsForDates.remove(game.id)
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

    private func gamesURL(for profileId: UUID? = nil) throws -> URL {
        let pid = profileId ?? ProfileManager.shared.activeProfileId
        let profileFilename = "library_\(pid.uuidString).json"
        let profileURL = try documentsURL().appendingPathComponent(profileFilename)
        if FileManager.default.fileExists(atPath: profileURL.path) {
            return profileURL
        }
        let legacyURL = try documentsURL().appendingPathComponent(gamesFileName)
        if FileManager.default.fileExists(atPath: legacyURL.path) && pid == ProfileManager.shared.profiles.first?.id {
            return legacyURL
        }
        return profileURL
    }

    private func collectionsURL(for profileId: UUID? = nil) throws -> URL {
        let pid = profileId ?? ProfileManager.shared.activeProfileId
        let profileFilename = "collections_\(pid.uuidString).json"
        let profileURL = try documentsURL().appendingPathComponent(profileFilename)
        if FileManager.default.fileExists(atPath: profileURL.path) {
            return profileURL
        }
        let legacyURL = try documentsURL().appendingPathComponent(collectionsFileName)
        if FileManager.default.fileExists(atPath: legacyURL.path) && pid == ProfileManager.shared.profiles.first?.id {
            return legacyURL
        }
        return profileURL
    }

    func saveGames() throws {
        let pid = ProfileManager.shared.activeProfileId
        let url = try documentsURL().appendingPathComponent("library_\(pid.uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(games)
        try data.write(to: url, options: .atomic)
    }

    func saveCollections() throws {
        let pid = ProfileManager.shared.activeProfileId
        let url = try documentsURL().appendingPathComponent("collections_\(pid.uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(collections)
        try data.write(to: url, options: .atomic)
    }

    func loadGames(for profileId: UUID? = nil) throws {
        let url = try gamesURL(for: profileId)
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

    func loadCollections(for profileId: UUID? = nil) throws {
        let url = try collectionsURL(for: profileId)
        guard FileManager.default.fileExists(atPath: url.path) else {
            self.collections = []
            return
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        self.collections = (try? decoder.decode([GameCollection].self, from: data)) ?? []
    }

    func importAndSyncProfile(userId: UUID) async throws -> Int {
        try? saveGames()
        try? saveCollections()

        checkedGameIDsForDates.removeAll()

        let remoteGames = try await SupabaseSyncService.shared.fetchRemoteGames(forUserId: userId)
        let remoteCollections = (try? await SupabaseSyncService.shared.fetchRemoteCollections(forUserId: userId)) ?? []

        self.games = remoteGames
        self.collections = remoteCollections

        try? saveGames()
        try? saveCollections()

        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        Task {
            await enrichMissingReleaseDates()
        }

        return remoteGames.count
    }

    func switchToProfile(id: UUID) {
        try? saveGames()
        try? saveCollections()

        checkedGameIDsForDates.removeAll()
        do {
            try loadGames(for: id)
            try loadCollections(for: id)
        } catch {
            self.games = []
            self.collections = []
        }

        Task {
            await syncWithRemote()
            await enrichMissingReleaseDates()
        }
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
