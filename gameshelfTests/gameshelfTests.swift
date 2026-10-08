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
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"abandoned\"".utf8)) == .abandoned)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Avslutat\"".utf8)) == .abandoned)
        #expect(try decoder.decode(PlayStatus.self, from: Data("\"Slutat spela\"".utf8)) == .completed)
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
        #expect(PlayStatus.abandoned.title(for: single) == "Avslutat")

        #expect(PlayStatus.notStarted.title(for: multi) == "Inte spelat")
        #expect(PlayStatus.playing.title(for: multi) == "Aktiv")
        #expect(PlayStatus.paused.title(for: multi) == "Pausat")
        #expect(PlayStatus.completed.title(for: multi) == "Arkiverad")
        #expect(PlayStatus.abandoned.title(for: multi) == "Avslutat")

        #expect(PlayStatus.playing.title(for: ongoing) == "Aktiv")
        #expect(PlayStatus.completed.title(for: ongoing) == "Arkiverad")
        #expect(PlayStatus.abandoned.title(for: ongoing) == "Avslutat")

        #expect(PlayStatus.playing.icon(for: single) == "play.fill")
        #expect(PlayStatus.playing.icon(for: multi) == "circle.fill")
        #expect(PlayStatus.abandoned.icon(for: single) == "xmark.circle.fill")
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

    @Test func supabaseDateParserParsesVariousFormats() {
        // Postgres timestamptz (6 mikrosekundsiffror och tidszon)
        let pgDate = SupabaseDateParser.parse("2025-08-25T14:30:00.123456+00:00")
        #expect(pgDate != nil)
        if let d = pgDate {
            let cal = Calendar(identifier: .gregorian)
            var utcCal = cal
            utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
            #expect(utcCal.component(.year, from: d) == 2025)
            #expect(utcCal.component(.month, from: d) == 8)
            #expect(utcCal.component(.day, from: d) == 25)
            #expect(utcCal.component(.hour, from: d) == 14)
            #expect(utcCal.component(.minute, from: d) == 30)
        }

        // JavaScript toISOString (3 millisekunder och Z)
        let jsDate = SupabaseDateParser.parse("2026-01-10T09:15:20.123Z")
        #expect(jsDate != nil)

        // ISO8601 utan millisekunder
        let stdDate = SupabaseDateParser.parse("2026-01-10T09:15:20Z")
        #expect(stdDate != nil)

        // Tom eller ogiltig sträng
        #expect(SupabaseDateParser.parse("") == nil)
        #expect(SupabaseDateParser.parse(nil) == nil)
        #expect(SupabaseDateParser.parse("inte ett datum") == nil)
    }

    @Test func priceWatcherTitleMatchPreventsFalsePositives() {
        // Skapa testbara fall för titlar
        let p = PriceWatcherService.shared

        // GTA 6 / GTA VI får INTE matcha GTA Vice City
        #expect(!p.testIsTitleMatch(gameTitle: "Grand Theft Auto VI", dealTitle: "Grand Theft Auto: Vice City  The Definitive Edition"))
        #expect(!p.testIsTitleMatch(gameTitle: "Grand Theft Auto 6", dealTitle: "Grand Theft Auto: Vice City  The Definitive Edition"))
        #expect(!p.testIsTitleMatch(gameTitle: "Grand Theft Auto", dealTitle: "Grand Theft Auto V"))
        #expect(!p.testIsTitleMatch(gameTitle: "Grand Theft Auto", dealTitle: "Grand Theft Auto IV"))
        #expect(!p.testIsTitleMatch(gameTitle: "Grand Theft Auto V", dealTitle: "Grand Theft Auto: Vice City"))
        #expect(!p.testIsTitleMatch(gameTitle: "Fallout 3", dealTitle: "Fallout 4"))
        #expect(!p.testIsTitleMatch(gameTitle: "Halo", dealTitle: "Halo 3"))
        #expect(!p.testIsTitleMatch(gameTitle: "Final Fantasy VII", dealTitle: "Final Fantasy VIII"))

        // Korrekta matchningar SKALL matcha
        #expect(p.testIsTitleMatch(gameTitle: "Grand Theft Auto V", dealTitle: "Grand Theft Auto V Enhanced"))
        #expect(p.testIsTitleMatch(gameTitle: "Grand Theft Auto 5", dealTitle: "Grand Theft Auto V Enhanced"))
        #expect(p.testIsTitleMatch(gameTitle: "Grand Theft Auto: Vice City", dealTitle: "Grand Theft Auto: Vice City  The Definitive Edition"))
        #expect(p.testIsTitleMatch(gameTitle: "Grand Theft Auto: San Andreas", dealTitle: "Grand Theft Auto: San Andreas  The Definitive Edition"))
        #expect(p.testIsTitleMatch(gameTitle: "The Witcher 3", dealTitle: "The Witcher 3: Wild Hunt  Remastered"))
        #expect(p.testIsTitleMatch(gameTitle: "Fallout 4", dealTitle: "Fallout 4 Game of the Year Edition"))
        #expect(p.testIsTitleMatch(gameTitle: "Resident Evil 4", dealTitle: "Resident Evil 4 (2005)"))
    }
}

