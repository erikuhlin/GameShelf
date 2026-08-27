
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

    init(
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
        totalRatingCount: Int? = nil
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
    }

    enum CodingKeys: String, CodingKey {
        case id, name, summary, cover, platforms, genres, collection, screenshots, artworks, videos
        case dlcs, expansions, themes
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

    var releaseYear: Int? {
        guard let timestamp = firstReleaseDate else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return Calendar.current.component(.year, from: date)
    }

    var releaseDateFormatted: String? {
        guard let timestamp = firstReleaseDate else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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
    let name: String
}

struct IGDBRelatedGame: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let cover: IGDBImage?

    var coverURL: URL? { cover?.url(size: "t_cover_big") }
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

    var mainStoryFormatted: String {
        formatSeconds(hastily)
    }

    var mainExtraFormatted: String {
        formatSeconds(normally)
    }

    var completionistFormatted: String {
        formatSeconds(completely)
    }

    private func formatSeconds(_ seconds: Int?) -> String {
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
