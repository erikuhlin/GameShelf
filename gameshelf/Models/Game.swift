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
    var platform: String
    var releaseYear: Int
    var genres: [String]
    var developer: String
    var status: PlayStatus
    var rating: Int?            // 1–10
    var coverURL: URL?
}