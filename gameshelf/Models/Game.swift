//
//  Game.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//


import Foundation

struct Game: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var platforms: [String]      // changed from String to list
    var releaseYear: Int
    var genres: [String]
    var developers: [String]     // changed from String to list
    var status: PlayStatus
    var rating: Int?             // user rating, 1–10
    var rawgRating: Double?      // RAWG rating, 0–5
    var coverURL: URL?
    var notes: String = ""       // personal notes
}
