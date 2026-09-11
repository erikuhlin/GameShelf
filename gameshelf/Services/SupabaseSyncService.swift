//
//  SupabaseSyncService.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-27.
//

import Foundation

// MARK: - Supabase Sync Actor Service
actor SupabaseSyncService {
    static let shared = SupabaseSyncService()

    private struct SupabaseGameDTO: Codable, Sendable {
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
        var created_at: String?
        var completed_year: Int?
        var completed_date: String?

        enum CodingKeys: String, CodingKey {
            case id, user_id, title, platform, platforms, release_year, first_release_date
            case genres, developers, status, rating, igdb_rating, cover_url, igdb_id
            case estimated_hours, is_owned, notes, todos, created_at
            case completed_year, completed_date
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(user_id, forKey: .user_id)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(platform, forKey: .platform)
            try container.encodeIfPresent(platforms, forKey: .platforms)
            try container.encodeIfPresent(release_year, forKey: .release_year)
            try container.encodeIfPresent(first_release_date, forKey: .first_release_date)
            try container.encodeIfPresent(genres, forKey: .genres)
            try container.encodeIfPresent(developers, forKey: .developers)
            try container.encodeIfPresent(status, forKey: .status)
            try container.encodeIfPresent(rating, forKey: .rating)
            try container.encodeIfPresent(igdb_rating, forKey: .igdb_rating)
            try container.encodeIfPresent(cover_url, forKey: .cover_url)
            try container.encodeIfPresent(igdb_id, forKey: .igdb_id)
            try container.encodeIfPresent(estimated_hours, forKey: .estimated_hours)
            try container.encodeIfPresent(is_owned, forKey: .is_owned)
            try container.encodeIfPresent(notes, forKey: .notes)
            try container.encodeIfPresent(todos, forKey: .todos)
            try container.encodeIfPresent(created_at, forKey: .created_at)
            // intentionally omit completed_year and completed_date to prevent PGRST204 errors
        }

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
            self.todos = game.todos
            self.completed_year = game.completedYear
            self.completed_date = game.completedDate.map { ISO8601DateFormatter().string(from: $0) }

            // Pack metadata (completedYear, completedDate) into notes
            var metaDict: [String: Any] = [:]
            if let cy = game.completedYear {
                metaDict["completed_year"] = cy
            } else if game.status == .completed {
                metaDict["completed_year"] = NSNull()
            }
            if let cd = game.completedDate { metaDict["completed_date"] = ISO8601DateFormatter().string(from: cd) }

            let cleanNotes = game.notes.replacingOccurrences(of: #"<!--GS_META:[\s\S]*?-->\n?"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)

            if !metaDict.isEmpty, let jsonData = try? JSONSerialization.data(withJSONObject: metaDict), let metaStr = String(data: jsonData, encoding: .utf8) {
                let tag = "<!--GS_META:\(metaStr)-->"
                self.notes = cleanNotes.isEmpty ? tag : "\(tag)\n\(cleanNotes)"
            } else {
                self.notes = cleanNotes
            }
        }

        func toDomainGame() -> Game {
            let playStatus: PlayStatus
            var isBacklog = false
            var isOwnedGame = is_owned ?? true
            let statusString = status?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? "notstarted"
            switch statusString {
            case "playing", "spelar", "spelar nu", "inprogress", "in_progress", "pågående", "aktiv":
                playStatus = .playing
            case "backlog":
                playStatus = .notStarted
                isBacklog = true
            case "unplayed", "ej spelat", "ej påbörjat", "inte påbörjat", "inte spelat", "notstarted", "not_started":
                playStatus = .notStarted
            case "paused", "pausat", "tar paus":
                playStatus = .paused
            case "completed", "klar", "klart", "genomspelat", "inte aktiv längre", "hundredpercent", "100 %", "100%":
                playStatus = .completed
            case "abandoned", "avbruten", "avbrutet", "droppat", "dropped", "slutat spela":
                playStatus = .abandoned
            case "wishlist", "önskelista":
                playStatus = .notStarted
                isOwnedGame = false
            default:
                playStatus = .notStarted
            }

            var plats = platforms ?? []
            if plats.isEmpty, let single = platform, !single.isEmpty {
                plats = [single]
            }

            let intRating: Int? = rating.map { Int(round($0)) }

            let parsedDate: Date
            if let createdStr = created_at {
                parsedDate = ISO8601DateFormatter().date(from: createdStr) ?? Date()
            } else {
                parsedDate = Date()
            }

            var parsedCompletedYear = completed_year
            var parsedCompletedDate: Date? = nil
            var cleanUserNotes = notes ?? ""

            if let rawNotes = notes, let regex = try? NSRegularExpression(pattern: #"<!--GS_META:([\s\S]*?)-->"#) {
                let nsStr = rawNotes as NSString
                if let match = regex.firstMatch(in: rawNotes, range: NSRange(location: 0, length: nsStr.length)) {
                    let jsonRange = match.range(at: 1)
                    let jsonStr = nsStr.substring(with: jsonRange)
                    if let data = jsonStr.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let cy = dict["completed_year"] as? Int {
                            parsedCompletedYear = cy
                        } else if let cyStr = dict["completed_year"] as? String, let cyInt = Int(cyStr) {
                            parsedCompletedYear = cyInt
                        } else if dict.keys.contains("completed_year") {
                            parsedCompletedYear = nil
                        }
                        if let cdStr = dict["completed_date"] as? String {
                            parsedCompletedDate = ISO8601DateFormatter().date(from: cdStr)
                        }
                    }
                    cleanUserNotes = regex.stringByReplacingMatches(in: rawNotes, range: NSRange(location: 0, length: nsStr.length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            if parsedCompletedDate == nil, let compStr = completed_date {
                parsedCompletedDate = ISO8601DateFormatter().date(from: compStr)
            }


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
                isOwned: isOwnedGame,
                notes: cleanUserNotes,
                todos: todos ?? [],
                dateAdded: parsedDate,
                isBacklog: isBacklog,
                completedYear: parsedCompletedYear,
                completedDate: parsedCompletedDate
            )
        }
    }

    private struct SupabaseCollectionDTO: Codable, Sendable {
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
        try? await upsertGames(localGames)
    }

    // MARK: - Games Sync

    /// Hämtar användarens spel från Supabase
    func fetchRemoteGames(forUserId explicitId: UUID? = nil) async throws -> [Game] {
        guard SupabaseConfig.isSyncEnabled else { return [] }
        let currentUserId: UUID
        if let explicitId {
            currentUserId = explicitId
        } else {
            currentUserId = await MainActor.run { SupabaseAuthManager.shared.persistentUserId }
        }
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

    /// Skapar eller uppdaterar flera spel i Supabase i snabba batch-anrop
    func upsertGames(_ games: [Game], forUserId explicitId: UUID? = nil) async throws {
        guard SupabaseConfig.isSyncEnabled, !games.isEmpty else { return }
        let currentUserId: UUID
        if let explicitId {
            currentUserId = explicitId
        } else {
            currentUserId = await MainActor.run { SupabaseAuthManager.shared.persistentUserId }
        }

        // Dela upp i batcher om max 50 spel per anrop
        let batchSize = 50
        for i in stride(from: 0, to: games.count, by: batchSize) {
            let chunk = Array(games[i..<min(i + batchSize, games.count)])
            let dtos = chunk.map { SupabaseGameDTO(from: $0, userId: currentUserId) }
            let data = try JSONEncoder().encode(dtos)

            guard let request = await makeRequest(
                endpoint: "user_games",
                method: "POST",
                body: data,
                prefer: "resolution=merge-duplicates,return=minimal"
            ) else {
                throw URLError(.badURL)
            }

            let (respData, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            guard (200...299).contains(statusCode) else {
                let err = String(data: respData, encoding: .utf8) ?? "Kunde inte spara spel"
                print("❌ upsertGames error (\(statusCode)): \(err)")

                // Om schema saknar first_release_date, prova fallback utan det fältet
                if err.contains("first_release_date") {
                    let fallbackDtos = dtos.map { dto -> SupabaseGameDTO in
                        var copy = dto
                        copy.first_release_date = nil
                        return copy
                    }
                    if let fbData = try? JSONEncoder().encode(fallbackDtos),
                       let fbReq = await makeRequest(
                           endpoint: "user_games",
                           method: "POST",
                           body: fbData,
                           prefer: "resolution=merge-duplicates,return=minimal"
                       ),
                       let (_, fbResp) = try? await session.data(for: fbReq),
                       (200...299).contains((fbResp as? HTTPURLResponse)?.statusCode ?? 500) {
                        continue
                    }
                }

                throw NSError(domain: "SyncError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: err])
            }
        }
    }

    /// Skapar eller uppdaterar ett enskilt spel i Supabase (upsert)
    func upsertGame(_ game: Game) async throws {
        try await upsertGames([game])
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
    func fetchRemoteCollections(forUserId explicitId: UUID? = nil) async throws -> [GameCollection] {
        guard SupabaseConfig.isSyncEnabled else { return [] }
        let currentUserId: UUID
        if let explicitId {
            currentUserId = explicitId
        } else {
            currentUserId = await MainActor.run { SupabaseAuthManager.shared.persistentUserId }
        }
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

    // MARK: - Profile Sync
    struct RemoteProfileRecord: Codable {
        var id: String
        var username: String?
        var full_name: String?
        var avatar_url: String?
        var updated_at: String?
    }

    struct ProfilePreferencesData: Codable {
        var age: Int?
        var platforms: [String]?
        var favoriteGenres: [String]?
        var playFor: [String]?
        var favoriteGameIDs: [String]?
        var annualGamingGoal: Int?
        var avatarType: String?
        var targetGameIDs: [String]?
        var playingMood: String?
        var gamerBio: String?
        var playstyle: [String]?
        var gotyByYear: [String: String]?
    }

    func fetchProfile(userId: UUID) async throws -> (username: String?, avatarUrl: String?, preferences: ProfilePreferencesData?)? {
        guard let request = await makeRequest(
            endpoint: "profiles?id=eq.\(userId.uuidString)&select=*",
            method: "GET"
        ) else { return nil }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return nil
        }

        let records = try JSONDecoder().decode([RemoteProfileRecord].self, from: data)
        guard let record = records.first else { return nil }

        var prefs: ProfilePreferencesData? = nil
        if let fn = record.full_name, let fnData = fn.data(using: .utf8) {
            prefs = try? JSONDecoder().decode(ProfilePreferencesData.self, from: fnData)
        }

        return (record.username, record.avatar_url, prefs)
    }

    func upsertProfile(
        userId: UUID,
        username: String,
        avatarUrl: String?,
        preferences: ProfilePreferencesData
    ) async throws {
        let prefsData = try JSONEncoder().encode(preferences)
        let fullNameJSON = String(data: prefsData, encoding: .utf8) ?? "{}"

        let record = RemoteProfileRecord(
            id: userId.uuidString,
            username: username,
            full_name: fullNameJSON,
            avatar_url: avatarUrl,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        let body = try JSONEncoder().encode(record)
        guard let request = await makeRequest(
            endpoint: "profiles",
            method: "POST",
            body: body,
            prefer: "resolution=merge-duplicates,return=representation"
        ) else { return }

        let (respData, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200...299).contains(statusCode) else {
            let err = String(data: respData, encoding: .utf8) ?? "Kunde inte spara profil"
            print("❌ upsertProfile error (\(statusCode)): \(err)")
            return
        }
    }
}
