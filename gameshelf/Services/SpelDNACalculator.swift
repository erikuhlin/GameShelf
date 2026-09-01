//
//  SpelDNACalculator.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-31.
//

import Foundation

enum SpelDNACalculator {
    /// Beräknar användarens Spel-DNA baserat på biblioteksdata och preferenser (10 arketyper + fallback)
    static func calculate(
        games: [Game],
        playFor: Set<String> = []
    ) -> SpelDNAProfile? {
        let ownedGames = games.filter { $0.isOwned }
        let wishlistGames = games.filter { !$0.isOwned }

        // Minimikrav: minst 5 ägda spel i biblioteket
        guard ownedGames.count >= 5 else {
            return nil
        }

        let totalOwned = ownedGames.count
        let completedCount = ownedGames.filter { $0.status == .completed }.count
        let completionRate = Double(completedCount) / Double(totalOwned)

        // 1. Räkna genreandelar
        var genreCounts: [String: Int] = [:]
        for game in ownedGames {
            for genre in game.genres {
                let trimmed = genre.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                genreCounts[trimmed, default: 0] += 1
            }
        }

        let sortedGenres = genreCounts.sorted { $0.value > $1.value }
        let topGenre = sortedGenres.first
        let topGenreName = topGenre?.key ?? "Okänd"
        let topGenreCount = topGenre?.value ?? 0
        let topGenreShare = Double(topGenreCount) / Double(totalOwned)
        let activeGenreCount = genreCounts.count

        // Gruppräkningar
        let rpgCount = genreCounts.filter {
            let k = $0.key.lowercased()
            return k.contains("rpg") || k.contains("rollspel") || k.contains("role-playing")
        }.values.reduce(0, +)
        let rpgShare = Double(rpgCount) / Double(totalOwned)

        let horrorCount = genreCounts.filter {
            let k = $0.key.lowercased()
            return k.contains("skräck") || k.contains("horror") || k.contains("survival horror")
        }.values.reduce(0, +)
        let horrorShare = Double(horrorCount) / Double(totalOwned)

        let shooterCount = genreCounts.filter {
            let k = $0.key.lowercased()
            return k.contains("shooter") || k.contains("fps") || k.contains("skjutspel") || k.contains("krig") || k.contains("tactical")
        }.values.reduce(0, +)
        let shooterShare = Double(shooterCount) / Double(totalOwned)

        let indieCount = genreCounts.filter {
            let k = $0.key.lowercased()
            return k.contains("indie") || k.contains("puzzle") || k.contains("pussel")
        }.values.reduce(0, +)
        let indieShare = Double(indieCount) / Double(totalOwned)

        let strategyCount = genreCounts.filter {
            let k = $0.key.lowercased()
            return k.contains("strategi") || k.contains("strategy") || k.contains("taktik") || k.contains("tactical")
        }.values.reduce(0, +)
        let strategyShare = Double(strategyCount) / Double(totalOwned)

        let cozyCount = genreCounts.filter {
            let k = $0.key.lowercased()
            return k.contains("simulator") || k.contains("pussel") || k.contains("puzzle") || k.contains("äventyr") || k.contains("adventure")
        }.values.reduce(0, +)
        let cozyShare = Double(cozyCount) / Double(totalOwned)

        let retroGamesCount = ownedGames.filter { game in
            (game.releaseYear > 0 && game.releaseYear <= 2012) ||
            game.platforms.contains { plat in
                let lower = plat.lowercased()
                return lower.contains("retro") || lower.contains("nes") || lower.contains("snes") || lower.contains("n64") ||
                       lower.contains("ps1") || lower.contains("ps2") || lower.contains("game boy") || lower.contains("sega")
            }
        }.count
        let retroShare = Double(retroGamesCount) / Double(totalOwned)

        let multiplayerCount = ownedGames.filter { game in
            let text = (game.title + " " + game.genres.joined(separator: " ")).lowercased()
            return text.contains("multiplayer") || text.contains("co-op") || text.contains("warzone") ||
                   text.contains("overwatch") || text.contains("apex") || text.contains("fifa") || text.contains("fc 2") ||
                   text.contains("counter-strike") || text.contains("valorant") || text.contains("helldivers") ||
                   text.contains("destiny") || text.contains("rocket league") || text.contains("battlefield")
        }.count
        let multiplayerShare = Double(multiplayerCount) / Double(totalOwned)

        let storyOrHorrorShare = Double(rpgCount + horrorCount) / Double(totalOwned)
        let prefersCompetition = playFor.contains("Tävling") || playFor.contains("Action")
        let prefersCozy = playFor.contains("Avkoppling") || playFor.contains("Kreativitet")
        let prefersChallenge = playFor.contains("Utmaning")

        // 2. Regeluppslag mot arketyp-tabell (första träff vinner)

        // 1. Story-driven Explorer
        let isHorrorOrRPGTop = topGenreName.localizedCaseInsensitiveContains("skräck") ||
                               topGenreName.localizedCaseInsensitiveContains("horror") ||
                               topGenreName.localizedCaseInsensitiveContains("rpg") ||
                               topGenreName.localizedCaseInsensitiveContains("rollspel")

        if (isHorrorOrRPGTop && topGenreShare >= 0.45 && completionRate >= 0.45) ||
           (storyOrHorrorShare >= 0.50 && completionRate >= 0.50) {
            let stat1 = horrorCount >= rpgCount ? "\(min(99, Int(horrorShare * 100)))% Skräck" : "\(min(99, Int(rpgShare * 100)))% RPG"
            let stat2 = "\(completedCount)/\(totalOwned) klarade"
            return SpelDNAProfile(
                archetypeID: .storyDrivenExplorer,
                title: "Story-driven Explorer",
                description: "Du väljer atmosfär och berättelse framför tempo — och du brukar faktiskt spela klart det du börjar.",
                icon: "🌒",
                accentHex: "#ff4b4b",
                supportingStats: [stat1, stat2]
            )
        }

        // 2. RPG Completionist
        if rpgShare >= 0.40 && completionRate >= 0.65 {
            let stat1 = "\(min(99, Int(rpgShare * 100)))% RPG"
            let stat2 = "\(completedCount)/\(totalOwned) klarade"
            return SpelDNAProfile(
                archetypeID: .rpgCompletionist,
                title: "RPG Completionist",
                description: "Sidouppdrag, loot och 100%-listor — om det finns en till timme att lägga i en värld tar du den.",
                icon: "🗺️",
                accentHex: "#6e7ae0",
                supportingStats: [stat1, stat2]
            )
        }

        // 3. Indie Connoisseur
        if indieShare >= 0.35 || topGenreName.localizedCaseInsensitiveContains("indie") {
            let stat1 = "\(min(99, max(35, Int(indieShare * 100))))% Indie & Pussel"
            let stat2 = "Konstnärlig smak"
            return SpelDNAProfile(
                archetypeID: .indieConnoisseur,
                title: "Indie Connoisseur",
                description: "Du söker unika visioner och originellt hantverk — de starkaste spelupplevelserna hittar du bortom storspelen.",
                icon: "🎨",
                accentHex: "#a855f7",
                supportingStats: [stat1, stat2]
            )
        }

        // 4. Hardcore Challenger
        if prefersChallenge && (completionRate >= 0.50 || topGenreShare >= 0.35) {
            let stat1 = "Hög utmaning"
            let stat2 = "\(completedCount)/\(totalOwned) klarade"
            return SpelDNAProfile(
                archetypeID: .hardcoreChallenger,
                title: "Hardcore Challenger",
                description: "Du backar inte för brutala bossar eller tuffa moment — segern smakar bäst när den krävt svett och tålamod.",
                icon: "⚡",
                accentHex: "#dc2626",
                supportingStats: [stat1, stat2]
            )
        }

        // 5. Grand Strategist
        if strategyShare >= 0.30 || topGenreName.localizedCaseInsensitiveContains("strategi") || topGenreName.localizedCaseInsensitiveContains("strategy") {
            let stat1 = "\(min(99, max(30, Int(strategyShare * 100))))% Strategi"
            let stat2 = "Taktiskt sinne"
            return SpelDNAProfile(
                archetypeID: .grandStrategist,
                title: "Grand Strategist",
                description: "Långsiktig planering, taktisk överblick och total kontroll — du vinner med hjärnan snarare än snabba reflexer.",
                icon: "👑",
                accentHex: "#f59e0b",
                supportingStats: [stat1, stat2]
            )
        }

        // 6. Retro Archivist
        if retroShare >= 0.30 {
            let stat1 = "\(retroGamesCount) klassiker"
            let stat2 = "Retrosamlare"
            return SpelDNAProfile(
                archetypeID: .retroArchivist,
                title: "Retro Archivist",
                description: "Spelhistoriens gyllene eror lever vidare i din samling — tidlösa mästerverk slår alltid tillfälliga trender.",
                icon: "🕹️",
                accentHex: "#f97316",
                supportingStats: [stat1, stat2]
            )
        }

        // 7. Tactical Operator
        let isShooterTop = topGenreName.localizedCaseInsensitiveContains("shooter") ||
                           topGenreName.localizedCaseInsensitiveContains("fps") ||
                           topGenreName.localizedCaseInsensitiveContains("skjutspel") ||
                           topGenreName.localizedCaseInsensitiveContains("krig")

        if (isShooterTop && topGenreShare >= 0.38 && completionRate < 0.38) ||
           (shooterShare >= 0.38 && completionRate < 0.38) {
            let stat1 = "\(min(99, max(38, Int(shooterShare * 100))))% Shooters"
            let stat2 = "\(completedCount)/\(totalOwned) klarade"
            return SpelDNAProfile(
                archetypeID: .tacticalOperator,
                title: "Tactical Operator",
                description: "Du lägger timmarna där det finns en match att vinna, inte en historia att avsluta.",
                icon: "🎯",
                accentHex: "#c7c23a",
                supportingStats: [stat1, stat2]
            )
        }

        // 8. Cozy Adventurer
        if prefersCozy || (cozyShare >= 0.35 && completionRate >= 0.40) {
            let stat1 = "Cozy & Avkoppling"
            let stat2 = "\(activeGenreCount) genrer aktiva"
            return SpelDNAProfile(
                archetypeID: .cozyAdventurer,
                title: "Cozy Adventurer",
                description: "Avkoppling, charm och atmosfär är ditt mantra — spel ska vara en varm tillflyktsort fri från stress och hets.",
                icon: "☕",
                accentHex: "#ec4899",
                supportingStats: [stat1, stat2]
            )
        }

        // 9. Squad Strategist
        if multiplayerShare >= 0.32 && prefersCompetition {
            let stat1 = "\(min(99, Int(multiplayerShare * 100)))% Multiplayer"
            let stat2 = "Lagspelare"
            return SpelDNAProfile(
                archetypeID: .squadStrategist,
                title: "Squad Strategist",
                description: "Spelet är bäst när ni är fler — samarbete och tävling slår solo-berättelser varje gång.",
                icon: "🤝",
                accentHex: "#3cc8aa",
                supportingStats: [stat1, stat2]
            )
        }

        // 10. Casual Collector
        if topGenreShare <= 0.38 && (wishlistGames.count >= 8 || totalOwned >= 10) {
            let stat1 = "\(wishlistGames.count) på önskelistan"
            let stat2 = "\(activeGenreCount) genrer aktiva"
            return SpelDNAProfile(
                archetypeID: .casualCollector,
                title: "Casual Collector",
                description: "Du samlar bredare än du hinner spela — biblioteket är lika mycket en önskelista som en att-göra-lista.",
                icon: "📦",
                accentHex: "#e6a03c",
                supportingStats: [stat1, stat2]
            )
        }

        // 11. Fallback: Genre-nomad
        let stat1 = "\(activeGenreCount) genrer i biblioteket"
        let stat2 = "\(totalOwned) ägda spel"
        return SpelDNAProfile(
            archetypeID: .genreNomad,
            title: "Genre-nomad",
            description: "Du rör dig fritt mellan världar och genrer utan att fastna i ett fack — nyfikenheten styr nästa val.",
            icon: "🎲",
            accentHex: "#8b8b8f",
            supportingStats: [stat1, stat2]
        )
    }
}
