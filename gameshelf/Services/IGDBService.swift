import Foundation

enum DiscoverSortOption: String, CaseIterable, Identifiable, Sendable {
    case rating = "Högst betyg"
    case popularity = "Mest populärt"
    case releaseDateDesc = "Nyast först"
    case releaseDateAsc = "Äldst först"

    var id: String { rawValue }

    var igdbSortClause: String {
        switch self {
        case .rating: return "total_rating desc"
        case .popularity: return "total_rating_count desc"
        case .releaseDateDesc: return "first_release_date desc"
        case .releaseDateAsc: return "first_release_date asc"
        }
    }
}

actor IGDBService {
    static let shared = IGDBService()
    
    private init() {}
    
    /// Söker efter spel via IGDB API v4
    func searchGames(query: String) async throws -> [IGDBGame] {
        // Om söksträngen är tom returnerar vi en tom lista direkt
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }
        
        // Hämta en giltig Bearer-token via vår AuthManager
        let token = try await IGDBAuthManager.shared.getValidToken()
        
        // Lös upp förkortningar/alias (t.ex. GTA V -> Grand Theft Auto V)
        let resolvedQuery = GameAliasResolver.resolve(query: trimmedQuery)
        
        // Sanera söksträngen från citationstecken så att inte query-syntaxen kraschar
        let safeQuery = resolvedQuery
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        // IGDB Apex Query:
        // Vi hämtar id, namn, sammanfattning, releasedatum, omslagsbild samt namn på plattformar och genrer.
        let bodyString = """
        search "\(safeQuery)";
        fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, total_rating, total_rating_count;
        limit 30;
        """
        
        return try await requestGames(body: bodyString, url: url, token: token)
    }
    
    /// Hämtar detaljer för ett specifikt spel baserat på IGDB ID
    func fetchGameDetails(id: Int) async throws -> IGDBGame {
        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }
        
        let token = try await IGDBAuthManager.shared.getValidToken()
        
        let bodyString = """
        where id = \(id);
        fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, total_rating, aggregated_rating, involved_companies.company.name, involved_companies.developer, involved_companies.publisher, collection.name, similar_games.name, similar_games.cover.image_id, dlcs.name, dlcs.cover.image_id, expansions.name, expansions.cover.image_id, screenshots.image_id, artworks.image_id, videos.name, videos.video_id, game_modes.name, themes.name, age_ratings.category, age_ratings.rating;
        """
        
        let games = try await requestGames(body: bodyString, url: url, token: token)
        
        guard var game = games.first else {
            throw URLError(.cannotParseResponse)
        }
        
        // Hämta reella speltidsdata från IGDB:s time_to_beats endpoint
        if let ttb = await fetchTimeToBeat(gameID: id) {
            game = IGDBGame(
                id: game.id,
                name: game.name,
                summary: game.summary,
                firstReleaseDate: game.firstReleaseDate,
                cover: game.cover,
                platforms: game.platforms,
                genres: game.genres,
                totalRating: game.totalRating,
                aggregatedRating: game.aggregatedRating,
                involvedCompanies: game.involvedCompanies,
                collection: game.collection,
                similarGames: game.similarGames,
                dlcs: game.dlcs,
                expansions: game.expansions,
                screenshots: game.screenshots,
                artworks: game.artworks,
                videos: game.videos,
                gameModes: game.gameModes,
                themes: game.themes,
                ageRatings: game.ageRatings,
                timeToBeat: ttb,
                totalRatingCount: game.totalRatingCount
            )
        }
        
        return game
    }

    /// Hämtar reell speltid (HowLongToBeat) från IGDB:s game_time_to_beats endpoint för ett spel
    func fetchTimeToBeat(gameID: Int) async -> IGDBTimeToBeat? {
        guard let url = URL(string: "https://api.igdb.com/v4/game_time_to_beats") else { return nil }
        do {
            let token = try await IGDBAuthManager.shared.getValidToken()
            let bodyString = "where game_id = \(gameID); fields hastily, normally, completely, game_id;"
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(IGDBAuthConfig.clientID, forHTTPHeaderField: "Client-ID")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = bodyString.data(using: .utf8)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("[IGDBService] fetchTimeToBeat HTTP error for gameID \(gameID)")
                return nil
            }

            let ttbList = try JSONDecoder().decode([IGDBTimeToBeat].self, from: data)
            if let ttb = ttbList.first {
                print("[IGDBService] ⏱️ IGDB game_time_to_beats for gameID \(gameID): Main=\(ttb.mainStoryFormatted) (\(ttb.hastily ?? 0)s), Extra=\(ttb.mainExtraFormatted) (\(ttb.normally ?? 0)s), 100%=\(ttb.completionistFormatted) (\(ttb.completely ?? 0)s)")
                return ttb
            } else {
                print("[IGDBService] ⚠️ No game_time_to_beats data for gameID \(gameID)")
            }
            return nil
        } catch {
            print("[IGDBService] fetchTimeToBeat error for gameID \(gameID): \(error.localizedDescription)")
            return nil
        }
    }

