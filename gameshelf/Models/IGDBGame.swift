
import Foundation

struct IGDBGame: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let summary: String?
    let firstReleaseDate: Int?
    let cover: IGDBImage?
    let platforms: [IGDBPlatform]?
    let genres: [IGDBGenre]?
    let totalRating: Double?
    let aggregatedRating: Double?
    let involvedCompanies: [IGDBInvolvedCompany]?
    let collection: IGDBCollection?
    let similarGames: [IGDBRelatedGame]?
    let dlcs: [IGDBRelatedGame]?
    let expansions: [IGDBRelatedGame]?
    let screenshots: [IGDBImage]?
    let artworks: [IGDBImage]?
    let videos: [IGDBVideo]?
    let gameModes: [IGDBNamedItem]?
    let themes: [IGDBNamedItem]?
    let ageRatings: [IGDBAgeRating]?
    let timeToBeat: IGDBTimeToBeat?
    let totalRatingCount: Int?
    let category: Int?
    let gameType: Int?
    let parentGame: Int?
    let versionParent: Int?
    let hypes: Int?
    let franchises: [IGDBFranchise]?

    nonisolated init(
        id: Int,
        name: String,
        summary: String? = nil,
        firstReleaseDate: Int? = nil,
        cover: IGDBImage? = nil,
        platforms: [IGDBPlatform]? = nil,
        genres: [IGDBGenre]? = nil,
        totalRating: Double? = nil,
        aggregatedRating: Double? = nil,
        involvedCompanies: [IGDBInvolvedCompany]? = nil,
        collection: IGDBCollection? = nil,
        similarGames: [IGDBRelatedGame]? = nil,
        dlcs: [IGDBRelatedGame]? = nil,
        expansions: [IGDBRelatedGame]? = nil,
        screenshots: [IGDBImage]? = nil,
        artworks: [IGDBImage]? = nil,
        videos: [IGDBVideo]? = nil,
        gameModes: [IGDBNamedItem]? = nil,
        themes: [IGDBNamedItem]? = nil,
        ageRatings: [IGDBAgeRating]? = nil,
        timeToBeat: IGDBTimeToBeat? = nil,
        totalRatingCount: Int? = nil,
        category: Int? = nil,
        gameType: Int? = nil,
        parentGame: Int? = nil,
        versionParent: Int? = nil,
        hypes: Int? = nil,
        franchises: [IGDBFranchise]? = nil
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.firstReleaseDate = firstReleaseDate
        self.cover = cover
        self.platforms = platforms
        self.genres = genres
        self.totalRating = totalRating
        self.aggregatedRating = aggregatedRating
        self.involvedCompanies = involvedCompanies
        self.collection = collection
        self.similarGames = similarGames
        self.dlcs = dlcs
        self.expansions = expansions
        self.screenshots = screenshots
        self.artworks = artworks
        self.videos = videos
        self.gameModes = gameModes
        self.themes = themes
        self.ageRatings = ageRatings
        self.timeToBeat = timeToBeat
        self.totalRatingCount = totalRatingCount
        self.category = category
        self.gameType = gameType
        self.parentGame = parentGame
        self.versionParent = versionParent
        self.hypes = hypes
        self.franchises = franchises
    }

    enum CodingKeys: String, CodingKey {
        case id, name, summary, cover, platforms, genres, collection, screenshots, artworks, videos
        case dlcs, expansions, themes, category, hypes, franchises
        case gameType = "game_type"
        case parentGame = "parent_game"
        case versionParent = "version_parent"
        case firstReleaseDate = "first_release_date"
        case totalRating = "total_rating"
        case aggregatedRating = "aggregated_rating"
        case involvedCompanies = "involved_companies"
        case similarGames = "similar_games"
        case gameModes = "game_modes"
        case ageRatings = "age_ratings"
        case timeToBeat = "time_to_beat"
        case totalRatingCount = "total_rating_count"
    }

    nonisolated var isDLC: Bool {
        // IGDB game_type / category:
        // 1: dlc_addon, 2: expansion, 5: mod, 12: fork, 13: pack, 14: update
        let dlcTypes: Set<Int> = [1, 2, 5, 12, 13, 14]
        if let type = gameType, dlcTypes.contains(type) {
            return true
        }
        if let cat = category, dlcTypes.contains(cat) {
            return true
        }
        // Om spelet har ett parent_game och inte är remake (8), remaster (9) eller fristående (4)
        if parentGame != nil {
            let type = gameType ?? category ?? -1
            if type != 8 && type != 9 && type != 4 {
                return true
            }
        }
        let lower = name.lowercased()
        if lower.contains(" - dlc") || lower.contains(" season pass") || lower.contains(" expansion pack") {
            return true
        }
        return false
    }

    /// Identifierar specialutgåvor, bundles och alternativa versioner (t.ex. Ultimate Edition, Deluxe Edition, GOTY)
    nonisolated var isSpecialEditionOrBundle: Bool {
        if versionParent != nil { return true }
        // 3: bundle, 11: port
        let bundleTypes: Set<Int> = [3, 11]
        if let type = gameType, bundleTypes.contains(type) { return true }
        if let cat = category, bundleTypes.contains(cat) { return true }

        let lower = name.lowercased()
        let editionMarkers = [
            "ultimate edition", "deluxe edition", "digital deluxe", "gold edition",
            "complete edition", "game of the year", "goty edition", "definitive edition",
            "director's cut", "directors cut", "collector's edition", "collectors edition",
            "anniversary edition", "special edition", "premium edition", "legendary edition",
            "royal edition", "expanded edition", "enhanced edition", "cross-gen bundle",
            "launch edition", "day one edition", "complete collection", "trilogy", "bundle"
        ]
        return editionMarkers.contains { lower.contains($0) }
    }

    /// Normaliserar en speltitel till dess kanoniska bastitel så att t.ex.
    /// "Cyberpunk 2077: Ultimate Edition" och "Cyberpunk 2077" matchar som samma spel.
    nonisolated static func canonicalBaseTitle(_ rawTitle: String) -> String {
        var s = rawTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Ta bort eventuella parenteser/hakparenteser på slutet, t.ex. "(PS5)" eller "[Deluxe Edition]"
        s = s.replacingOccurrences(of: #"\s*[\(\[][^\)\]]*[\)\]]\s*$"#, with: "", options: .regularExpression)

        // Vanliga utgåve- och versionssuffix att rensa bort
        let suffixes = [
            "digital deluxe edition",
            "game of the year edition",
            "collector's edition",
            "collectors edition",
            "anniversary edition",
            "definitive edition",
            "ultimate edition",
            "complete edition",
            "expanded edition",
            "enhanced edition",
            "legendary edition",
            "standard edition",
            "champion edition",
            "imperial edition",
            "komplete edition",
            "tarnished edition",
            "special edition",
            "premium edition",
            "deluxe edition",
            "royal edition",
            "launch edition",
            "day one edition",
            "goty edition",
            "gold edition",
            "full clip edition",
            "prepare to die edition",
            "the fire fades edition",
            "scholar of the first sin",
            "director's cut",
            "directors cut",
            "digital deluxe",
            "game of the year",
            "cross-gen bundle",
            "complete collection",
            "hd remaster",
            "remastered",
            "remaster",
            "remake",
            "bundle"
        ]

        // Upprepa städning ifall en titel har t.ex. ": Director's Cut Deluxe Edition"
        var didStrip = true
        while didStrip {
            didStrip = false
            for suffix in suffixes {
                let pattern = #"(?:\s*[:\-–—]\s*|\s+)"# + NSRegularExpression.escapedPattern(for: suffix) + #"$"#
                if let range = s.range(of: pattern, options: .regularExpression) {
                    s.removeSubrange(range)
                    s = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    didStrip = true
                }
            }
        }

        // Normalisera skiljetecken och mellanslag
        s = s.replacingOccurrences(of: "’", with: "'")
        s = s.replacingOccurrences(of: #"[:\-–—']+"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var releaseYear: Int? {
        guard let timestamp = firstReleaseDate else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return Calendar.current.component(.year, from: date)
    }

    var releaseDate: Date? {
        guard let timestamp = firstReleaseDate else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    var isUnreleased: Bool {
        if let date = releaseDate {
            return date >= Calendar.current.startOfDay(for: Date())
        }
        if let year = releaseYear, year > Calendar.current.component(.year, from: Date()) {
            return true
        }
        return false
    }

    var hasExactReleaseDate: Bool {
        guard let date = releaseDate else { return false }
        if isUnreleased && date.isYearPlaceholderDate {
            return false
        }
        return true
    }

    var releaseDateFormatted: String? {
        if let date = releaseDate {
            if date > Date() && date.isYearPlaceholderDate {
                if let year = releaseYear ?? Calendar.current.component(.year, from: date) as Int?, year > 0 {
                    return "Kommande \(year)"
                }
                return "Kommande"
            }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "sv_SE")
            formatter.dateStyle = .long
            return formatter.string(from: date)
        }
        if let year = releaseYear, year > 0 {
            if year > Calendar.current.component(.year, from: Date()) {
                return "Kommande \(year)"
            }
            return String(year)
        }
        return nil
    }

    var coverURL: URL? {
        guard let imageID = cover?.imageId else { return nil }
        return URL(string: "https://images.igdb.com/igdb/image/upload/t_cover_big/\(imageID).jpg")
    }

    var developerName: String? {
        involvedCompanies?.first(where: { $0.developer == true })?.company?.name
    }

    var publisherName: String? {
        involvedCompanies?.first(where: { $0.publisher == true })?.company?.name
    }

    /// Samlar alla unika spel i franchisen eller serien exklusive det aktuella spelet, sorterade kronologiskt
    var franchiseGames: [IGDBRelatedGame] {
        var all: [IGDBRelatedGame] = []
        if let colGames = collection?.games {
            all.append(contentsOf: colGames)
        }
        if let franGames = franchises?.compactMap({ $0.games }).flatMap({ $0 }) {
            all.append(contentsOf: franGames)
        }

        var seen = Set<Int>()
        seen.insert(self.id)

        var unique: [IGDBRelatedGame] = []
        for g in all {
            if !seen.contains(g.id) {
                seen.insert(g.id)
                unique.append(g)
            }
        }

        return unique.sorted { (g1, g2) in
            (g1.firstReleaseDate ?? 0) < (g2.firstReleaseDate ?? 0)
        }
    }

    var franchiseName: String? {
        if let name = collection?.name, !name.isEmpty { return name }
        if let name = franchises?.first?.name, !name.isEmpty { return name }
        return nil
    }
}

struct IGDBImage: Decodable, Identifiable, Sendable {
    let id: Int
    let imageId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case imageId = "image_id"
    }
}

