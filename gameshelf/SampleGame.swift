//
//  SampleGame.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//


//  Explore+SampleData.swift
//  Gameshelf

import Foundation

struct SampleGame { let title: String; let platform: String; let rating: Int }

func sampleGames(for prefs: ExplorePrefs) -> [SampleGame] {
    let base = [
        SampleGame(title: "Metroid Prime Remastered", platform: "Nintendo Switch", rating: 9),
        SampleGame(title: "Final Fantasy VII Rebirth", platform: "PlayStation 5", rating: 9),
        SampleGame(title: "Hades II", platform: "PC", rating: 10)
    ]
    if prefs.platforms.isEmpty { return base }
    return base.filter { prefs.platforms.contains($0.platform) }
}

func sampleTrending(for prefs: ExplorePrefs) -> [SampleGame] {
    [
        SampleGame(title: "Elden Ring: Shadow of the Erdtree", platform: "PlayStation 5", rating: 10),
        SampleGame(title: "Baldur's Gate 3", platform: "PC", rating: 10),
        SampleGame(title: "The Legend of Zelda: TOTK", platform: "Nintendo Switch", rating: 10)
    ].filter { prefs.platforms.isEmpty || prefs.platforms.contains($0.platform) }
}