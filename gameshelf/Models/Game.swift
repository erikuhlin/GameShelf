//
//  Game.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import Foundation

struct GameTodoItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var isDone: Bool = false
}

struct Game: Identifiable, Hashable, Codable {
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

    var releaseDate: Date? {
        guard let timestamp = firstReleaseDate else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    var isUnreleased: Bool {
        if let date = releaseDate {
            return date > Date()
        }
        if releaseYear > Calendar.current.component(.year, from: Date()) {
            return true
        }
        return false
    }

    enum CodingKeys: String, CodingKey {
        case id, title, platforms, releaseYear, genres, developers, status, rating
        case igdbRating, rawgRating, coverURL, igdbID, firstReleaseDate, estimatedHours, isOwned, notes, todos
    }

    init(
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
        todos: [GameTodoItem] = []
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        platforms = try container.decode([String].self, forKey: .platforms)
        releaseYear = try container.decode(Int.self, forKey: .releaseYear)
        genres = try container.decode([String].self, forKey: .genres)
        developers = try container.decode([String].self, forKey: .developers)
        status = try container.decode(PlayStatus.self, forKey: .status)
        rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        igdbRating = try container.decodeIfPresent(Double.self, forKey: .igdbRating)
            ?? container.decodeIfPresent(Double.self, forKey: .rawgRating)
        coverURL = try container.decodeIfPresent(URL.self, forKey: .coverURL)
        igdbID = try container.decodeIfPresent(Int.self, forKey: .igdbID)
        firstReleaseDate = try container.decodeIfPresent(Int.self, forKey: .firstReleaseDate)
        estimatedHours = try container.decodeIfPresent(Int.self, forKey: .estimatedHours)
        isOwned = try container.decodeIfPresent(Bool.self, forKey: .isOwned) ?? true
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        todos = try container.decodeIfPresent([GameTodoItem].self, forKey: .todos) ?? []
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
    }
}