extension IGDBImage {
    func url(size: String) -> URL? {
        guard let imageId = imageId else { return nil }
        return URL(string: "https://images.igdb.com/igdb/image/upload/\(size)/\(imageId).jpg")
    }
}

struct IGDBPlatform: Decodable, Sendable {
    let id: Int
    let name: String
}

struct IGDBGenre: Decodable, Sendable {
    let id: Int
    let name: String
}

struct IGDBNamedItem: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
}

struct IGDBInvolvedCompany: Decodable, Sendable {
    let company: IGDBNamedItem?
    let developer: Bool?
    let publisher: Bool?
}

struct IGDBCollection: Decodable, Sendable {
    let id: Int
    let name: String?
    let games: [IGDBRelatedGame]?
}

struct IGDBFranchise: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let games: [IGDBRelatedGame]?
}

struct IGDBRelatedGame: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let cover: IGDBImage?
    let firstReleaseDate: Int?
    let totalRating: Double?
    let rating: Double?

    init(
        id: Int,
        name: String? = nil,
        cover: IGDBImage? = nil,
        firstReleaseDate: Int? = nil,
        totalRating: Double? = nil,
        rating: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.cover = cover
        self.firstReleaseDate = firstReleaseDate
        self.totalRating = totalRating
        self.rating = rating
    }

    enum CodingKeys: String, CodingKey {
        case id, name, cover
        case firstReleaseDate = "first_release_date"
        case totalRating = "total_rating"
        case rating
    }

    var coverURL: URL? { cover?.url(size: "t_cover_big") }

    var releaseYear: Int? {
        guard let ts = firstReleaseDate else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        return Calendar.current.component(.year, from: date)
    }

    var displayRating: Int? {
        if let tr = totalRating, tr > 0 { return Int(round(tr)) }
        if let r = rating, r > 0 { return Int(round(r)) }
        return nil
    }

    var ratingOutOfTen: Double? {
        if let tr = totalRating, tr > 0 { return tr / 10.0 }
        if let r = rating, r > 0 { return r / 10.0 }
        return nil
    }
}

