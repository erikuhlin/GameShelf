//
//  SupabaseSyncService.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-27.
//

import Foundation

// MARK: - Supabase DTO Models
private struct SupabaseGameDTO: Codable {
    var id: UUID
    var user_id: UUID?
    var title: String
    var platform: String?
    var platforms: [String]?
    var release_year: Int?
    var first_release_date: Int?
    var genres: [String]?
    var developers: [String]?
    var status: String?
    var rating: Double?
    var igdb_rating: Double?
    var cover_url: String?
    var igdb_id: Int?
    var estimated_hours: Int?
    var is_owned: Bool?
    var notes: String?
    var todos: [GameTodoItem]?

    init(from game: Game, userId: UUID? = nil) {
        self.id = game.id
        self.user_id = userId
        self.title = game.title
        self.platform = game.platforms.first
        self.platforms = game.platforms
        self.release_year = game.releaseYear
        self.first_release_date = game.firstReleaseDate
        self.genres = game.genres
        self.developers = game.developers
        self.status = game.status.rawValue
        self.rating = game.rating.map { Double($0) }
        self.igdb_rating = game.igdbRating
        self.cover_url = game.coverURL?.absoluteString
        self.igdb_id = game.igdbID
        self.estimated_hours = game.estimatedHours
        self.is_owned = game.isOwned
        self.notes = game.notes
        self.todos = game.todos
    }

    func toDomainGame() -> Game {
        let playStatus: PlayStatus
        let statusString = status?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? "backlog"
        switch statusString {
        case "playing", "spelar", "spelar nu", "inprogress", "in_progress", "pågående":
            playStatus = .playing
        case "backlog", "unplayed", "ej spelat", "ej påbörjat":
            playStatus = .backlog
        case "paused", "pausat":
            playStatus = .paused
        case "completed", "klar", "hundredpercent", "100 %", "100%":
            playStatus = .completed
        case "abandoned", "avbruten", "avbrutet", "droppat", "dropped":
            playStatus = .abandoned
        case "wishlist", "önskelista":
            playStatus = .wishlist
        default:
            playStatus = .backlog
        }

        var plats = platforms ?? []
        if plats.isEmpty, let single = platform, !single.isEmpty {
            plats = [single]
        }

        let intRating: Int? = rating.map { Int(round($0)) }

        return Game(
            id: id,
            title: title,
            platforms: plats,
            releaseYear: release_year ?? 0,
            genres: genres ?? [],
            developers: developers ?? [],
            status: playStatus,
            rating: intRating,
            igdbRating: igdb_rating,
            coverURL: cover_url.flatMap { URL(string: $0) },
            igdbID: igdb_id,
            firstReleaseDate: first_release_date,
            estimatedHours: estimated_hours,
            isOwned: is_owned ?? true,
            notes: notes ?? "",
            todos: todos ?? []
        )
    }
}

private struct SupabaseCollectionDTO: Codable {
    var id: UUID
    var user_id: UUID?
    var name: String
    var description: String?
    var game_ids: [UUID]?

    init(from col: GameCollection, userId: UUID? = nil) {
        self.id = col.id
        self.user_id = userId
        self.name = col.name
        self.description = col.description
        self.game_ids = col.gameIDs
    }

    func toDomainCollection() -> GameCollection {
        GameCollection(
            id: id,
            name: name,
            description: description ?? "",
            gameIDs: game_ids ?? []
        )
    }
}

