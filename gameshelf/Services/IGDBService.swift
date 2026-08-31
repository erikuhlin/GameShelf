import Foundation

enum DiscoverSortOption: String, CaseIterable, Identifiable, Sendable {
    case rating = "Högst betyg"
    case popularity = "Mest populärt"
    case releaseDateDesc = "Nyast först"
    case releaseDateAsc = "Äldst först"

    var id: String { rawValue }

    nonisolated var igdbSortClause: String {
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
    
    // In-memory cache för snabb återanvändning av speldetaljer (0 ms laddtid vid återbesök)
    private var gameDetailsCache: [Int: IGDBGame] = [:]
    
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
        // Vi hämtar id, namn, sammanfattning, releasedatum, omslagsbild, genrer, category samt game_type och parent_game.
        // DLC, expansioner, uppdateringar och packs filtreras bort säkert i Swift via !$0.isDLC.
        let bodyString = """
        search "\(safeQuery)";
        fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, total_rating, total_rating_count, category, game_type, parent_game;
        limit 30;
        """
        
        let games = try await requestGames(body: bodyString, url: url, token: token)
        return games.filter { !$0.isDLC }
    }
    
    /// Hämtar detaljer för ett specifikt spel baserat på IGDB ID
    func fetchGameDetails(id: Int) async throws -> IGDBGame {
        // Återanvänd från cachen om vi redan hämtat spelet under sessionen
        if let cached = gameDetailsCache[id] {
            return cached
        }

        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }
        
        let token = try await IGDBAuthManager.shared.getValidToken()
        
        let bodyString = """
        where id = \(id);
        fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, total_rating, aggregated_rating, involved_companies.company.name, involved_companies.developer, involved_companies.publisher, collection.name, collection.games.name, collection.games.cover.image_id, collection.games.first_release_date, franchises.name, franchises.games.name, franchises.games.cover.image_id, franchises.games.first_release_date, similar_games.name, similar_games.cover.image_id, dlcs.name, dlcs.cover.image_id, expansions.name, expansions.cover.image_id, screenshots.image_id, artworks.image_id, videos.name, videos.video_id, game_modes.name, themes.name, age_ratings.category, age_ratings.rating, category, game_type, parent_game;
        """
        
        // Hämta speldetaljer och speltid (HowLongToBeat) parallellt för att halvera laddtiden
        async let gamesTask = requestGames(body: bodyString, url: url, token: token)
        async let ttbTask = fetchTimeToBeat(gameID: id)
        
        let (games, ttb) = (try await gamesTask, await ttbTask)
        
        guard var game = games.first else {
            throw URLError(.cannotParseResponse)
        }
        
        if let ttb = ttb {
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
                totalRatingCount: game.totalRatingCount,
                category: game.category,
                gameType: game.gameType,
                parentGame: game.parentGame,
                hypes: game.hypes,
                franchises: game.franchises
            )
        }
        
        // Spara i cachen
        gameDetailsCache[id] = game
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
            request.timeoutInterval = 6 // Begränsa timeout så det inte blockerar huvudladdningen
            request.setValue(IGDBAuthConfig.clientID, forHTTPHeaderField: "Client-ID")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
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

