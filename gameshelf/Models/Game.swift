//
//  Game.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import Foundation

struct GameTodoItem: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var title: String
    var isDone: Bool = false
}

enum GameStoryProgress: String, Codable, CaseIterable, Identifiable, Sendable {
    case justStarted = "Precis börjat"
    case midway = "Mitt i det"
    case nearEnd = "Närmar mig slutet"
    case completed = "Klar"

    var id: String { rawValue }
}

struct Game: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var title: String
    var platforms: [String]      // changed from String to list
    var releaseYear: Int
    var genres: [String]
    var developers: [String]     // changed from String to list
    var status: PlayStatus
    var rating: Int?             // user rating, 1–10
    var igdbRating: Double?      // IGDB rating, 0–10
    var coverURL: URL?
    var igdbID: Int?
    var firstReleaseDate: Int?   // Unix timestamp (seconds)
    var estimatedHours: Int?     // Estimated playtime in hours (from IGDB timeToBeat)
    var isOwned: Bool = true     // true: I ägo / aktiv samling, false: Spelminne / tidigare spelad
    var notes: String = ""       // personal notes
    var todos: [GameTodoItem] = [] // checklist / to-do items
    var dateAdded: Date = Date() // tidpunkt då spelet lades till i biblioteket

    // Nya fält för utökat statussystem och speltyper
    var playTypes: [GamePlayType] = [.singlePlayer]
    var isBacklog: Bool = false
    var priority: PlayPriority = .none
    var lastPlayedDate: Date? = nil
    var completedYear: Int? = nil
    var completedDate: Date? = nil
    var storyProgress: GameStoryProgress? = nil
    var hoursPlayed: Double? = nil
    var progressNote: String? = nil
    var noteUpdatedAt: Date? = nil

    // MARK: - Computed Helpers
    var effectiveHoursPlayed: Double {
        get {
            if let hp = hoursPlayed { return hp }
            if let est = estimatedHours { return Double(est) }
            return 0.0
        }
        set {
            hoursPlayed = newValue
            estimatedHours = Int(round(newValue))
        }
    }
    var isMultiplayerOrOngoing: Bool {
        playTypes.contains(.multiplayer) || playTypes.contains(.ongoing)
    }

    var isSinglePlayer: Bool {
        playTypes.contains(.singlePlayer)
    }

    var statusDisplayTitle: String {
        status.title(for: playTypes)
    }

    var statusDisplayIcon: String {
        status.icon(for: playTypes)
    }

    var lastPlayedFormatted: String? {
        guard let date = lastPlayedDate else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Senast spelat idag"
        } else if calendar.isDateInYesterday(date) {
            return "Senast spelat igår"
        } else {
            let components = calendar.dateComponents([.day], from: date, to: Date())
            let days = max(1, components.day ?? 1)
            if days < 7 {
                return "Senast spelat för \(days) dagar sedan"
            } else if days < 30 {
                let weeks = max(1, days / 7)
                return weeks == 1 ? "Senast spelat för 1 vecka sedan" : "Senast spelat för \(weeks) veckor sedan"
            } else {
                let months = max(1, days / 30)
                return months == 1 ? "Senast spelat för 1 månad sedan" : "Senast spelat för \(months) månader sedan"
            }
        }
    }

    var releaseDate: Date? {
        guard let timestamp = firstReleaseDate else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    /// Sant om spelet har ett spikat, exakt lanseringsdatum (och inte en platshållare såsom 31 dec)
    var hasExactReleaseDate: Bool {
        guard let date = releaseDate else { return false }
        if isUnreleased && date.isYearPlaceholderDate {
            return false
        }
        return true
    }

    var isUnreleased: Bool {
        if let date = releaseDate {
            return date > Date()
        }
        if releaseYear >= Calendar.current.component(.year, from: Date()) {
            return true
        }
        return false
    }

    // MARK: - Play Type Inferens
    static func inferPlayTypes(genres: [String], title: String, gameModes: [String]? = nil) -> [GamePlayType] {
        var types: Set<GamePlayType> = []

        let allModes = (gameModes ?? []).map { $0.lowercased() }
        let allGenres = genres.map { $0.lowercased() }
        let lowerTitle = title.lowercased()

        for mode in allModes {
            if mode.contains("single player") || mode == "singleplayer" {
                types.insert(.singlePlayer)
            }
            if mode.contains("multiplayer") || mode.contains("battle royale") || mode.contains("mmo") || mode.contains("split screen") {
                types.insert(.multiplayer)
            }
            if mode.contains("co-operative") || mode.contains("cooperative") || mode.contains("coop") || mode.contains("co-op") {
                types.insert(.coOp)
            }
        }

        let combinedText = (lowerTitle + " " + allGenres.joined(separator: " ") + " " + allModes.joined(separator: " "))

        let multiplayerKeywords = [
            "multiplayer", "online", "co-op", "cooperative", "coop", "samarbete", "split screen",
            "battle royale", "mmo", "mmorpg", "massively multiplayer", "live service",
            "hell let loose", "helldivers", "warzone", "apex legends", "fortnite", "destiny",
            "overwatch", "valorant", "counter-strike", "world of warcraft", "final fantasy xiv",
            "league of legends", "dota", "rocket league", "rainbow six", "rainbow 6", "genshin impact",
            "battlefield", "call of duty", "pubg", "dead by daylight", "squad", "rust", "dayz",
            "sea of thieves", "deep rock galactic", "warframe", "smite", "team fortress",
            "street fighter", "tekken", "mortal kombat", "smash bros", "overcooked", "it takes two",
            "among us", "phasmophobia", "lethal company", "enlisted", "insurgency", "arma",
            "fall guys", "roblox", "hunt: showdown", "the finals", "arc raiders", "escape from tarkov",
            "tarkov", "chivalry", "mordhau", "payday", "left 4 dead", "back 4 blood", "borderlands",
            "diablo", "path of exile", "fifa", "fc 24", "fc 25", "ea sports", "nba 2k", "madden", "nhl"
        ]

        let ongoingKeywords = [
            "mmo", "mmorpg", "massively multiplayer", "live service", "battle royale",
            "hell let loose", "helldivers", "warzone", "apex legends", "fortnite", "destiny",
            "overwatch", "valorant", "counter-strike", "world of warcraft", "final fantasy xiv",
            "league of legends", "dota", "rocket league", "rainbow six", "rainbow 6",
            "genshin impact", "pubg", "dead by daylight", "rust", "sea of thieves", "warframe",
            "the finals", "roblox", "fall guys", "hunt: showdown", "escape from tarkov", "tarkov"
        ]

        for kw in multiplayerKeywords {
            if combinedText.contains(kw) {
                types.insert(.multiplayer)
                break
            }
        }

        for kw in ongoingKeywords {
            if combinedText.contains(kw) {
                types.insert(.ongoing)
                types.insert(.multiplayer)
                break
            }
        }

        if combinedText.contains("co-op") || combinedText.contains("cooperative") || combinedText.contains("coop") || combinedText.contains("samarbete") {
            types.insert(.coOp)
        }

        // Standardvärde singlePlayer om inget annat angetts
        if types.isEmpty {
            types.insert(.singlePlayer)
        }

        return GamePlayType.allCases.filter { types.contains($0) }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, platforms, releaseYear, genres, developers, status, rating
        case igdbRating, rawgRating, coverURL, igdbID, firstReleaseDate, estimatedHours, isOwned, notes, todos, dateAdded
        case playTypes, isBacklog, priority, lastPlayedDate
        case completedYear, completedDate, storyProgress
        case hoursPlayed, progressNote, noteUpdatedAt
    }

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        platforms: [String],
        releaseYear: Int,
        genres: [String],
        developers: [String],
        status: PlayStatus,
        rating: Int?,
        igdbRating: Double? = nil,
        coverURL: URL?,
        igdbID: Int? = nil,
        firstReleaseDate: Int? = nil,
        estimatedHours: Int? = nil,
        isOwned: Bool = true,
        notes: String = "",
        todos: [GameTodoItem] = [],
        dateAdded: Date = Date(),
        playTypes: [GamePlayType]? = nil,
        isBacklog: Bool = false,
        priority: PlayPriority = .none,
        lastPlayedDate: Date? = nil,
        completedYear: Int? = nil,
        completedDate: Date? = nil,
        storyProgress: GameStoryProgress? = nil,
        hoursPlayed: Double? = nil,
        progressNote: String? = nil,
        noteUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.platforms = platforms
        self.releaseYear = releaseYear
        self.genres = genres
        self.developers = developers
        self.status = status
        self.rating = rating
        self.igdbRating = igdbRating
        self.coverURL = coverURL
        self.igdbID = igdbID
        self.firstReleaseDate = firstReleaseDate
        self.estimatedHours = estimatedHours
        self.isOwned = isOwned
        self.notes = notes
        self.todos = todos
        self.dateAdded = dateAdded
        self.playTypes = playTypes ?? Game.inferPlayTypes(genres: genres, title: title)
        self.isBacklog = isBacklog
        self.priority = priority
        self.lastPlayedDate = lastPlayedDate
        self.completedYear = completedYear
        self.completedDate = completedDate
        self.storyProgress = storyProgress
        self.hoursPlayed = hoursPlayed
        self.progressNote = progressNote
        self.noteUpdatedAt = noteUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        platforms = try container.decode([String].self, forKey: .platforms)
        releaseYear = try container.decode(Int.self, forKey: .releaseYear)
        genres = try container.decode([String].self, forKey: .genres)
        developers = try container.decode([String].self, forKey: .developers)

        // Robust bakåtkompatibel status-migrering
        var decodedStatus: PlayStatus = .notStarted
        var legacyWasBacklog = false
        var legacyWasWishlist = false

        if let rawStatusString = try? container.decode(String.self, forKey: .status) {
            let lower = rawStatusString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if lower == "backlog" {
                legacyWasBacklog = true
                decodedStatus = .notStarted
            } else if lower == "wishlist" || lower == "önskelista" {
                legacyWasWishlist = true
                decodedStatus = .notStarted
            } else {
                // Skapa en avkodare via sub-container för PlayStatus
                let statusDecoder = try container.superDecoder(forKey: .status)
                decodedStatus = (try? PlayStatus(from: statusDecoder)) ?? .notStarted
            }
        } else if let st = try? container.decode(PlayStatus.self, forKey: .status) {
            decodedStatus = st
        }

        status = decodedStatus

        rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        igdbRating = try container.decodeIfPresent(Double.self, forKey: .igdbRating)
            ?? container.decodeIfPresent(Double.self, forKey: .rawgRating)
        coverURL = try container.decodeIfPresent(URL.self, forKey: .coverURL)
        igdbID = try container.decodeIfPresent(Int.self, forKey: .igdbID)
        firstReleaseDate = try container.decodeIfPresent(Int.self, forKey: .firstReleaseDate)
        estimatedHours = try container.decodeIfPresent(Int.self, forKey: .estimatedHours)

        var decodedOwned = try container.decodeIfPresent(Bool.self, forKey: .isOwned) ?? true
        if legacyWasWishlist {
            decodedOwned = false
        }
        isOwned = decodedOwned

        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        todos = try container.decodeIfPresent([GameTodoItem].self, forKey: .todos) ?? []
        dateAdded = try container.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date()

        // Nya fält
        if let storedBacklog = try? container.decode(Bool.self, forKey: .isBacklog) {
            isBacklog = storedBacklog
        } else {
            isBacklog = legacyWasBacklog
        }

        if let storedTypes = try? container.decode([GamePlayType].self, forKey: .playTypes), !storedTypes.isEmpty {
            if storedTypes == [.singlePlayer] {
                let reInferred = Game.inferPlayTypes(genres: genres, title: title)
                if reInferred.contains(.multiplayer) || reInferred.contains(.ongoing) || reInferred.contains(.coOp) {
                    playTypes = reInferred
                } else {
                    playTypes = storedTypes
                }
            } else {
                playTypes = storedTypes
            }
        } else {
            playTypes = Game.inferPlayTypes(genres: genres, title: title)
        }

        priority = (try? container.decodeIfPresent(PlayPriority.self, forKey: .priority)) ?? .none
        lastPlayedDate = try? container.decodeIfPresent(Date.self, forKey: .lastPlayedDate)
        completedYear = try? container.decodeIfPresent(Int.self, forKey: .completedYear)
        completedDate = try? container.decodeIfPresent(Date.self, forKey: .completedDate)
        storyProgress = try? container.decodeIfPresent(GameStoryProgress.self, forKey: .storyProgress)
        hoursPlayed = try? container.decodeIfPresent(Double.self, forKey: .hoursPlayed)
        progressNote = try? container.decodeIfPresent(String.self, forKey: .progressNote)
        noteUpdatedAt = try? container.decodeIfPresent(Date.self, forKey: .noteUpdatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(platforms, forKey: .platforms)
        try container.encode(releaseYear, forKey: .releaseYear)
        try container.encode(genres, forKey: .genres)
        try container.encode(developers, forKey: .developers)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(igdbRating, forKey: .igdbRating)
        try container.encodeIfPresent(coverURL, forKey: .coverURL)
        try container.encodeIfPresent(igdbID, forKey: .igdbID)
        try container.encodeIfPresent(firstReleaseDate, forKey: .firstReleaseDate)
        try container.encodeIfPresent(estimatedHours, forKey: .estimatedHours)
        try container.encode(isOwned, forKey: .isOwned)
        try container.encode(notes, forKey: .notes)
        try container.encode(todos, forKey: .todos)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(playTypes, forKey: .playTypes)
        try container.encode(isBacklog, forKey: .isBacklog)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(lastPlayedDate, forKey: .lastPlayedDate)
        try container.encodeIfPresent(completedYear, forKey: .completedYear)
        try container.encodeIfPresent(completedDate, forKey: .completedDate)
        try container.encodeIfPresent(storyProgress, forKey: .storyProgress)
        try container.encodeIfPresent(hoursPlayed, forKey: .hoursPlayed)
        try container.encodeIfPresent(progressNote, forKey: .progressNote)
        try container.encodeIfPresent(noteUpdatedAt, forKey: .noteUpdatedAt)
    }
}

// MARK: - Date Helpers
extension Date {
    /// Kollar om ett datum är ett platshållardatum (t.ex. 31 december som IGDB sätter för spel med endast känt år eller kvartal)
    var isYearPlaceholderDate: Bool {
        var calUTC = Calendar(identifier: .gregorian)
        calUTC.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let compsUTC = calUTC.dateComponents([.month, .day], from: self)
        if compsUTC.month == 12 && compsUTC.day == 31 {
            return true
        }

        let compsLocal = Calendar.current.dateComponents([.month, .day], from: self)
        return compsLocal.month == 12 && compsLocal.day == 31
    }
}