// MARK: - Supabase Sync Actor Service
actor SupabaseSyncService {
    static let shared = SupabaseSyncService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    private func makeRequest(endpoint: String, method: String = "GET", body: Data? = nil, prefer: String? = nil) async -> URLRequest? {
        let base = SupabaseConfig.baseURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let fullURL = URL(string: "\(base)/rest/v1/\(endpoint)") else { return nil }

        var request = URLRequest(url: fullURL)
        request.httpMethod = method

        var token = SupabaseConfig.anonKey
        let (isLinked, userToken) = await MainActor.run {
            (SupabaseAuthManager.shared.currentUser?.isLinkedWithRealEmail ?? false,
             SupabaseAuthManager.shared.session?.accessToken)
        }
        if isLinked, let userToken = userToken {
            token = userToken
        }

        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let prefer = prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }

        if let body = body {
            request.httpBody = body
        }

        return request
    }

    // MARK: - One-Time Migration
    /// Engångsmigrering som läser in lokala spel och laddar upp dem till Supabase vid första anslutning
    func migrateLocalGamesIfNeeded(localGames: [Game]) async {
        guard !localGames.isEmpty else { return }

        for game in localGames {
            try? await upsertGame(game)
        }
    }

    // MARK: - Games Sync

    /// Hämtar användarens spel från Supabase
    func fetchRemoteGames() async throws -> [Game] {
        guard SupabaseConfig.isSyncEnabled else { return [] }
        let currentUserId = await MainActor.run { SupabaseAuthManager.shared.persistentUserId }
        guard let request = await makeRequest(endpoint: "user_games?user_id=eq.\(currentUserId.uuidString)&select=*&order=created_at.desc") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let dtos = try JSONDecoder().decode([SupabaseGameDTO].self, from: data)
        return dtos.map { $0.toDomainGame() }
    }

    /// Skapar eller uppdaterar ett spel i Supabase (upsert)
    func upsertGame(_ game: Game) async throws {
        guard SupabaseConfig.isSyncEnabled else { return }
        let currentUserId = await MainActor.run { SupabaseAuthManager.shared.persistentUserId }
        let dto = SupabaseGameDTO(from: game, userId: currentUserId)
        let data = try JSONEncoder().encode(dto)

        guard let request = await makeRequest(
            endpoint: "user_games",
            method: "POST",
            body: data,
            prefer: "resolution=merge-duplicates,return=representation"
        ) else {
            throw URLError(.badURL)
        }

        let (respData, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200...299).contains(statusCode) else {
            let err = String(data: respData, encoding: .utf8) ?? "Kunde inte spara spel"
            print("❌ upsertGame error (\(statusCode)): \(err)")
            throw NSError(domain: "SyncError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: err])
        }
    }

    /// Tar bort ett spel från Supabase
    func deleteGame(id: UUID) async throws {
        guard SupabaseConfig.isSyncEnabled else { return }
        let currentUserId = await MainActor.run { SupabaseAuthManager.shared.persistentUserId }
        guard let request = await makeRequest(
            endpoint: "user_games?id=eq.\(id.uuidString)&user_id=eq.\(currentUserId.uuidString)",
            method: "DELETE"
        ) else {
            throw URLError(.badURL)
        }

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Collections Sync

    /// Hämtar användarens samlingar från Supabase
    func fetchRemoteCollections() async throws -> [GameCollection] {
        guard SupabaseConfig.isSyncEnabled else { return [] }
        let currentUserId = await MainActor.run { SupabaseAuthManager.shared.persistentUserId }
        guard let request = await makeRequest(endpoint: "collections?user_id=eq.\(currentUserId.uuidString)&select=*&order=created_at.desc") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let dtos = try JSONDecoder().decode([SupabaseCollectionDTO].self, from: data)
        return dtos.map { $0.toDomainCollection() }
    }

    /// Skapar eller uppdaterar en samling i Supabase (upsert)
    func upsertCollection(_ collection: GameCollection) async throws {
        guard SupabaseConfig.isSyncEnabled else { return }
        let currentUserId = await MainActor.run { SupabaseAuthManager.shared.persistentUserId }
        let dto = SupabaseCollectionDTO(from: collection, userId: currentUserId)
        let data = try JSONEncoder().encode(dto)

        guard let request = await makeRequest(
            endpoint: "collections",
            method: "POST",
            body: data,
            prefer: "resolution=merge-duplicates,return=representation"
        ) else {
            throw URLError(.badURL)
        }

        let (respData, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200...299).contains(statusCode) else {
            let err = String(data: respData, encoding: .utf8) ?? "Kunde inte spara samling"
            print("❌ upsertCollection error (\(statusCode)): \(err)")
            throw NSError(domain: "SyncError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: err])
        }
    }

    /// Tar bort en samling från Supabase
    func deleteCollection(id: UUID) async throws {
        guard SupabaseConfig.isSyncEnabled else { return }
        guard let request = await makeRequest(
            endpoint: "collections?id=eq.\(id.uuidString)",
            method: "DELETE"
        ) else {
            throw URLError(.badURL)
        }

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