struct TrendingGameResult: Sendable {
    let game: IGDBGame
    let primarySourceType: Int // 34 = Twitch, 5 = 24h Peak Players, 9 = Global Top Sellers, 1 = Visits, 3 = Playing
}

    /// Hämtar råa popularitetsprimitiver från IGDB PopScore (Twitch 24h, 24h Peak Players, Top Sellers, Visits, Playing)
    private func fetchPopularityPrimitives(types: [Int] = [34, 5, 9, 1, 3], limit: Int = 200) async throws -> [IGDBPopularityPrimitive] {
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

    /// Hämtar trendande spel med realtidsdata (Twitch 24h-tittare, Steam 24h-spelare, toppsäljare och besök)
    func fetchTrendingGamesWithDetails(platformIDs: [Int]) async throws -> [TrendingGameResult] {
        let token = try await IGDBAuthManager.shared.getValidToken()
        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }
        let now = Int(Date().timeIntervalSince1970)
        let sixMonthsAgo = now - (180 * 24 * 3600)
        let platformFilter = platformIDs.isEmpty
            ? ""
            : " & platforms = (\(platformIDs.map(String.init).joined(separator: ",")))"

        // 1. Primär metod: Äkta realtids PopScore med balanserad rank-poängsättning och aktualitetsbonus
        do {
            // Hämta toppsäljare (9), mest önskade kommande (10), Twitch (34), sökbesök (1), 24h-spelare (5), vill spela (2)
            let prims = try await fetchPopularityPrimitives(types: [9, 10, 34, 1, 5, 2], limit: 300)

            struct LiveTrendingMeta {
                var score: Double = 0.0
                var bestType: Int = 1
                var bestTypeValue: Double = 0.0
            }
            var metaMap: [Int: LiveTrendingMeta] = [:]

            // Gruppera per popularitetstyp för att normalisera rankningen
            // (Steam-spelare har råvärde ~0.18 medan toppsäljare och önskelistor har ~0.0004)
            let groupedByType = Dictionary(grouping: prims, by: \.popularityType)

            for (type, items) in groupedByType {
                let sortedItems = items.sorted { $0.value > $1.value }
                let typeWeight: Double = {
                    switch type {
                    case 9:  return 1.6 // Globala toppsäljare just nu
                    case 10: return 1.5 // Mest önskade kommande spelen
                    case 34: return 1.4 // Twitch 24h tittartid - dagsaktuellt!
                    case 1:  return 1.2 // Sökningar och besök på IGDB
                    case 2:  return 1.1 // Vill spela
                    case 5:  return 0.8 // 24h peak samtidiga spelare
                    default: return 1.0
                    }
                }()

                for (rank, p) in sortedItems.prefix(50).enumerated() {
                    // Placering 1 ger 100p, placering 2 ger 98p, etc.
                    let rankScore = max(10.0, 100.0 - Double(rank * 2))
                    let weightedScore = rankScore * typeWeight

                    var meta = metaMap[p.gameId] ?? LiveTrendingMeta(bestType: type)
                    meta.score += weightedScore
                    if weightedScore > meta.bestTypeValue {
                        meta.bestTypeValue = weightedScore
                        meta.bestType = type
                    }
                    metaMap[p.gameId] = meta
                }
            }

            let sortedGameIDs = metaMap.keys.sorted { (metaMap[$0]?.score ?? 0) > (metaMap[$1]?.score ?? 0) }

            if !sortedGameIDs.isEmpty {
                let topIDs = Array(sortedGameIDs.prefix(120))
                let idList = topIDs.map(String.init).joined(separator: ",")
                let bodyString = """
                fields name, summary, first_release_date, cover.image_id, platforms.id, platforms.name, genres.name, themes.id, themes.name, total_rating, total_rating_count, hypes, game_type, category, parent_game;
                where id = (\(idList)) & cover != null;
                limit \(topIDs.count);
                """
                let games = try await requestGames(body: bodyString, url: url, token: token)
                let gameMap = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
                var fetchedGames = topIDs.compactMap { gameMap[$0] }

                // Filtrera bort DLC/expansioner och olämpligt innehåll (tema 42 = Erotic)
                fetchedGames.removeAll { game in
                    game.isDLC || (game.themes?.contains(where: { $0.id == 42 || $0.name.lowercased().contains("erotic") }) ?? false)
                }

                // Tillämpa aktualitetsbonus (Freshness multiplier) så nya och kommande spel lyfts fram
                let oneYearAgo = now - (365 * 24 * 3600)
                let threeYearsAgo = now - (3 * 365 * 24 * 3600)

                var adjustedScores: [Int: Double] = [:]
                for game in fetchedGames {
                    var finalScore = metaMap[game.id]?.score ?? 0.0
                    let release = game.firstReleaseDate ?? 0

                    if release > now || release == 0 {
                        // Kommande efterlängtat spel
                        finalScore *= 1.4
                    } else if release > oneYearAgo {
                        // Släppt senaste 12 månaderna
                        finalScore *= 1.35
                    } else if release > threeYearsAgo {
                        // Släppt 1-3 år sedan
                        finalScore *= 1.0
                    } else {
                        // Äldre spel (>3 år, t.ex. gamla live-service)
                        finalScore *= 0.65
                    }
                    adjustedScores[game.id] = finalScore
                }

                let orderedGames = fetchedGames.sorted { (adjustedScores[$0.id] ?? 0) > (adjustedScores[$1.id] ?? 0) }

                let finalGames: [IGDBGame]
                if !platformIDs.isEmpty {
                    let platformSet = Set(platformIDs)
                    let matching = orderedGames.filter { game in
                        guard let pList = game.platforms else { return false }
                        return pList.contains(where: { platformSet.contains($0.id) })
                    }
                    let others = orderedGames.filter { game in
                        guard let pList = game.platforms else { return true }
                        return !pList.contains(where: { platformSet.contains($0.id) })
                    }
                    // Prioritera användarens plattformar, fyll på med globala hits vid behov
                    finalGames = Array((matching + others).prefix(30))
                } else {
                    finalGames = Array(orderedGames.prefix(30))
                }

                if !finalGames.isEmpty {
                    return finalGames.map { g in
                        TrendingGameResult(game: g, primarySourceType: metaMap[g.id]?.bestType ?? 1)
                    }
                }
            }
        } catch {
            print("[IGDBService] fetchTrendingGamesWithDetails PopScore error: \(error)")
        }

        // 2. Dynamisk fallback om PopScore inte svarar: Nya releaser med högst hype / betyg (INTE gamla all-time recensioner)
        let recentHotBody = """
        fields name, summary, first_release_date, cover.image_id, platforms.name, platforms.id, genres.name, themes.id, themes.name, total_rating, total_rating_count, hypes;
        where first_release_date > \(sixMonthsAgo) & cover != null & hypes > 0\(platformFilter);
        sort hypes desc;
        limit 30;
        """
        let hotGames = (try? await requestGames(body: recentHotBody, url: url, token: token)) ?? []
        if !hotGames.isEmpty {
            return hotGames.map { TrendingGameResult(game: $0, primarySourceType: 1) }
        }

        // 3. Andra fallback: Högst betyg senaste halvåret
        let fallbackBody = """
        fields name, summary, first_release_date, cover.image_id, platforms.name, platforms.id, genres.name, themes.id, themes.name, total_rating, total_rating_count, hypes;
        where first_release_date > \(sixMonthsAgo) & cover != null & total_rating > 70\(platformFilter);
        sort total_rating desc;
        limit 30;
        """
        let fallbackGames = try await requestGames(body: fallbackBody, url: url, token: token)
        return fallbackGames.map { TrendingGameResult(game: $0, primarySourceType: 1) }
    }

    /// Bakåtkompatibel metod som returnerar enbart IGDBGame-listan
    func fetchTrendingGames(platformIDs: [Int]) async throws -> [IGDBGame] {
        let results = try await fetchTrendingGamesWithDetails(platformIDs: platformIDs)
        return results.map(\.game)
    }

    /// Hämtar aktuella och dynamiskt populära spel från IGDB per specifik genre eller globalt (anpassat efter användarens plattformar)
    func fetchPopularGames(genre: String? = nil, platformIDs: [Int] = [], sort: String = "popularity", limit: Int = 15) async throws -> [IGDBGame] {
        // För "Alla" (genre == nil): använd den uppgraderade, balanserade trendmotorn anpassad efter plattformar
        guard let g = genre, !g.isEmpty else {
            let trendingGames = try await fetchTrendingGames(platformIDs: platformIDs)
            return Array(trendingGames.prefix(limit))
        }

        let token = try await IGDBAuthManager.shared.getValidToken()
        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }

        let platformFilter = platformIDs.isEmpty
            ? ""
            : " & platforms = (\(platformIDs.map(String.init).joined(separator: ",")))"

        // Exakta IGDB ID-klausuler för maximal träffsäkerhet
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

        // Filtrera på moderna releaser (2021+) och användarens plattformar om sådana finns
        let minTimestamp = 1609459200 // 2021-01-01
        let genreBody = """
        fields name, summary, first_release_date, cover.image_id, platforms.id, platforms.name, genres.name, themes.id, themes.name, total_rating, total_rating_count, hypes, game_type, category, parent_game;
        where \(filterClause) & first_release_date >= \(minTimestamp) & cover != null\(platformFilter);
        \(sortClause)
        limit \(limit * 2);
        """

        do {
            var genreGames = try await requestGames(body: genreBody, url: url, token: token)
            genreGames = genreGames.filter { game in
                !game.isDLC && !(game.themes?.contains(where: { $0.id == 42 || $0.name.lowercased().contains("erotic") }) ?? false)
            }
            if !genreGames.isEmpty {
                return Array(genreGames.prefix(limit))
            }
        } catch {
            print("[IGDBService] fetchPopularGames for genre \(g) fallback: \(error)")
        }

        // Bredare fallback om tidsfiltret eller plattformarna var för snäva
        let fallbackBody = """
        fields name, summary, first_release_date, cover.image_id, platforms.id, platforms.name, genres.name, themes.id, themes.name, total_rating, total_rating_count, hypes, game_type, category, parent_game;
        where \(filterClause) & cover != null;
        \(sortClause)
        limit \(limit * 2);
        """
        let fallbackGames = try await requestGames(body: fallbackBody, url: url, token: token)
        let cleanFallback = fallbackGames.filter { game in
            !game.isDLC && !(game.themes?.contains(where: { $0.id == 42 || $0.name.lowercased().contains("erotic") }) ?? false)
        }
        return Array(cleanFallback.prefix(limit))
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
    func fetchRecommendations(forGenres genres: [String], limit: Int = 35) async throws -> [IGDBGame] {
        let token = try await IGDBAuthManager.shared.getValidToken()
        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }
        let now = Int(Date().timeIntervalSince1970)
        let fiveYearsAgo = now - (1825 * 24 * 3600) // Senaste 5 åren för rikare variation

        var genreClauses: [String] = []
        for g in genres.prefix(4) {
            let safe = g.replacingOccurrences(of: "\"", with: "\\\"")
            genreClauses.append("genres.name = \"\(safe)\"")
        }
        let genreCondition = genreClauses.isEmpty ? "" : " & (\(genreClauses.joined(separator: " | ")))"

        let bodyString = """
        fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, total_rating, total_rating_count;
        where first_release_date > \(fiveYearsAgo) & first_release_date <= \(now) & cover != null & total_rating > 70 & total_rating_count > 4\(genreCondition);
        sort total_rating desc;
        limit \(max(30, limit));
        """
        return try await requestGames(body: bodyString, url: url, token: token)
    }

    /// Hämtar de officiellt liknande spelen för ett visst spel baserat på IGDBs similar_games
    func fetchSimilarGames(forGameID id: Int, limit: Int = 12) async throws -> [IGDBGame] {
        let detail = try await fetchGameDetails(id: id)
        guard let similar = detail.similarGames, !similar.isEmpty else { return [] }
        let ids = similar.prefix(limit).map { String($0.id) }.joined(separator: ",")
        let token = try await IGDBAuthManager.shared.getValidToken()
        guard let url = URL(string: "https://api.igdb.com/v4/games") else { throw URLError(.badURL) }
        let body = """
        fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, total_rating, total_rating_count;
        where id = (\(ids)) & cover != null;
        limit \(limit);
        """
        return try await requestGames(body: body, url: url, token: token)
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
            fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, total_rating, total_rating_count, involved_companies.company.name, involved_companies.developer, category, game_type, parent_game;
            \(whereClause)
            limit \(limit);
            """
        } else {
            bodyString = """
            fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, total_rating, total_rating_count, involved_companies.company.name, involved_companies.developer, category, game_type, parent_game;
            \(whereClause)
            sort \(sortOption.igdbSortClause);
            limit \(limit);
            """
        }

        let results = try await requestGames(body: bodyString, url: url, token: token)
        return results.filter { !$0.isDLC }
    }

    /// Hämtar kommande spelsläpp från IGDB
    func fetchUpcomingReleases(
        platformIDs: [Int] = [],
        fromDate: Date = Date(),
        toDate: Date? = nil,
        sortByHype: Bool = false,
        minHype: Int? = nil,
        limit: Int = 50
    ) async throws -> [IGDBGame] {
        let token = try await IGDBAuthManager.shared.getValidToken()
        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }

        let fromTs = Int(fromDate.timeIntervalSince1970)
        var conditions: [String] = [
            "first_release_date >= \(fromTs)",
            "cover != null"
        ]

        if let toDate = toDate {
            let toTs = Int(toDate.timeIntervalSince1970)
            conditions.append("first_release_date <= \(toTs)")
        }

        if let minHype = minHype {
            conditions.append("hypes >= \(minHype)")
        } else if sortByHype {
            conditions.append("hypes > 0")
        }

        if !platformIDs.isEmpty {
            let idList = platformIDs.map(String.init).joined(separator: ",")
            conditions.append("platforms = (\(idList))")
        }

        let whereClause = "where \(conditions.joined(separator: " & "));"
        let sortClause = sortByHype ? "sort hypes desc;" : "sort first_release_date asc;"

        let bodyString = """
        fields name, summary, first_release_date, cover.image_id, platforms.id, platforms.name, genres.name, themes.id, themes.name, hypes, total_rating, total_rating_count, involved_companies.company.name, involved_companies.developer, category, game_type, parent_game;
        \(whereClause)
        \(sortClause)
        limit \(limit);
        """

        let games = try await requestGames(body: bodyString, url: url, token: token)
        return games.filter { !$0.isDLC }
    }

    /// Hämtar företagsinformation (bio, logotyp, grundat år) från IGDB
    func fetchCompanyDetails(name: String, companyID: Int? = nil) async -> IGDBCompany? {
        guard let url = URL(string: "https://api.igdb.com/v4/companies") else { return nil }
        guard let token = try? await IGDBAuthManager.shared.getValidToken() else { return nil }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || companyID != nil else { return nil }

        let whereClause: String
        if let id = companyID {
            whereClause = "where id = \(id); limit 1;"
        } else {
            let safeName = trimmed.replacingOccurrences(of: "\"", with: "\\\"")
            whereClause = "where name ~ *\"\(safeName)\"*; limit 1;"
        }

        let body = """
        fields name, description, logo.image_id, start_date, country, url;
        \(whereClause)
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(IGDBAuthConfig.clientID, forHTTPHeaderField: "Client-ID")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            let companies = try JSONDecoder().decode([IGDBCompany].self, from: data)
            return companies.first
        } catch {
            return nil
        }
    }

    /// Hämtar spel för en utvecklare eller utgivare från IGDB
    func fetchGamesForCompany(
        name: String,
        companyID: Int? = nil,
        role: CompanyRole,
        sortOption: DiscoverSortOption = .popularity,
        limit: Int = 60
    ) async throws -> [IGDBGame] {
        guard let url = URL(string: "https://api.igdb.com/v4/games") else {
            throw URLError(.badURL)
        }
        let token = try await IGDBAuthManager.shared.getValidToken()

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var conditions: [String] = ["cover != null"]

        let roleField = (role == .developer) ? "involved_companies.developer = true" : "involved_companies.publisher = true"
        conditions.append(roleField)

        if let id = companyID {
            conditions.append("involved_companies.company = \(id)")
        } else if !trimmed.isEmpty {
            let safeName = trimmed.replacingOccurrences(of: "\"", with: "\\\"")
            conditions.append("involved_companies.company.name ~ *\"\(safeName)\"*")
        }

        if sortOption == .rating {
            conditions.append("total_rating != null & total_rating_count > 1")
        }

        let whereClause = "where \(conditions.joined(separator: " & "));"
        let sortClause = "sort \(sortOption.igdbSortClause);"

        let bodyString = """
        fields name, summary, first_release_date, cover.image_id, platforms.name, genres.name, total_rating, total_rating_count, category, game_type, parent_game, involved_companies.company.name, involved_companies.developer, involved_companies.publisher;
        \(whereClause)
        \(sortClause)
        limit \(limit);
        """

        let games = try await requestGames(body: bodyString, url: url, token: token)
        return games.filter { !$0.isDLC }
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
