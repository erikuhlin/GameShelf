//
//  gameshelfTests.swift
//  gameshelfTests
//
//  Created by Erik Uhlin on 2025-08-25.
//

import Foundation
import Testing
@testable import Gameshelf

struct gameshelfTests {

    @Test func example() async throws {
        // Basic test sanity
    }

    @Test func playStatusDecodesLegacyAndNewValues() throws {
        let decoder = JSONDecoder()

        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Completed\"".utf8)) == .completed)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Klar\"".utf8)) == .completed)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Genomspelat\"".utf8)) == .completed)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"100 %\"".utf8)) == .completed)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Spelar\"".utf8)) == .playing)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Spelar nu\"".utf8)) == .playing)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Aktiv\"".utf8)) == .playing)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Pågående\"".utf8)) == .playing)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Backlog\"".utf8)) == .notStarted)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Ej spelat\"".utf8)) == .notStarted)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Inte påbörjat\"".utf8)) == .notStarted)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Inte spelat\"".utf8)) == .notStarted)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Pausat\"".utf8)) == .paused)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Tar paus\"".utf8)) == .paused)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Droppat\"".utf8)) == .abandoned)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Avbruten\"".utf8)) == .abandoned)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Avbrutet\"".utf8)) == .abandoned)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Slutat spela\"".utf8)) == .abandoned)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Önskelista\"".utf8)) == .notStarted)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"wishlist\"".utf8)) == .notStarted)
    }

    @Test func gameMigratesLegacyBacklogAndWishlist() throws {
        let backlogJson = """
        {
          "id": "00000000-0000-0000-0000-000000000010",
          "title": "Chrono Trigger",
          "platforms": ["SNES"],
          "releaseYear": 1995,
          "genres": ["RPG"],
          "developers": ["Square"],
          "status": "Backlog",
          "rating": 10
        }
        """
        let backlogGame = try JSONDecoder().decode(Game.self, from: Data(backlogJson.utf8))
        #expect(backlogGame.status == .notStarted)
        #expect(backlogGame.isBacklog == true)
        #expect(backlogGame.isOwned == true)

        let wishlistJson = """
        {
          "id": "00000000-0000-0000-0000-000000000011",
          "title": "Silksong",
          "platforms": ["PC"],
          "releaseYear": 2026,
          "genres": ["Metroidvania"],
          "developers": ["Team Cherry"],
          "status": "Önskelista",
          "rating": 0
        }
        """
        let wishlistGame = try JSONDecoder().decode(Game.self, from: Data(wishlistJson.utf8))
        #expect(wishlistGame.status == .notStarted)
        #expect(wishlistGame.isOwned == false)
    }

    @Test func dynamicStatusTextsAndIcons() {
        let single: [GamePlayType] = [.singlePlayer]
        let multi: [GamePlayType] = [.multiplayer]
        let ongoing: [GamePlayType] = [.ongoing]

        #expect(PlayStatus.notStarted.title(for: single) == "Inte påbörjat")
        #expect(PlayStatus.playing.title(for: single) == "Spelar nu")
        #expect(PlayStatus.paused.title(for: single) == "Pausat")
        #expect(PlayStatus.completed.title(for: single) == "Genomspelat")
        #expect(PlayStatus.abandoned.title(for: single) == "Avbrutet")

        #expect(PlayStatus.notStarted.title(for: multi) == "Inte spelat")
        #expect(PlayStatus.playing.title(for: multi) == "Aktiv")
        #expect(PlayStatus.paused.title(for: multi) == "Tar paus")
        #expect(PlayStatus.completed.title(for: multi) == "Inte aktiv längre")
        #expect(PlayStatus.abandoned.title(for: multi) == "Slutat spela")

        #expect(PlayStatus.playing.title(for: ongoing) == "Aktiv")
        #expect(PlayStatus.completed.title(for: ongoing) == "Inte aktiv längre")

        #expect(PlayStatus.playing.icon(for: single) == "play.fill")
        #expect(PlayStatus.playing.icon(for: multi) == "circle.fill")
    }

    @Test func playTypeInference() {
        let mmoTypes = Game.inferPlayTypes(genres: ["Massively Multiplayer Online (MMO)"], title: "World of Warcraft")
        #expect(mmoTypes.contains(.ongoing))
        #expect(mmoTypes.contains(.multiplayer))

        let coopTypes = Game.inferPlayTypes(genres: ["Shooter"], title: "Helldivers 2", gameModes: ["Co-operative", "Multiplayer"])
        #expect(coopTypes.contains(.coOp))
        #expect(coopTypes.contains(.multiplayer))

        let hllTypes = Game.inferPlayTypes(genres: ["Shooter", "Simulator"], title: "Hell Let Loose: Vietnam")
        #expect(hllTypes.contains(.multiplayer))
        #expect(hllTypes.contains(.ongoing))

        let codTypes = Game.inferPlayTypes(genres: ["Shooter"], title: "Call of Duty: Warzone")
        #expect(codTypes.contains(.multiplayer))
        #expect(codTypes.contains(.ongoing))

        let singleTypes = Game.inferPlayTypes(genres: ["Adventure"], title: "Zelda", gameModes: ["Single player"])
        #expect(singleTypes.contains(.singlePlayer))
    }

    @Test func legacySinglePlayerUpgradesToMultiplayerOnDecode() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000099",
          "title": "Hell Let Loose: Vietnam",
          "platforms": ["PlayStation 5"],
          "releaseYear": 2024,
          "genres": ["Shooter", "Simulator"],
          "developers": ["Team17"],
          "status": "Spelar nu",
          "playTypes": ["singlePlayer"]
        }
        """
        let game = try JSONDecoder().decode(Game.self, from: Data(json.utf8))
        #expect(game.isMultiplayerOrOngoing == true)
        #expect(game.playTypes.contains(.multiplayer))
    }

    @Test func gameDecodesLegacyRAWGRating() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "title": "Test Game",
          "platforms": ["PC"],
          "releaseYear": 2025,
          "genres": [],
          "developers": [],
          "status": "Playing",
          "rating": 8,
          "rawgRating": 4.5,
          "notes": ""
        }
        """
        let game = try JSONDecoder().decode(Game.self, from: Data(json.utf8))
        #expect(game.status == .playing)
        #expect(game.igdbRating == 4.5)
        #expect(game.isOwned == true)
    }

    @Test func gameDecodesExplicitOwnership() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000002",
          "title": "Retro Memory",
          "platforms": ["PlayStation 2"],
          "releaseYear": 2004,
          "genres": ["Action"],
          "developers": ["Capcom"],
          "status": "Klar",
          "isOwned": false
        }
        """
        let game = try JSONDecoder().decode(Game.self, from: Data(json.utf8))
        #expect(game.isOwned == false)
        #expect(game.status == .completed)
    }

    @Test func gameCollectionEncodesAndDecodesCorrectly() throws {
        let gameID1 = UUID()
        let gameID2 = UUID()
        let collection = GameCollection(
            name: "🎃 Halloween",
            description: "Läskiga spel för hösten",
            gameIDs: [gameID1, gameID2]
        )

        let data = try JSONEncoder().encode(collection)
        let decoded = try JSONDecoder().decode(GameCollection.self, from: data)

        #expect(decoded.name == "🎃 Halloween")
        #expect(decoded.description == "Läskiga spel för hösten")
        #expect(decoded.gameIDs == [gameID1, gameID2])
    }

    @Test func igdbTimeToBeatConvertsSecondsToHours() throws {
        let json = """
        {
          "id": 1,
          "game_id": 25076,
          "hastily": 175371,
          "normally": 318200,
          "completely": 749781
        }
        """
        let ttb = try JSONDecoder().decode(IGDBTimeToBeat.self, from: Data(json.utf8))
        #expect(ttb.mainStoryFormatted == "49 tim")
        #expect(ttb.mainExtraFormatted == "88 tim")
        #expect(ttb.completionistFormatted == "208 tim")
    }

    @Test func igdbGameDecodesAgeRatingsWithMissingCategoryOrRating() throws {
        let json = """
        [
          {
            "id": 119171,
            "name": "Baldur's Gate 3",
            "age_ratings": [
              { "id": 204993 },
              { "id": 162025, "category": 2 }
            ]
          }
        ]
        """
        let games = try JSONDecoder().decode([IGDBGame].self, from: Data(json.utf8))
        #expect(games.count == 1)
        #expect(games.first?.name == "Baldur's Gate 3")
        #expect(games.first?.ageRatings?.count == 2)
    }
}