struct IGDBVideo: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let videoID: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case videoID = "video_id"
    }

    var youtubeURL: URL? {
        guard let vID = videoID else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(vID)")
    }

    var thumbnailURL: URL? {
        guard let vID = videoID else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(vID)/hqdefault.jpg")
    }
}

struct IGDBAgeRating: Decodable, Identifiable, Sendable {
    let id: Int
    let category: Int?
    let rating: Int?

    var label: String? {
        guard let category = category, let rating = rating else { return nil }
        switch category {
        case 2:
            let pegi = [1: "3", 2: "7", 3: "12", 4: "16", 5: "18"][rating]
            return pegi.map { "PEGI \($0)" }
        case 1:
            let esrb = [6: "RP", 7: "EC", 8: "E", 9: "E10+", 10: "T", 11: "M", 12: "AO"][rating]
            return esrb.map { "ESRB \($0)" }
        default:
            return nil
        }
    }
}

struct IGDBTimeToBeat: Decodable, Sendable {
    let id: Int?
    let gameId: Int?
    let hastily: Int?
    let normally: Int?
    let completely: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case hastily
        case normally
        case completely
    }

    var mainStoryHours: Int? {
        guard let hastily = hastily, hastily > 0 else { return nil }
        return Int(round(Double(hastily) / 3600.0))
    }

    var mainExtraHours: Int? {
        guard let normally = normally, normally > 0 else { return nil }
        return Int(round(Double(normally) / 3600.0))
    }

    var completionistHours: Int? {
        guard let completely = completely, completely > 0 else { return nil }
        return Int(round(Double(completely) / 3600.0))
    }

    nonisolated var mainStoryFormatted: String {
        formatSeconds(hastily)
    }

    nonisolated var mainExtraFormatted: String {
        formatSeconds(normally)
    }

    nonisolated var completionistFormatted: String {
        formatSeconds(completely)
    }

    nonisolated private func formatSeconds(_ seconds: Int?) -> String {
        guard let seconds = seconds, seconds > 0 else { return "—" }
        let hours = Int(round(Double(seconds) / 3600.0))
        if hours == 0 {
            let minutes = max(1, Int(round(Double(seconds) / 60.0)))
            return "\(minutes) min"
        }
        return "\(hours) tim"
    }

    var entries: [(String, Int)] {
        [("Snabb", hastily), ("Huvudstory", normally), ("Komplett", completely)].compactMap { label, seconds in
            seconds.map { (label, $0) }
        }
    }
}