struct IGDBPopularityPrimitive: Decodable, Sendable {
    let id: Int
    let gameId: Int
    let value: Double
    let popularityType: Int

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case value
        case popularityType = "popularity_type"
    }
}

    /// Hämtar råa popularitetsprimitiver från IGDB PopScore (Visits, Playing, Top Sellers m.m.)
    private func fetchPopularityPrimitives(types: [Int] = [1, 3, 9], limit: Int = 60) async throws -> [IGDBPopularityPrimitive] {
        let token = try await IGDBAuthManager.shared.getValidToken()
        guard let url = URL(string: "https://api.igdb.com/v4/popularity_primitives") else {
            throw URLError(.badURL)
        }
        let typeClause = types.count == 1 ? "popularity_type = \(types[0])" : "popularity_type = (\(types.map(String.init).joined(separator: ",")))"
        let bodyString = """
        fields game_id, value, popularity_type;
        where \(typeClause);
        sort value desc;
        limit \(limit);
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(IGDBAuthConfig.clientID, forHTTPHeaderField: "Client-ID")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([IGDBPopularityPrimitive].self, from: data)
    }

    /// Hämtar trendande spel med plattformsfiltrering
    func fetchTrendingGames(platformIDs: [Int]) async throws -> [IGDBGame] {
        let token = try await IGDBAuthManager.shared.getValidToken()
        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }
        let now = Int(Date().timeIntervalSince1970)

        // 1. Försök att hämta dynamiskt populära spel från IGDB PopScore
        do {
            let prims = try await fetchPopularityPrimitives(types: [1, 3, 9], limit: 60)
            var uniqueIDs: [Int] = []
            var seen = Set<Int>()
            for p in prims {
                if !seen.contains(p.gameId) {
                    seen.insert(p.gameId)
                    uniqueIDs.append(p.gameId)
                }
            }

            if !uniqueIDs.isEmpty {
                let idList = uniqueIDs.map(String.init).joined(separator: ",")
                let bodyString = """
                fields name, summary, first_release_date, cover.image_id, platforms.id, platforms.name, genres.name, themes.id, themes.name, total_rating, total_rating_count, hypes;
                where id = (\(idList)) & cover != null;
                limit \(uniqueIDs.count);
                """
                let games = try await requestGames(body: bodyString, url: url, token: token)
                let gameMap = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
                var orderedGames = uniqueIDs.compactMap { gameMap[$0] }

                // Filtrera bort olämpligt innehåll (tema 42 = Erotic)
                orderedGames.removeAll { game in
                    (game.themes?.contains(where: { $0.id == 42 || $0.name.lowercased().contains("erotic") }) ?? false)
                }

                if !platformIDs.isEmpty {
                    let platformSet = Set(platformIDs)
                    let filtered = orderedGames.filter { game in
                        guard let pList = game.platforms else { return false }
                        return pList.contains(where: { platformSet.contains($0.id) })
                    }
                    if !filtered.isEmpty {
                        return Array(filtered.prefix(30))
                    }
                } else if !orderedGames.isEmpty {
                    return Array(orderedGames.prefix(30))
                }
            }
        } catch {
            print("[IGDBService] fetchTrendingGames PopScore fallback: \(error)")
        }

        // Fallback: Senaste 12 månaderna
        let oneYearAgo = now - (365 * 24 * 3600)
        let platformFilter = platformIDs.isEmpty
            ? ""
            : " & platforms = (\(platformIDs.map(String.init).joined(separator: ",")))"

        let bodyString = """
        fields name, first_release_date, cover.image_id, platforms.name, platforms.id, genres.name, themes.id, themes.name, total_rating, total_rating_count, hypes;
        where first_release_date > \(oneYearAgo) & first_release_date <= \(now) & cover != null & (hypes > 0 | total_rating != null)\(platformFilter);
        sort hypes desc;
        limit 30;
        """
        return try await requestGames(body: bodyString, url: url, token: token)
    }

    /// Hämtar aktuella och dynamiskt populära spel från IGDB per specifik genre eller globalt
    func fetchPopularGames(genre: String? = nil, sort: String = "popularity", limit: Int = 15) async throws -> [IGDBGame] {
        let token = try await IGDBAuthManager.shared.getValidToken()
        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }

        // Om en specifik genre är vald: Använd exakta IGDB ID-klausuler för maximal träffsäkerhet
        if let g = genre, !g.isEmpty {
            let filterClause: String
            let lower = g.lowercased()
            if lower == "action" {
                filterClause = "genres = (25, 5, 4)"
            } else if lower.contains("rpg") || lower.contains("rollspel") {
                filterClause = "genres = (12)"
            } else if lower == "adventure" || lower == "äventyr" {
                filterClause = "genres = (31)"
            } else if lower == "shooter" || lower == "skjutspel" {
                filterClause = "genres = (5)"
            } else if lower == "horror" || lower == "skräck" {
                filterClause = "themes = (19)"
            } else if lower == "strategy" || lower == "strategi" {
                filterClause = "genres = (15, 11, 16, 24)"
            } else if lower == "platform" || lower == "plattform" {
                filterClause = "genres = (8)"
            } else if lower == "racing" {
                filterClause = "genres = (10)"
            } else if lower == "fighting" {
                filterClause = "genres = (4)"
            } else if lower == "indie" {
                filterClause = "genres = (32)"
            } else if lower == "simulator" {
                filterClause = "genres = (13)"
            } else if lower == "puzzle" || lower == "pussel" {
                filterClause = "genres = (9)"
            } else if lower == "sport" {
                filterClause = "genres = (14)"
            } else {
                filterClause = "genres.name = \"\(g.replacingOccurrences(of: "\"", with: "\\\""))\""
            }

            var sortClause = "sort total_rating_count desc;"
            if sort == "rating" {
                sortClause = "sort total_rating desc;"
            } else if sort == "newest" {
                sortClause = "sort first_release_date desc;"
            }

            // Filtrera på moderna releaser (2021+) för hög aktualitet
            let minTimestamp = 1609459200 // 2021-01-01
            let genreBody = """
            fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, themes.id, themes.name, total_rating, total_rating_count, hypes;
            where \(filterClause) & first_release_date >= \(minTimestamp) & cover != null & (total_rating >= 68 | total_rating_count >= 5 | hypes >= 3);
            \(sortClause)
            limit \(limit);
            """

            do {
                let genreGames = try await requestGames(body: genreBody, url: url, token: token)
                if !genreGames.isEmpty {
                    return genreGames
                }
            } catch {
                print("[IGDBService] fetchPopularGames for genre \(g) fallback: \(error)")
            }

            // Bredare fallback om tidsfiltret var för snävt
            let fallbackBody = """
            fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, themes.id, themes.name, total_rating, total_rating_count, hypes;
            where \(filterClause) & cover != null;
            \(sortClause)
            limit \(limit);
            """
            return try await requestGames(body: fallbackBody, url: url, token: token)
        }

        // För "Alla" (genre == nil): Hämta globalt populära spel från IGDB PopScore
        do {
            let prims = try await fetchPopularityPrimitives(types: [1, 3, 9], limit: 80)
            var uniqueIDs: [Int] = []
            var seen = Set<Int>()
            for p in prims {
                if !seen.contains(p.gameId) {
                    seen.insert(p.gameId)
                    uniqueIDs.append(p.gameId)
                }
            }

            if !uniqueIDs.isEmpty {
                let idList = uniqueIDs.map(String.init).joined(separator: ",")
                let bodyString = """
                fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, themes.id, themes.name, total_rating, total_rating_count, hypes;
                where id = (\(idList)) & cover != null;
                limit \(uniqueIDs.count);
                """
                let games = try await requestGames(body: bodyString, url: url, token: token)
                let gameMap = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
                var orderedGames = uniqueIDs.compactMap { gameMap[$0] }

                // Filtrera bort olämpligt innehåll (tema 42 = Erotic)
                orderedGames.removeAll { game in
                    (game.themes?.contains(where: { $0.id == 42 || $0.name.lowercased().contains("erotic") }) ?? false)
                }

                if !orderedGames.isEmpty {
                    return Array(orderedGames.prefix(limit))
                }
            }
        } catch {
            print("[IGDBService] fetchPopularGames PopScore fallback: \(error)")
        }

        // Fallback om PopScore inte svarar
        let now = Int(Date().timeIntervalSince1970)
        let oneYearAgo = now - (365 * 24 * 3600)
        let fallbackBody = """
        fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, themes.id, themes.name, total_rating, total_rating_count, hypes;
        where first_release_date > \(oneYearAgo) & first_release_date <= \(now) & cover != null & (hypes > 0 | total_rating > 60);
        sort hypes desc;
        limit \(limit);
        """
        let fallbackGames = try await requestGames(body: fallbackBody, url: url, token: token)
        return Array(fallbackGames.prefix(limit))
    }

    /// Hämtar kommande heta spel från IGDB
    func fetchUpcomingGames(limit: Int = 15) async throws -> [IGDBGame] {
        let token = try await IGDBAuthManager.shared.getValidToken()
        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }
        let nowTimestamp = Int(Date().timeIntervalSince1970)
        let bodyString = """
        fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, hypes;
        where first_release_date > \(nowTimestamp) & cover != null & (hypes > 3 | total_rating_count > 0);
        sort first_release_date asc;
        limit \(limit);
        """
        return try await requestGames(body: bodyString, url: url, token: token)
    }

    /// Hämtar rekommenderade aktuella spel baserat på en lista av genrer
    func fetchRecommendations(forGenres genres: [String], limit: Int = 15) async throws -> [IGDBGame] {
        let token = try await IGDBAuthManager.shared.getValidToken()
        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }
        let now = Int(Date().timeIntervalSince1970)
        let threeYearsAgo = now - (1095 * 24 * 3600) // Senaste 3 åren

        var genreClauses: [String] = []
        for g in genres.prefix(3) {
            let safe = g.replacingOccurrences(of: "\"", with: "\\\"")
            genreClauses.append("genres.name = \"\(safe)\"")
        }
        let genreCondition = genreClauses.isEmpty ? "" : " & (\(genreClauses.joined(separator: " | ")))"

        let bodyString = """
        fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, total_rating, total_rating_count;
        where first_release_date > \(threeYearsAgo) & first_release_date <= \(now) & cover != null & total_rating > 75 & total_rating_count > 5\(genreCondition);
        sort total_rating desc;
        limit \(limit);
        """
        return try await requestGames(body: bodyString, url: url, token: token)
    }

    /// Avancerad sökning och upptäckt med årtal, tidsperiod, plattform, genre, utvecklare och sortering
    func discoverGames(
        query: String? = nil,
        startYear: Int? = nil,
        endYear: Int? = nil,
        platformIDs: [Int] = [],
        genre: String? = nil,
        developer: String? = nil,
        sortOption: DiscoverSortOption = .popularity,
        limit: Int = 30
    ) async throws -> [IGDBGame] {
        let token = try await IGDBAuthManager.shared.getValidToken()
        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }

        var conditions: [String] = ["cover != null"]

        // 1. Årtalsvillkor (timestamps)
        if let sYear = startYear {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!
            var startComps = DateComponents()
            startComps.year = sYear
            startComps.month = 1
            startComps.day = 1
            startComps.hour = 0
            startComps.minute = 0
            startComps.second = 0
            if let startDate = cal.date(from: startComps) {
                let startTs = Int(startDate.timeIntervalSince1970)
                conditions.append("first_release_date >= \(startTs)")
            }
        }

        if let eYear = endYear {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!
            var endComps = DateComponents()
            endComps.year = eYear
            endComps.month = 12
            endComps.day = 31
            endComps.hour = 23
            endComps.minute = 59
            endComps.second = 59
            if let endDate = cal.date(from: endComps) {
                let endTs = Int(endDate.timeIntervalSince1970)
                conditions.append("first_release_date <= \(endTs)")
            }
        }

        // 2. Plattformar
        if !platformIDs.isEmpty {
            let idList = platformIDs.map(String.init).joined(separator: ",")
            conditions.append("platforms = (\(idList))")
        }

        // 3. Genre / Tema
        if let g = genre, !g.isEmpty {
            let safeG = g.replacingOccurrences(of: "\"", with: "\\\"")
            if safeG.lowercased() == "horror" {
                conditions.append("themes.name = \"Horror\"")
            } else {
                conditions.append("genres.name = \"\(safeG)\"")
            }
        }

        // 4. Utvecklare / Studio
        if let dev = developer, !dev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let safeDev = dev.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "\\\"")
            conditions.append("involved_companies.company.name ~ *\"\(safeDev)\"*")
        }

        // 5. Betyg / Popularitetskrav vid sortering på betyg för relevans
        if sortOption == .rating {
            conditions.append("total_rating != null & total_rating_count > 3")
        }

        let whereClause = conditions.isEmpty ? "" : "where \(conditions.joined(separator: " & "));"

        // 6. Fritext vs filter query
        let trimmedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var bodyString = ""

        if !trimmedQuery.isEmpty {
            let resolvedQuery = GameAliasResolver.resolve(query: trimmedQuery)
            let safeQuery = resolvedQuery.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            bodyString = """
            search "\(safeQuery)";
            fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, total_rating, total_rating_count, involved_companies.company.name, involved_companies.developer;
            \(whereClause)
            limit \(limit);
            """
        } else {
            bodyString = """
            fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, total_rating, total_rating_count, involved_companies.company.name, involved_companies.developer;
            \(whereClause)
            sort \(sortOption.igdbSortClause);
            limit \(limit);
            """
        }

        let results = try await requestGames(body: bodyString, url: url, token: token)
        return results
    }

    private func requestGames(body: String, url: URL, token: String) async throws -> [IGDBGame] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(IGDBAuthConfig.clientID, forHTTPHeaderField: "Client-ID")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8) ?? "N/A"
            print("[IGDBService] Request failed with HTTP \(status): \(bodyText)")
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([IGDBGame].self, from: data)
    }
}
