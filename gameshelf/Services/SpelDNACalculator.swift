//
//  SpelDNACalculator.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-31.
//

import Foundation

enum SpelDNACalculator {
    private struct ArchetypeCandidate {
        let archetypeID: SpelDNAArchetypeID
        let title: String
        let description: String
        let icon: String
        let accentHex: String
        let supportingStats: [String]
        let score: Double
    }

    /// Beräknar användarens Spel-DNA baserat på biblioteksdata, betyg, favoriter och preferenser
    static func calculate(
        games: [Game],
        playFor: Set<String> = [],
        favoriteGenres: Set<String> = [],
        favoriteGameIDs: [String] = [],
        playstyle: Set<String> = []
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

        let favSet = Set(favoriteGameIDs.map { $0.lowercased() })

        // 1. Viktat genomslag per spel
        var totalEffectiveWeight = 0.0
        var gameWeights: [UUID: Double] = [:]

        for game in ownedGames {
            var w = 1.0
            let isFav = favSet.contains(game.id.uuidString.lowercased()) || (game.igdbID.map { favSet.contains(String($0).lowercased()) } ?? false)
            if let r = game.rating {
                if r >= 9 {
                    w += 1.5
                } else if r == 8 {
                    w += 0.8
                }
            }
            if isFav {
                w += 1.2
            }
            if game.status == .completed {
                w += 0.4
            }
            gameWeights[game.id] = w
            totalEffectiveWeight += w
        }

        if totalEffectiveWeight <= 0 { totalEffectiveWeight = Double(totalOwned) }

        // 2. Räkna viktade genrer
        var genreWeights: [String: Double] = [:]
        for game in ownedGames {
            let w = gameWeights[game.id] ?? 1.0
            for genre in game.genres {
                let trimmed = genre.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                genreWeights[trimmed, default: 0.0] += w
            }
        }

        let sortedGenres = genreWeights.sorted { $0.value > $1.value }
        let topGenre = sortedGenres.first
        let topGenreName = topGenre?.key ?? "Okänd"
        let topGenreWeight = topGenre?.value ?? 0.0
        let topGenreShare = topGenreWeight / totalEffectiveWeight
        let activeGenreCount = genreWeights.count

        func weightForKeywords(_ keywords: [String]) -> Double {
            var sum = 0.0
            for (genre, w) in genreWeights {
                let lower = genre.lowercased()
                if keywords.contains(where: { lower.contains($0) }) {
                    sum += w
                }
            }
            return sum
        }

        let rpgWeight = weightForKeywords(["rpg", "rollspel", "role-playing", "jrpg"])
        let rpgShare = rpgWeight / totalEffectiveWeight

        let horrorWeight = weightForKeywords(["skräck", "horror", "survival horror"])
        let horrorShare = horrorWeight / totalEffectiveWeight

        let shooterWeight = weightForKeywords(["shooter", "fps", "skjutspel", "krig", "tactical"])
        let shooterShare = shooterWeight / totalEffectiveWeight

        let indieWeight = weightForKeywords(["indie", "puzzle", "pussel"])
        let indieShare = indieWeight / totalEffectiveWeight

        let strategyWeight = weightForKeywords(["strategi", "strategy", "taktik", "tactical"])
        let strategyShare = strategyWeight / totalEffectiveWeight

        let cozyWeight = weightForKeywords(["simulator", "pussel", "puzzle", "äventyr", "adventure", "cozy", "life sim"])
        let cozyShare = cozyWeight / totalEffectiveWeight

        var soulsWeight = 0.0
        var soulsCount = 0
        for game in ownedGames {
            let text = (game.title + " " + game.genres.joined(separator: " ")).lowercased()
            let isSouls = text.contains("souls") || text.contains("soulslike") || text.contains("elden ring") ||
                          text.contains("bloodborne") || text.contains("sekiro") || text.contains("nioh") ||
                          text.contains("lies of p") || text.contains("hollow knight") || text.contains("roguelike")
            if isSouls {
                soulsCount += 1
                soulsWeight += (gameWeights[game.id] ?? 1.0)
            }
        }
        let soulsShare = soulsWeight / totalEffectiveWeight

        var openWorldWeight = 0.0
        var openWorldCount = 0
        for game in ownedGames {
            let text = (game.title + " " + game.genres.joined(separator: " ")).lowercased()
            let isOW = text.contains("open world") || text.contains("öppen värld") || text.contains("sandbox") ||
                       text.contains("sandlåda") || text.contains("witcher") || text.contains("zelda") ||
                       text.contains("skyrim") || text.contains("red dead") || text.contains("cyberpunk")
            if isOW {
                openWorldCount += 1
                openWorldWeight += (gameWeights[game.id] ?? 1.0)
            }
        }
        let openWorldShare = openWorldWeight / totalEffectiveWeight

        var retroWeight = 0.0
        var retroGamesCount = 0
        for game in ownedGames {
            let isOldYear = game.releaseYear > 0 && game.releaseYear <= 2012
            let hasRetroPlat = game.platforms.contains { plat in
                let lower = plat.lowercased()
                return lower.contains("retro") || lower.contains("nes") || lower.contains("snes") || lower.contains("n64") ||
                       lower.contains("ps1") || lower.contains("ps2") || lower.contains("game boy") || lower.contains("sega")
            }
            if isOldYear || hasRetroPlat {
                retroGamesCount += 1
                retroWeight += (gameWeights[game.id] ?? 1.0)
            }
        }
        let retroShare = retroWeight / totalEffectiveWeight

        var multiplayerWeight = 0.0
        var multiplayerCount = 0
        for game in ownedGames {
            let text = (game.title + " " + game.genres.joined(separator: " ")).lowercased()
            let isMP = text.contains("multiplayer") || text.contains("co-op") || text.contains("samarbete") ||
                       text.contains("warzone") || text.contains("overwatch") || text.contains("apex") ||
                       text.contains("fifa") || text.contains("fc 2") || text.contains("counter-strike") ||
                       text.contains("valorant") || text.contains("helldivers") || text.contains("destiny") ||
                       text.contains("rocket league") || text.contains("battlefield")
            if isMP {
                multiplayerCount += 1
                multiplayerWeight += (gameWeights[game.id] ?? 1.0)
            }
        }
        let multiplayerShare = multiplayerWeight / totalEffectiveWeight

        // Preferenser
        let prefersCompetition = playFor.contains("Tävling") || playFor.contains("Action") || playstyle.contains("PvP / Multiplayer")
        let prefersCozy = playFor.contains("Avkoppling") || playFor.contains("Avkoppling & Lugn") || playFor.contains("Kreativitet") || playFor.contains("Kreativitet & Byggande") || playstyle.contains("Casual & Cozy")
        let prefersChallenge = playFor.contains("Utmaning") || playFor.contains("Utmaning & Bemästring") || playFor.contains("Adrenalin & Puls") || playFor.contains("Mästra svåra bossar") || playstyle.contains("Hardcore / Utmanare")
        let prefersLore = playFor.contains("Djup Lore & Världsbygge") || playFor.contains("Story") || playFor.contains("Story & Karaktärer") || playFor.contains("Immersion & Stämning") || playstyle.contains("Story-fokuserad")
        let prefersCoop = playFor.contains("Samarbete & Gemenskap (Co-op)") || playFor.contains("Samarbete") || playFor.contains("Samarbete & Gemenskap") || playstyle.contains("Co-op / Samarbete")
        let prefersCompletionism = playFor.contains("100% Completionism (Trophies)") || playFor.contains("100% Completionism") || playFor.contains("Trophy Hunter") || playFor.contains("Completionist (100%)") || playstyle.contains("Completionist (100%)") || playstyle.contains("Trophy / Achievement Hunter")
        let prefersExploration = playFor.contains("Utforskning") || playstyle.contains("Utforskare & Samlare")

        let favGenresLower = favoriteGenres.map { $0.lowercased() }
        let hasFavGenre: (String) -> Bool = { kw in favGenresLower.contains(where: { $0.contains(kw) }) }

        // 3. Poängsättning för alla kandidater
        var candidates: [ArchetypeCandidate] = [
            // 1. Souls Survivor
            ArchetypeCandidate(
                archetypeID: .soulsSurvivor,
                title: "Souls Survivor",
                description: "Brutala bossar, millimeterprecision och hårt förvärvade triumfer — du backar aldrig för en verklig utmaning.",
                icon: "⚔️",
                accentHex: "#e11d48",
                supportingStats: ["\(soulsCount) souls/utmaningar", "Oböjligt tålamod"],
                score: (soulsShare * 110.0) + (soulsCount >= 2 ? 25.0 : 0.0) + (prefersChallenge ? 20.0 : 0.0) + (hasFavGenre("soulslike") ? 25.0 : 0.0)
            ),

            // 2. Story-driven Explorer
            ArchetypeCandidate(
                archetypeID: .storyDrivenExplorer,
                title: "Story-driven Explorer",
                description: "Du väljer atmosfär och berättelse framför tempo — och du brukar faktiskt spela klart det du börjar.",
                icon: "🌒",
                accentHex: "#ff4b4b",
                supportingStats: [
                    horrorWeight >= rpgWeight ? "\(min(99, Int(horrorShare * 100)))% Skräck" : "\(min(99, Int(rpgShare * 100)))% RPG",
                    "\(completedCount)/\(totalOwned) klarade"
                ],
                score: ((rpgShare + horrorShare) * 65.0) + (prefersLore ? 25.0 : 0.0) + (completionRate >= 0.35 ? 15.0 : 0.0) + (hasFavGenre("berättelsedrivet") ? 20.0 : 0.0)
            ),

            // 3. RPG Completionist
            ArchetypeCandidate(
                archetypeID: .rpgCompletionist,
                title: "RPG Completionist",
                description: "Sidouppdrag, loot och 100%-listor — om det finns en till timme att lägga i en värld tar du den.",
                icon: "🗺️",
                accentHex: "#6e7ae0",
                supportingStats: ["\(min(99, Int(rpgShare * 100)))% RPG", "\(completedCount)/\(totalOwned) klarade"],
                score: (rpgShare * 85.0) + (completionRate * 25.0) + (hasFavGenre("rpg") || hasFavGenre("jrpg") ? 20.0 : 0.0)
            ),

            // 4. Open-World Wanderer
            ArchetypeCandidate(
                archetypeID: .openWorldWanderer,
                title: "Öppen Värld-Nomad",
                description: "Vidsträckta vyer och total frihet — för dig är resan mot horisonten alltid viktigare än den raka vägen.",
                icon: "🧭",
                accentHex: "#0ea5e9",
                supportingStats: ["\(openWorldCount) öppna världar", "Horisontsökare"],
                score: (openWorldShare * 95.0) + (openWorldCount >= 2 ? 15.0 : 0.0) + (prefersExploration ? 25.0 : 0.0) + (hasFavGenre("öppen värld") ? 20.0 : 0.0)
            ),

            // 5. Indie Connoisseur
            ArchetypeCandidate(
                archetypeID: .indieConnoisseur,
                title: "Indie Connoisseur",
                description: "Du söker unika visioner och originellt hantverk — de starkaste spelupplevelserna hittar du bortom storspelen.",
                icon: "🎨",
                accentHex: "#a855f7",
                supportingStats: ["\(min(99, max(30, Int(indieShare * 100))))% Indie & Pussel", "Konstnärlig smak"],
                score: (indieShare * 100.0) + (topGenreName.localizedCaseInsensitiveContains("indie") ? 20.0 : 0.0) + (hasFavGenre("indie") ? 25.0 : 0.0)
            ),

            // 6. Hardcore Challenger
            ArchetypeCandidate(
                archetypeID: .hardcoreChallenger,
                title: "Hardcore Challenger",
                description: "Du backar inte för brutala bossar eller tuffa moment — segern smakar bäst när den krävt svett och tålamod.",
                icon: "⚡",
                accentHex: "#dc2626",
                supportingStats: ["Hög utmaning", "\(completedCount)/\(totalOwned) klarade"],
                score: (prefersChallenge ? 35.0 : 0.0) + (completionRate * 30.0) + (soulsShare * 30.0)
            ),

            // 7. Atmosphere Hunter
            ArchetypeCandidate(
                archetypeID: .atmosphereHunter,
                title: "Atmosfärsdykare",
                description: "Ljuddesign, tryckande stämning och mörka mysterier — du vill sugas in i världar som berör på djupet.",
                icon: "🕯️",
                accentHex: "#a21caf",
                supportingStats: ["\(min(99, Int(horrorShare * 100)))% Skräck & Mörker", "Djup atmosfär"],
                score: (horrorShare * 110.0) + (prefersLore ? 20.0 : 0.0) + (hasFavGenre("skräck") ? 25.0 : 0.0)
            ),

            // 8. Pixel Purist
            ArchetypeCandidate(
                archetypeID: .pixelPurist,
                title: "Pixel Purist",
                description: "Tidlös estetik, pixelperfektion och ren spelglädje — kärleken till klassiker och retrokonst består.",
                icon: "👾",
                accentHex: "#06b6d4",
                supportingStats: ["\(retroGamesCount) retro & pixel", "Tidlös estetik"],
                score: (retroShare * 65.0) + (indieShare * 35.0) + (retroGamesCount >= 3 ? 15.0 : 0.0)
            ),

            // 9. Grand Strategist
            ArchetypeCandidate(
                archetypeID: .grandStrategist,
                title: "Grand Strategist",
                description: "Långsiktig planering, taktisk överblick och total kontroll — du vinner med hjärnan snarare än snabba reflexer.",
                icon: "👑",
                accentHex: "#f59e0b",
                supportingStats: ["\(min(99, max(30, Int(strategyShare * 100))))% Strategi", "Taktiskt sinne"],
                score: (strategyShare * 110.0) + (hasFavGenre("strategi") ? 25.0 : 0.0)
            ),

            // 10. Retro Archivist
            ArchetypeCandidate(
                archetypeID: .retroArchivist,
                title: "Retro Archivist",
                description: "Spelhistoriens gyllene eror lever vidare i din samling — tidlösa mästerverk slår alltid tillfälliga trender.",
                icon: "🕹️",
                accentHex: "#f97316",
                supportingStats: ["\(retroGamesCount) klassiker", "Retrosamlare"],
                score: (retroShare * 105.0) + (hasFavGenre("retro") ? 25.0 : 0.0)
            ),

            // 11. Zen Cultivator
            ArchetypeCandidate(
                archetypeID: .zenCultivator,
                title: "Zen-odlare",
                description: "Spel som en varm tillflyktsort — rofyllt byggande, charm och avkopplande stunder utan stress.",
                icon: "🌱",
                accentHex: "#10b981",
                supportingStats: ["Zen & Harmoni", "Lugnt tempo"],
                score: (cozyShare * 80.0) + (prefersCozy ? 30.0 : 0.0) + (hasFavGenre("cozy") ? 20.0 : 0.0)
            ),

            // 12. Cozy Adventurer
            ArchetypeCandidate(
                archetypeID: .cozyAdventurer,
                title: "Cozy Adventurer",
                description: "Avkoppling, charm och atmosfär är ditt mantra — spel ska vara en varm tillflyktsort fri från stress och hets.",
                icon: "☕",
                accentHex: "#ec4899",
                supportingStats: ["Cozy & Avkoppling", "\(activeGenreCount) genrer aktiva"],
                score: (cozyShare * 75.0) + (prefersCozy ? 25.0 : 0.0) + (completionRate >= 0.35 ? 15.0 : 0.0)
            ),

            // 13. Tactical Operator
            ArchetypeCandidate(
                archetypeID: .tacticalOperator,
                title: "Tactical Operator",
                description: "Du lägger timmarna där det finns en match att vinna, inte en historia att avsluta.",
                icon: "🎯",
                accentHex: "#c7c23a",
                supportingStats: ["\(min(99, max(30, Int(shooterShare * 100))))% Shooters", "Taktiskt fokus"],
                score: (shooterShare * 100.0) + (prefersCompetition ? 20.0 : 0.0) + (hasFavGenre("fps") ? 25.0 : 0.0)
            ),

            // 14. Squad Strategist
            ArchetypeCandidate(
                archetypeID: .squadStrategist,
                title: "Squad Strategist",
                description: "Spelet är bäst när ni är fler — samarbete och tävling slår solo-berättelser varje gång.",
                icon: "🤝",
                accentHex: "#3cc8aa",
                supportingStats: ["\(min(99, Int(multiplayerShare * 100)))% Multiplayer", "Lagspelare"],
                score: (multiplayerShare * 100.0) + (prefersCoop ? 30.0 : 0.0) + (prefersCompetition ? 15.0 : 0.0)
            ),

            // 15. Completionist Prime
            ArchetypeCandidate(
                archetypeID: .completionistPrime,
                title: "Completionist Prime",
                description: "100% är det enda acceptabla. Du lämnar ingen trofé, sidouppdrag eller hemlighet oavslutad.",
                icon: "🏅",
                accentHex: "#eab308",
                supportingStats: ["\(min(99, Int(completionRate * 100)))% genomfört", "Troféjägare"],
                score: (completionRate >= 0.65 ? 50.0 : 0.0) + (prefersCompletionism ? 40.0 : 0.0)
            ),

            // 16. Backlog Titan
            ArchetypeCandidate(
                archetypeID: .backlogTitan,
                title: "Backlog Titan",
                description: "Ett storslaget bibliotek som växer ständigt — du samlar med passion och erövrar med tålamod.",
                icon: "📚",
                accentHex: "#d97706",
                supportingStats: ["\(totalOwned) i biblioteket", "Massiv backlog"],
                score: (totalOwned >= 25 && completionRate < 0.20 && topGenreShare < 0.30) ? 40.0 : 5.0
            ),

            // 17. Casual Collector
            ArchetypeCandidate(
                archetypeID: .casualCollector,
                title: "Casual Collector",
                description: "Du samlar bredare än du hinner spela — biblioteket är lika mycket en önskelista som en att-göra-lista.",
                icon: "📦",
                accentHex: "#e6a03c",
                supportingStats: ["\(wishlistGames.count) på önskelistan", "\(activeGenreCount) genrer aktiva"],
                score: (wishlistGames.count >= 12 && completionRate < 0.25 && topGenreShare < 0.25) ? 35.0 : 5.0
            ),

            // 18. Fallback: Genre-nomad
            ArchetypeCandidate(
                archetypeID: .genreNomad,
                title: "Genre-nomad",
                description: "Du rör dig fritt mellan världar och genrer utan att fastna i ett fack — nyfikenheten styr nästa val.",
                icon: "🎲",
                accentHex: "#8b8b8f",
                supportingStats: ["\(activeGenreCount) genrer i samlingen", "\(totalOwned) ägda spel"],
                score: (activeGenreCount >= 5 && topGenreShare <= 0.25) ? 45.0 : 15.0
            )
        ]

        candidates.sort { $0.score > $1.score }
        let best = candidates[0]
        let primaryScore = max(1.0, best.score)

        var primaryArchetype = SpelDNAProfile(
            archetypeID: best.archetypeID,
            title: best.title,
            description: best.description,
            icon: best.icon,
            accentHex: best.accentHex,
            supportingStats: best.supportingStats
        )

        let secondaryArchetypes = candidates
            .dropFirst()
            .filter { $0.score >= 35.0 && $0.archetypeID != best.archetypeID }
            .prefix(2)
            .map { cand in
                SpelDNASubArchetype(
                    archetypeID: cand.archetypeID,
                    title: cand.title,
                    icon: cand.icon,
                    accentHex: cand.accentHex,
                    matchPercentage: min(95, Int(round((cand.score / primaryScore) * 100.0)))
                )
            }

        primaryArchetype.secondaryArchetypes = Array(secondaryArchetypes)

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
        if let sec = primary.secondaryArchetypes.first {
            tile1 = SpelDNATile(
                id: "tile_hybrid",
                category: "SEKUNDÄRT DRAG",
                title: sec.title,
                subtitle: "\(sec.matchPercentage)% matchning",
                icon: sec.icon,
                accentHex: sec.accentHex,
                detail: "Starkt komplementärt drag i din unika spelstil (\(sec.matchPercentage)% match)"
            )
        } else if primary.archetypeID != .indieConnoisseur && indieShare >= 0.20 {
            tile1 = SpelDNATile(
                id: "tile_hybrid",
                category: "SEKUNDÄRT DRAG",
                title: "Indie Gourmet",
                subtitle: "Konstnärlig ådra",
                icon: "🎨",
                accentHex: "#a855f7",
                detail: "\(Int(indieShare * 100))% av hyllan utgörs av unika indiepärlor"
            )
        } else if primary.archetypeID != .rpgCompletionist && rpgShare >= 0.20 {
            tile1 = SpelDNATile(
                id: "tile_hybrid",
                category: "SEKUNDÄRT DRAG",
                title: "Rollspelsdykare",
                subtitle: "Djupa världar",
                icon: "🗺️",
                accentHex: "#6e7ae0",
                detail: "Stark dragning till karaktärsutveckling och rik lore"
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
        if completionRate >= 0.55 {
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
        if topGenreShare >= 0.45 {
            tile4 = SpelDNATile(
                id: "tile_spectrum",
                category: "SMAKSPEKTRUM",
                title: "Genrefokuserad Specialist",
                subtitle: "Tydlig profil",
                icon: "🎯",
                accentHex: "#ef4444",
                detail: "\(topGenreName) utgör en stark kärna i din personliga samling"
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
        } else if retroShare >= 0.20 {
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
