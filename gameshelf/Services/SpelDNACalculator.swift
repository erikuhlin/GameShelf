//
//  SpelDNACalculator.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-31.
//

import Foundation

enum SpelDNACalculator {
    /// Beräknar användarens Spel-DNA baserat på biblioteksdata och preferenser (18 arketyper + 4 dynamiska DNA-rutor)
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

        // Gruppräkningar med utökad matchning
        let rpgCount = genreCounts.filter {
            let k = $0.key.lowercased()
            return k.contains("rpg") || k.contains("rollspel") || k.contains("role-playing") || k.contains("jrpg")
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
            return k.contains("simulator") || k.contains("pussel") || k.contains("puzzle") || k.contains("äventyr") || k.contains("adventure") || k.contains("cozy")
        }.values.reduce(0, +)
        let cozyShare = Double(cozyCount) / Double(totalOwned)

        let soulsCount = ownedGames.filter { game in
            let text = (game.title + " " + game.genres.joined(separator: " ")).lowercased()
            return text.contains("souls") || text.contains("soulslike") || text.contains("elden ring") ||
                   text.contains("bloodborne") || text.contains("sekiro") || text.contains("nioh") ||
                   text.contains("lies of p") || text.contains("hollow knight") || text.contains("roguelike")
        }.count
        let soulsShare = Double(soulsCount) / Double(totalOwned)

