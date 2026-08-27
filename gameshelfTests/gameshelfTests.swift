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
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"100 %\"".utf8)) == .completed)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Spelar\"".utf8)) == .playing)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Spelar nu\"".utf8)) == .playing)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Pågående\"".utf8)) == .playing)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Backlog\"".utf8)) == .backlog)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Ej spelat\"".utf8)) == .backlog)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Pausat\"".utf8)) == .paused)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Droppat\"".utf8)) == .abandoned)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Avbruten\"".utf8)) == .abandoned)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Avbrutet\"".utf8)) == .abandoned)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Önskelista\"".utf8)) == .wishlist)
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
