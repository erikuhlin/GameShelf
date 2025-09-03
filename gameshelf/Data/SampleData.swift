//
//  SampleData.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//


import Foundation

enum SampleData {
    static let games: [Game] = [
        Game(title: "The Legend of Zelda: Breath of the Wild",
             platform: "Nintendo Switch",
             releaseYear: 2017,
             genres: ["Action-Adventure"],
             developer: "Nintendo",
             status: .playing,
             rating: 9,
             coverURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/0/0b/The_Legend_of_Zelda_Breath_of_the_Wild.jpg")),
        Game(title: "Red Dead Redemption 2",
             platform: "PlayStation 4",
             releaseYear: 2018,
             genres: ["Action","Adventure"],
             developer: "Rockstar Games",
             status: .completed,
             rating: 10,
             coverURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/4/44/Red_Dead_Redemption_II.jpg")),
        Game(title: "Hades",
             platform: "PC",
             releaseYear: 2020,
             genres: ["Roguelike"],
             developer: "Supergiant Games",
             status: .wishlist,
             rating: nil,
             coverURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/e/e0/Hades_cover_art.jpg")),
        Game(title: "Bloodborne",
             platform: "PlayStation 4",
             releaseYear: 2015,
             genres: ["Action RPG"],
             developer: "FromSoftware",
             status: .abandoned,
             rating: 6,
             coverURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/6/6e/Bloodborne_Cover_Wallpaper.jpg")),
        Game(title: "Super Mario Odyssey",
             platform: "Nintendo Switch",
             releaseYear: 2017,
             genres: ["Platformer"],
             developer: "Nintendo",
             status: .completed,
             rating: 9,
             coverURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/8/8d/Super_Mario_Odyssey.jpg")),
        Game(title: "Portal 2",
             platform: "PC",
             releaseYear: 2011,
             genres: ["Puzzle"],
             developer: "Valve",
             status: .completed,
             rating: 10,
             coverURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/f/f9/Portal2cover.jpg")),
        Game(title: "Persona 4",
             platform: "PlayStation 2",
             releaseYear: 2008,
             genres: ["JRPG"],
             developer: "Atlus",
             status: .wishlist,
             rating: nil,
             coverURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/5/5e/Persona_4_cover.png")),
        Game(title: "Chrono Trigger",
             platform: "SNES",
             releaseYear: 1995,
             genres: ["JRPG"],
             developer: "Square",
             status: .completed,
             rating: 10,
             coverURL: URL(string: "https://upload.wikimedia.org/wikipedia/en/2/25/Chrono_Trigger.jpg"))
    ]
}