        let openWorldCount = ownedGames.filter { game in
            let text = (game.title + " " + game.genres.joined(separator: " ")).lowercased()
            return text.contains("open world") || text.contains("öppen värld") || text.contains("sandbox") ||
                   text.contains("sandlåda") || text.contains("witcher") || text.contains("zelda") ||
                   text.contains("skyrim") || text.contains("red dead") || text.contains("cyberpunk")
        }.count
        let openWorldShare = Double(openWorldCount) / Double(totalOwned)

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
            return text.contains("multiplayer") || text.contains("co-op") || text.contains("samarbete") ||
                   text.contains("warzone") || text.contains("overwatch") || text.contains("apex") ||
                   text.contains("fifa") || text.contains("fc 2") || text.contains("counter-strike") ||
                   text.contains("valorant") || text.contains("helldivers") || text.contains("destiny") ||
                   text.contains("rocket league") || text.contains("battlefield")
        }.count
        let multiplayerShare = Double(multiplayerCount) / Double(totalOwned)

        let storyOrHorrorShare = Double(rpgCount + horrorCount) / Double(totalOwned)
        let prefersCompetition = playFor.contains("Tävling") || playFor.contains("Action")
        let prefersCozy = playFor.contains("Avkoppling") || playFor.contains("Kreativitet")
        let prefersChallenge = playFor.contains("Utmaning") || playFor.contains("Adrenalin & Puls")
        let prefersLore = playFor.contains("Djup Lore & Världsbygge") || playFor.contains("Story")
        let prefersCoop = playFor.contains("Samarbete & Gemenskap (Co-op)") || playFor.contains("Samarbete")
        let prefersCompletionism = playFor.contains("100% Completionism (Trophies)")

        // 2. Regeluppslag mot Huvudarketyp
        var primaryArchetype: SpelDNAProfile

        // 1. Souls Survivor (Hög utmaning & souls-titlar)
        if soulsCount >= 2 && (prefersChallenge || completionRate >= 0.40) {
            let stat1 = "\(soulsCount) souls/utmaningar"
            let stat2 = "Oböjligt tålamod"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .soulsSurvivor,
                title: "Souls Survivor",
                description: "Brutala bossar, millimeterprecision och hårt förvärvade triumfer — du backar aldrig för en verklig utmaning.",
                icon: "⚔️",
                accentHex: "#e11d48",
                supportingStats: [stat1, stat2]
            )
        }
        // 2. Story-driven Explorer
        else if (isHorrorOrRPGTop(topGenreName: topGenreName) && topGenreShare >= 0.45 && completionRate >= 0.45) ||
           (storyOrHorrorShare >= 0.50 && completionRate >= 0.50) {
            let stat1 = horrorCount >= rpgCount ? "\(min(99, Int(horrorShare * 100)))% Skräck" : "\(min(99, Int(rpgShare * 100)))% RPG"
            let stat2 = "\(completedCount)/\(totalOwned) klarade"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .storyDrivenExplorer,
                title: "Story-driven Explorer",
                description: "Du väljer atmosfär och berättelse framför tempo — och du brukar faktiskt spela klart det du börjar.",
                icon: "🌒",
                accentHex: "#ff4b4b",
                supportingStats: [stat1, stat2]
            )
        }
        // 3. Completionist Prime (extremt hög completion rate)
        else if (completionRate >= 0.75 && totalOwned >= 7) || (prefersCompletionism && completionRate >= 0.65) {
            let stat1 = "\(min(99, Int(completionRate * 100)))% genomfört"
            let stat2 = "Troféjägare"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .completionistPrime,
                title: "Completionist Prime",
                description: "100% är det enda acceptabla. Du lämnar ingen trofé, sidouppdrag eller hemlighet oavslutad.",
                icon: "🏅",
                accentHex: "#eab308",
                supportingStats: [stat1, stat2]
            )
        }
        // 4. Open-World Wanderer
        else if openWorldShare >= 0.35 || (openWorldCount >= 2 && (playFor.contains("Utforskning") || rpgShare >= 0.30)) {
            let stat1 = "\(openWorldCount) öppna världar"
            let stat2 = "Horisontsökare"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .openWorldWanderer,
                title: "Öppen Värld-Nomad",
                description: "Vidsträckta vyer och total frihet — för dig är resan mot horisonten alltid viktigare än den raka vägen.",
                icon: "🧭",
                accentHex: "#0ea5e9",
                supportingStats: [stat1, stat2]
            )
        }
        // 5. RPG Completionist
        else if rpgShare >= 0.40 && completionRate >= 0.60 {
            let stat1 = "\(min(99, Int(rpgShare * 100)))% RPG"
            let stat2 = "\(completedCount)/\(totalOwned) klarade"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .rpgCompletionist,
                title: "RPG Completionist",
                description: "Sidouppdrag, loot och 100%-listor — om det finns en till timme att lägga i en värld tar du den.",
                icon: "🗺️",
                accentHex: "#6e7ae0",
                supportingStats: [stat1, stat2]
            )
        }
        // 6. Pixel Purist
        else if (retroShare >= 0.30 && indieShare >= 0.20) || (retroShare >= 0.40) {
            let stat1 = "\(retroGamesCount) retro & pixel"
            let stat2 = "Tidlös estetik"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .pixelPurist,
                title: "Pixel Purist",
                description: "Tidlös estetik, pixelperfektion och ren spelglädje — kärleken till klassiker och retrokonst består.",
                icon: "👾",
                accentHex: "#06b6d4",
                supportingStats: [stat1, stat2]
            )
        }
        // 7. Atmosphere Hunter
        else if horrorShare >= 0.30 || (prefersLore && horrorShare >= 0.20) {
            let stat1 = "\(min(99, Int(horrorShare * 100)))% Skräck & Mörker"
            let stat2 = "Djup atmosfär"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .atmosphereHunter,
                title: "Atmosfärsdykare",
                description: "Ljuddesign, tryckande stämning och mörka mysterier — du vill sugas in i världar som berör på djupet.",
                icon: "🕯️",
                accentHex: "#a21caf",
                supportingStats: [stat1, stat2]
            )
        }
        // 8. Indie Connoisseur
        else if indieShare >= 0.35 || topGenreName.localizedCaseInsensitiveContains("indie") {
            let stat1 = "\(min(99, max(35, Int(indieShare * 100))))% Indie & Pussel"
            let stat2 = "Konstnärlig smak"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .indieConnoisseur,
                title: "Indie Connoisseur",
                description: "Du söker unika visioner och originellt hantverk — de starkaste spelupplevelserna hittar du bortom storspelen.",
                icon: "🎨",
                accentHex: "#a855f7",
                supportingStats: [stat1, stat2]
            )
        }
        // 9. Hardcore Challenger
        else if prefersChallenge && (completionRate >= 0.45 || topGenreShare >= 0.35) {
            let stat1 = "Hög utmaning"
            let stat2 = "\(completedCount)/\(totalOwned) klarade"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .hardcoreChallenger,
                title: "Hardcore Challenger",
                description: "Du backar inte för brutala bossar eller tuffa moment — segern smakar bäst när den krävt svett och tålamod.",
                icon: "⚡",
                accentHex: "#dc2626",
                supportingStats: [stat1, stat2]
            )
        }
        // 10. Grand Strategist
        else if strategyShare >= 0.30 || topGenreName.localizedCaseInsensitiveContains("strategi") || topGenreName.localizedCaseInsensitiveContains("strategy") {
            let stat1 = "\(min(99, max(30, Int(strategyShare * 100))))% Strategi"
            let stat2 = "Taktiskt sinne"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .grandStrategist,
                title: "Grand Strategist",
                description: "Långsiktig planering, taktisk överblick och total kontroll — du vinner med hjärnan snarare än snabba reflexer.",
                icon: "👑",
                accentHex: "#f59e0b",
                supportingStats: [stat1, stat2]
            )
        }
        // 11. Retro Archivist
        else if retroShare >= 0.30 {
            let stat1 = "\(retroGamesCount) klassiker"
            let stat2 = "Retrosamlare"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .retroArchivist,
                title: "Retro Archivist",
                description: "Spelhistoriens gyllene eror lever vidare i din samling — tidlösa mästerverk slår alltid tillfälliga trender.",
                icon: "🕹️",
                accentHex: "#f97316",
                supportingStats: [stat1, stat2]
            )
        }
        // 12. Tactical Operator
        else if (isShooterTop(topGenreName: topGenreName) && topGenreShare >= 0.35 && completionRate < 0.40) ||
           (shooterShare >= 0.35 && completionRate < 0.40) {
            let stat1 = "\(min(99, max(35, Int(shooterShare * 100))))% Shooters"
            let stat2 = "\(completedCount)/\(totalOwned) klarade"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .tacticalOperator,
                title: "Tactical Operator",
                description: "Du lägger timmarna där det finns en match att vinna, inte en historia att avsluta.",
                icon: "🎯",
                accentHex: "#c7c23a",
                supportingStats: [stat1, stat2]
            )
        }
        // 13. Zen Cultivator
        else if prefersCozy && (cozyShare >= 0.30 || indieShare >= 0.25) {
            let stat1 = "Zen & Harmoni"
            let stat2 = "Lugnt tempo"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .zenCultivator,
                title: "Zen-odlare",
                description: "Spel som en varm tillflyktsort — rofyllt byggande, charm och avkopplande stunder utan stress.",
                icon: "🌱",
                accentHex: "#10b981",
                supportingStats: [stat1, stat2]
            )
        }
        // 14. Cozy Adventurer
        else if prefersCozy || (cozyShare >= 0.35 && completionRate >= 0.40) {
            let stat1 = "Cozy & Avkoppling"
            let stat2 = "\(activeGenreCount) genrer aktiva"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .cozyAdventurer,
                title: "Cozy Adventurer",
                description: "Avkoppling, charm och atmosfär är ditt mantra — spel ska vara en varm tillflyktsort fri från stress och hets.",
                icon: "☕",
                accentHex: "#ec4899",
                supportingStats: [stat1, stat2]
            )
        }
        // 15. Squad Strategist
        else if multiplayerShare >= 0.28 && (prefersCompetition || prefersCoop) {
            let stat1 = "\(min(99, Int(multiplayerShare * 100)))% Multiplayer"
            let stat2 = "Lagspelare"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .squadStrategist,
                title: "Squad Strategist",
                description: "Spelet är bäst när ni är fler — samarbete och tävling slår solo-berättelser varje gång.",
                icon: "🤝",
                accentHex: "#3cc8aa",
                supportingStats: [stat1, stat2]
            )
        }
        // 16. Backlog Titan
        else if totalOwned >= 25 && completionRate < 0.30 {
            let stat1 = "\(totalOwned) i biblioteket"
            let stat2 = "Massiv backlog"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .backlogTitan,
                title: "Backlog Titan",
                description: "Ett storslaget bibliotek som växer ständigt — du samlar med passion och erövrar med tålamod.",
                icon: "📚",
                accentHex: "#d97706",
                supportingStats: [stat1, stat2]
            )
        }
        // 17. Casual Collector
        else if topGenreShare <= 0.38 && (wishlistGames.count >= 8 || totalOwned >= 10) {
            let stat1 = "\(wishlistGames.count) på önskelistan"
            let stat2 = "\(activeGenreCount) genrer aktiva"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .casualCollector,
                title: "Casual Collector",
                description: "Du samlar bredare än du hinner spela — biblioteket är lika mycket en önskelista som en att-göra-lista.",
                icon: "📦",
                accentHex: "#e6a03c",
                supportingStats: [stat1, stat2]
            )
        }
        // 18. Fallback: Genre-nomad
        else {
            let stat1 = "\(activeGenreCount) genrer i biblioteket"
            let stat2 = "\(totalOwned) ägda spel"
            primaryArchetype = SpelDNAProfile(
                archetypeID: .genreNomad,
                title: "Genre-nomad",
                description: "Du rör dig fritt mellan världar och genrer utan att fastna i ett fack — nyfikenheten styr nästa val.",
                icon: "🎲",
                accentHex: "#8b8b8f",
                supportingStats: [stat1, stat2]
            )
        }

        // 3. Beräkna de 4 dynamiska DNA-rutorna
        let tiles = calculateTiles(
            primary: primaryArchetype,
            ownedGames: ownedGames,
            wishlistGames: wishlistGames,
            totalOwned: totalOwned,
            completedCount: completedCount,
            completionRate: completionRate,
            activeGenreCount: activeGenreCount,
            topGenreName: topGenreName,
            topGenreShare: topGenreShare,
            rpgShare: rpgShare,
            horrorShare: horrorShare,
            indieShare: indieShare,
            strategyShare: strategyShare,
            retroShare: retroShare,
            retroGamesCount: retroGamesCount,
            multiplayerShare: multiplayerShare,
            playFor: playFor,
            prefersChallenge: prefersChallenge,
            prefersCozy: prefersCozy,
            prefersLore: prefersLore
        )

        primaryArchetype.tiles = tiles
        return primaryArchetype
    }

    private static func isHorrorOrRPGTop(topGenreName: String) -> Bool {
        topGenreName.localizedCaseInsensitiveContains("skräck") ||
        topGenreName.localizedCaseInsensitiveContains("horror") ||
        topGenreName.localizedCaseInsensitiveContains("rpg") ||
        topGenreName.localizedCaseInsensitiveContains("rollspel")
    }

    private static func isShooterTop(topGenreName: String) -> Bool {
        topGenreName.localizedCaseInsensitiveContains("shooter") ||
        topGenreName.localizedCaseInsensitiveContains("fps") ||
        topGenreName.localizedCaseInsensitiveContains("skjutspel") ||
        topGenreName.localizedCaseInsensitiveContains("krig")
    }

    // MARK: - Beräkning av 4 personliga DNA-rutor
    private static func calculateTiles(
        primary: SpelDNAProfile,
        ownedGames: [Game],
        wishlistGames: [Game],
        totalOwned: Int,
        completedCount: Int,
        completionRate: Double,
        activeGenreCount: Int,
        topGenreName: String,
        topGenreShare: Double,
        rpgShare: Double,
        horrorShare: Double,
        indieShare: Double,
        strategyShare: Double,
        retroShare: Double,
        retroGamesCount: Int,
        multiplayerShare: Double,
        playFor: Set<String>,
        prefersChallenge: Bool,
        prefersCozy: Bool,
        prefersLore: Bool
    ) -> [SpelDNATile] {
        var tiles: [SpelDNATile] = []

        // RUTA 1: Sekundärt DNA (Hybrid-drag)
        let tile1: SpelDNATile
        if primary.archetypeID != .indieConnoisseur && indieShare >= 0.22 {
            tile1 = SpelDNATile(
                id: "tile_hybrid",
                category: "SEKUNDÄRT DRAG",
                title: "Indie Gourmet",
                subtitle: "Konstnärlig ådra",
                icon: "🎨",
                accentHex: "#a855f7",
                detail: "\(Int(indieShare * 100))% av hyllan utgörs av unika indiepärlor"
            )
        } else if primary.archetypeID != .rpgCompletionist && rpgShare >= 0.22 {
            tile1 = SpelDNATile(
                id: "tile_hybrid",
                category: "SEKUNDÄRT DRAG",
                title: "Rollspelsdykare",
                subtitle: "Djupa världar",
                icon: "🗺️",
                accentHex: "#6e7ae0",
                detail: "Stark dragning till karaktärsutveckling och rik lore"
            )
        } else if primary.archetypeID != .retroArchivist && primary.archetypeID != .pixelPurist && retroShare >= 0.18 {
            tile1 = SpelDNATile(
                id: "tile_hybrid",
                category: "SEKUNDÄRT DRAG",
                title: "Retro-nostalgiker",
                subtitle: "Tidlösa klassiker",
                icon: "🕹️",
                accentHex: "#f97316",
                detail: "\(retroGamesCount) äldre klassiker bevaras i ditt bibliotek"
            )
        } else if primary.archetypeID != .squadStrategist && multiplayerShare >= 0.18 {
            tile1 = SpelDNATile(
                id: "tile_hybrid",
                category: "SEKUNDÄRT DRAG",
                title: "Co-op Kamrat",
                subtitle: "Gemensam glädje",
                icon: "🤝",
                accentHex: "#3cc8aa",
                detail: "Spelar gärna sida vid sida med vänner"
            )
        } else if primary.archetypeID != .hardcoreChallenger && primary.archetypeID != .soulsSurvivor && prefersChallenge {
            tile1 = SpelDNATile(
                id: "tile_hybrid",
                category: "SEKUNDÄRT DRAG",
                title: "Utmaningssökare",
                subtitle: "Gillar motstånd",
                icon: "⚡",
                accentHex: "#dc2626",
                detail: "Trivs när spelet kräver fokus och skärpa"
            )
        } else if primary.archetypeID != .cozyAdventurer && primary.archetypeID != .zenCultivator && prefersCozy {
            tile1 = SpelDNATile(
                id: "tile_hybrid",
                category: "SEKUNDÄRT DRAG",
                title: "Avkopplingsnjutare",
                subtitle: "Stressfri zon",
                icon: "☕",
                accentHex: "#ec4899",
                detail: "Värdesätter harmoniska och varma spelstunder"
            )
        } else {
            tile1 = SpelDNATile(
                id: "tile_hybrid",
                category: "SEKUNDÄRT DRAG",
                title: "Berättelsedykare",
                subtitle: "Story & Världsbygge",
                icon: "📖",
                accentHex: "#38bdf8",
                detail: "Drags till fängslande manus och atmosfär"
            )
        }
        tiles.append(tile1)

        // RUTA 2: Tempo & Pacing
        let estimatedList = ownedGames.compactMap { $0.estimatedHours }.filter { $0 > 0 }
        let avgHours = estimatedList.isEmpty ? 0 : Double(estimatedList.reduce(0, +)) / Double(estimatedList.count)
        let tile2: SpelDNATile
        if avgHours >= 30.0 || (rpgShare >= 0.35 && avgHours >= 20.0) {
            tile2 = SpelDNATile(
                id: "tile_pacing",
                category: "TEMPO & PACING",
                title: "Episk Maratonspelare",
                subtitle: "30h+ per äventyr",
                icon: "⏳",
                accentHex: "#f59e0b",
                detail: "Investerar helhjärtat i djupa, expansiva världar"
            )
        } else if avgHours > 0 && avgHours <= 14.0 {
            tile2 = SpelDNATile(
                id: "tile_pacing",
                category: "TEMPO & PACING",
                title: "Bite-sized Gourmet",
                subtitle: "Fokuserade pärlor",
                icon: "⚡",
                accentHex: "#06b6d4",
                detail: "Föredrar intensiva upplevelser som respekterar din tid"
            )
        } else {
            tile2 = SpelDNATile(
                id: "tile_pacing",
                category: "TEMPO & PACING",
                title: "Balanserad Äventyrare",
                subtitle: "Flexibelt tempo",
                icon: "⏱️",
                accentHex: "#10b981",
                detail: "Växlar ledigt mellan snabba sessionsspel och längre kampanjer"
            )
        }
        tiles.append(tile2)

        // RUTA 3: Fullbordar-profil
        let tile3: SpelDNATile
        if completionRate >= 0.58 {
            tile3 = SpelDNATile(
                id: "tile_completion",
                category: "FULLBORDARE",
                title: "100% Fullbordare",
                subtitle: "\(Int(completionRate * 100))% genomfört",
                icon: "🏆",
                accentHex: "#eab308",
                detail: "\(completedCount) av \(totalOwned) spel har spelats hela vägen in i mål"
            )
        } else if wishlistGames.count >= ownedGames.count || (totalOwned >= 18 && completionRate < 0.25) {
            tile3 = SpelDNATile(
                id: "tile_completion",
                category: "FULLBORDARE",
                title: "Backlog-Erövrare",
                subtitle: "\(totalOwned) spel i hyllan",
                icon: "🏔️",
                accentHex: "#f97316",
                detail: "Bygger ett skafferi av äventyr och tar sig an spelen med tiden"
            )
        } else if completionRate < 0.35 {
            tile3 = SpelDNATile(
                id: "tile_completion",
                category: "FULLBORDARE",
                title: "Nyfiken Upptäckare",
                subtitle: "Utforskar brett",
                icon: "🔍",
                accentHex: "#8b5cf6",
                detail: "Testar gärna nya mekaniker utan krav på att se eftertexterna"
            )
        } else {
            tile3 = SpelDNATile(
                id: "tile_completion",
                category: "FULLBORDARE",
                title: "Målmedveten Spelare",
                subtitle: "Jämn framfart",
                icon: "🎯",
                accentHex: "#3b82f6",
                detail: "God balans mellan att utforska nytt och avsluta påbörjat"
            )
        }
        tiles.append(tile3)

        // RUTA 4: Smakspektrum
        let tile4: SpelDNATile
        if topGenreShare >= 0.48 {
            tile4 = SpelDNATile(
                id: "tile_spectrum",
                category: "SMAKSPEKTRUM",
                title: "Genrefokuserad Specialist",
                subtitle: "Tydlig profil",
                icon: "🎯",
                accentHex: "#ef4444",
                detail: "\(topGenreName) utgör \(Int(topGenreShare * 100))% av hela din samling"
            )
        } else if activeGenreCount >= 5 && topGenreShare <= 0.35 {
            tile4 = SpelDNATile(
                id: "tile_spectrum",
                category: "SMAKSPEKTRUM",
                title: "Eklektisk Allätare",
                subtitle: "\(activeGenreCount) aktiva genrer",
                icon: "🌈",
                accentHex: "#ec4899",
                detail: "Rör dig obehindrat mellan helt olika spelstilar och koncept"
            )
        } else if retroShare >= 0.25 {
            tile4 = SpelDNATile(
                id: "tile_spectrum",
                category: "SMAKSPEKTRUM",
                title: "Klassiker-kännare",
                subtitle: "\(retroGamesCount) retrotitlar",
                icon: "🕹️",
                accentHex: "#f59e0b",
                detail: "En fin känsla för spelhistoriens mest inflytelserika epoker"
            )
        } else {
            tile4 = SpelDNATile(
                id: "tile_spectrum",
                category: "SMAKSPEKTRUM",
                title: "Modern Allroundare",
                subtitle: "Tidsenlig smak",
                icon: "✨",
                accentHex: "#6366f1",
                detail: "Öppen för både nutida storspel och nyskapande format"
            )
        }
        tiles.append(tile4)

        return tiles
    }
}
