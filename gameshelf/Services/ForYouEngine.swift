//
//  ForYouEngine.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-09-06.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Spelkompassen Filter Types

enum CompassMood: String, CaseIterable, Identifiable, Sendable {
    case all = "Alla känslor"
    case storyRich = "Mysigt & Story"
    case highAction = "Action & Fart"
    case deepTactics = "Djup & Taktik"
    case chillingHorror = "Skräck & Atmosfär"
    case casualFun = "Avkopplande & Indie"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "sparkles"
        case .storyRich: return "book.closed.fill"
        case .highAction: return "flame.fill"
        case .deepTactics: return "brain.head.profile"
        case .chillingHorror: return "moon.stars.fill"
        case .casualFun: return "cup.and.saucer.fill"
        }
    }

    var igdbGenres: [String] {
        switch self {
        case .all:
            return []
        case .storyRich:
            return ["Role-playing (RPG)", "Adventure"]
        case .highAction:
            return ["Shooter", "Action", "Hack and slash/Beat 'em up"]
        case .deepTactics:
            return ["Strategy", "Role-playing (RPG)", "Simulator", "Tactical"]
        case .chillingHorror:
            return ["Horror"]
        case .casualFun:
            return ["Platform", "Puzzle", "Indie"]
        }
    }
}

enum CompassEra: String, CaseIterable, Identifiable, Sendable {
    case all = "Alla epoker"
    case era2020s = "2020 och framåt"
    case era2010s = "2010–2019"
    case era2000s = "2000–2009"
    case era90s = "90-talet & Retro"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "clock"
        case .era2020s: return "sparkles.tv"
        case .era2010s: return "play.desktopcomputer"
        case .era2000s: return "opticaldisc"
        case .era90s: return "gamecontroller"
        }
    }

    var yearRange: (start: Int?, end: Int?) {
        switch self {
        case .all: return (nil, nil)
        case .era2020s: return (2020, 2026)
        case .era2010s: return (2010, 2019)
        case .era2000s: return (2000, 2009)
        case .era90s: return (1985, 1999)
        }
    }
}

enum CompassPlaytime: String, CaseIterable, Identifiable, Sendable {
    case all = "Alla längder"
    case short = "< 10 tim"
    case medium = "10–25 tim"
    case long = "30+ tim"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "hourglass"
        case .short: return "hare.fill"
        case .medium: return "clock.fill"
        case .long: return "tortoise.fill"
        }
    }

    func matches(hours: Int) -> Bool {
        switch self {
        case .all: return true
        case .short: return hours > 0 && hours < 10
        case .medium: return hours >= 10 && hours <= 25
        case .long: return hours >= 30
        }
    }
}

struct CompassPlatformOption: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let icon: String

    static let allPlatforms: [CompassPlatformOption] = [
        CompassPlatformOption(id: 167, name: "PlayStation 5", icon: "playstation.logo"),
        CompassPlatformOption(id: 48, name: "PlayStation 4", icon: "playstation.logo"),
        CompassPlatformOption(id: 9, name: "PlayStation 3", icon: "playstation.logo"),
        CompassPlatformOption(id: 8, name: "PlayStation 2", icon: "playstation.logo"),
        CompassPlatformOption(id: 169, name: "Xbox Series X/S", icon: "xbox.logo"),
        CompassPlatformOption(id: 49, name: "Xbox One", icon: "xbox.logo"),
        CompassPlatformOption(id: 12, name: "Xbox 360", icon: "xbox.logo"),
        CompassPlatformOption(id: 130, name: "Nintendo Switch", icon: "gamecontroller"),
        CompassPlatformOption(id: 37, name: "Nintendo 3DS", icon: "gamecontroller"),
        CompassPlatformOption(id: 21, name: "GameCube", icon: "gamecontroller"),
        CompassPlatformOption(id: 6, name: "PC (Windows)", icon: "desktopcomputer"),
        CompassPlatformOption(id: 14, name: "Mac", icon: "laptopcomputer")
    ]
}

// MARK: - Models

enum ForYouSectionKind: Equatable {
    case spelDNA(focus: String)
    case referenceGame(slot: Int, game: Game)
    case studio(name: String)
    case topRated
    case playingMood(mood: String)
}

struct ForYouCuratedSection: Identifiable {
    let id: String
    var title: String
    var badge: String
    var icon: String
    var accentColor: Color
    var kind: ForYouSectionKind
    var games: [IGDBGame]
}

struct NostalgiaGameItem: Identifiable {
    var id: Int { game.id }
    let game: IGDBGame
    let nostalgiaReason: String
    let eraLabel: String
    let platformLabel: String
}

struct ForYouFingerprint: Sendable {
    let topGenres: [String]
    let favoriteGames: [Game]
    let topDevelopers: [String]
    let userPlatforms: [String]
    let userPlatformIDs: [Int]
    let spelDNA: SpelDNAProfile?
    let ownedIGDBIDs: Set<Int>
    let ownedTitles: Set<String>
}

struct CuratedRecommendation: Identifiable, Sendable {
    var id: Int { game.id }
    let game: IGDBGame
    let matchedReason: String
}

// MARK: - ForYouEngine

@MainActor
final class ForYouEngine: ObservableObject {
    static let shared = ForYouEngine()

    @Published var isLoading = false
    @Published var curatedSections: [ForYouCuratedSection] = []
    @Published var nostalgiaItems: [NostalgiaGameItem] = []
    @Published var compassResults: [IGDBGame] = []
    @Published var isLoadingCompass = false
    @Published var fingerprint: ForYouFingerprint? = nil

    // Cache för För dig (Startsida / LiveDiscoverySection) med 24h giltighetstid
    @Published var homeCuratedRecommendations: [CuratedRecommendation] = []
    @Published var isLoadingHomeRecommendations = false
    private var lastHomeFetched: Date? = nil
    private var lastHomeGameCount: Int = 0

    // Interaktiva valbara alternativ för första sidan
    @Published var selectedReferenceGame1: Game? = nil
    @Published var selectedReferenceGame2: Game? = nil
    @Published var selectedStudio: String? = nil
    @Published var selectedDNAFocus: String = "modern" // "modern", "highest_rated", "classic"
    @Published var availableReferenceGames: [Game] = []
    @Published var availableStudios: [String] = []

    private let fallbackStudios = [
        "Rockstar Games", "FromSoftware", "CD Projekt Red", "Naughty Dog",
        "Bethesda Game Studios", "Capcom", "Nintendo", "Remedy Entertainment",
        "Square Enix", "BioWare", "Insomniac Games", "Sony Interactive Entertainment", "Valve"
    ]

    private init() {}

    // MARK: - 1. Analysera användarens bibliotek & profil
    func buildFingerprint(games: [Game], profile: ProfileStore) -> ForYouFingerprint {
        let owned = games.filter { $0.isOwned }
        let ownedIGDBIDs = Set(owned.compactMap(\.igdbID))
        let ownedTitles = Set(owned.map { $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })

        // Genre-frekvens
        var genreCounts: [String: Int] = [:]
        for g in owned {
            for genre in g.genres where !genre.isEmpty {
                genreCounts[genre, default: 0] += 1
            }
        }
        for favGenre in profile.favoriteGenres where !favGenre.isEmpty {
            genreCounts[favGenre, default: 0] += 5
        }
        let topGenres = genreCounts.sorted { $0.value > $1.value }.map(\.key)

        // Studio/utvecklar-frekvens
        var devCounts: [String: Int] = [:]
        for g in owned {
            let weight = (g.rating ?? 0) >= 8 ? 3 : 1
            for dev in g.developers where !dev.isEmpty {
                let cleanDev = dev.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanDev.lowercased() != "unknown" && cleanDev.count > 2 {
                    devCounts[cleanDev, default: 0] += weight
                }
            }
        }
        let topDevsFromLibrary = devCounts.sorted { $0.value > $1.value }.map(\.key)

        // Kombinera biblioteksstudios med kända kvalitetsstudios
        var combinedStudios: [String] = []
        for d in topDevsFromLibrary {
            if !combinedStudios.contains(d) { combinedStudios.append(d) }
        }
        for f in fallbackStudios {
            if !combinedStudios.contains(f) { combinedStudios.append(f) }
        }
        self.availableStudios = combinedStudios
        if self.selectedStudio == nil {
            self.selectedStudio = topDevsFromLibrary.first ?? fallbackStudios.first
        }

        // Valbara referensspel: Profilfavoriter först, därefter högst rankade i biblioteket
        var candidateGames: [Game] = []
        for favID in profile.favoriteGameIDs {
            let lower = favID.lowercased()
            if let match = owned.first(where: {
                $0.id.uuidString.lowercased() == lower ||
                ($0.igdbID != nil && String($0.igdbID!) == favID)
            }) {
                if !candidateGames.contains(where: { $0.id == match.id }) {
                    candidateGames.append(match)
                }
            }
        }
        let highRated = owned.filter { ($0.rating ?? 0) >= 8 && $0.igdbID != nil }.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        for hr in highRated {
            if !candidateGames.contains(where: { $0.id == hr.id }) {
                candidateGames.append(hr)
            }
        }
        let playingOrCompleted = owned.filter { ($0.status == .playing || $0.status == .completed) && $0.igdbID != nil }
        for pc in playingOrCompleted.prefix(10) {
            if !candidateGames.contains(where: { $0.id == pc.id }) {
                candidateGames.append(pc)
            }
        }
        self.availableReferenceGames = candidateGames

        if self.selectedReferenceGame1 == nil {
            self.selectedReferenceGame1 = candidateGames.first
        }
        if self.selectedReferenceGame2 == nil {
            self.selectedReferenceGame2 = candidateGames.count > 1 ? candidateGames[1] : nil
        }

        // Användarens plattformar
        let platforms = Array(profile.platforms.isEmpty ? PlatformMatcher.currentProfilePlatforms() : profile.platforms)
        var platformIDs: [Int] = []
        for p in platforms {
            let lower = p.lowercased()
            if lower.contains("playstation 5") || lower == "ps5" { platformIDs.append(167) }
            else if lower.contains("playstation 4") || lower == "ps4" { platformIDs.append(48) }
            else if lower.contains("playstation 3") || lower == "ps3" { platformIDs.append(9) }
            else if lower.contains("playstation 2") || lower == "ps2" { platformIDs.append(8) }
            else if lower.contains("xbox series") { platformIDs.append(169) }
            else if lower.contains("xbox one") { platformIDs.append(49) }
            else if lower.contains("xbox 360") { platformIDs.append(12) }
            else if lower.contains("switch") { platformIDs.append(130) }
            else if lower.contains("3ds") { platformIDs.append(37) }
            else if lower.contains("gamecube") { platformIDs.append(21) }
            else if lower.contains("mac") { platformIDs.append(14) }
            else if lower.contains("steam deck") || lower.contains("rog ally") || lower.contains("pc") || lower.contains("windows") { platformIDs.append(6) }
        }

        let spelDNA = SpelDNACalculator.calculate(games: games, playFor: profile.playFor)

        let fp = ForYouFingerprint(
            topGenres: topGenres,
            favoriteGames: candidateGames,
            topDevelopers: topDevsFromLibrary,
            userPlatforms: platforms,
            userPlatformIDs: Array(Set(platformIDs)),
            spelDNA: spelDNA,
            ownedIGDBIDs: ownedIGDBIDs,
            ownedTitles: ownedTitles
        )
        self.fingerprint = fp
        return fp
    }

    // MARK: - 2. Ladda flik 1: Nya favoriter
    func loadPersonalizedRecommendations(games: [Game], profile: ProfileStore, forceReload: Bool = false) async {
        guard curatedSections.isEmpty || forceReload else { return }
        isLoading = true
        let fp = buildFingerprint(games: games, profile: profile)

        var sections: [ForYouCuratedSection] = []
        var seenGameIDs = Set<Int>()

        // Sektion A: Spel-DNA Rekommendation (Smart modern/hög kvalitet)
        if let dna = fp.spelDNA {
            let dnaGames = await fetchArchetypeGames(dna: dna, fp: fp, focus: selectedDNAFocus)
            if !dnaGames.isEmpty {
                for g in dnaGames { seenGameIDs.insert(g.id) }
                sections.append(ForYouCuratedSection(
                    id: "dna_\(dna.id)",
                    title: "För din arketyp: \(dna.title)",
                    badge: "Ditt Spel-DNA",
                    icon: dna.icon,
                    accentColor: dna.accentColor,
                    kind: .spelDNA(focus: selectedDNAFocus),
                    games: dnaGames
                ))
            }
        }

        // Sektion B: Referensspel 1 (T.ex. The Last of Us / Mafia II)
        if let ref1 = selectedReferenceGame1 {
            let similar1 = await fetchSmartSimilarGames(for: ref1, fp: fp, seenIDs: &seenGameIDs)
            if !similar1.isEmpty {
                let shortTitle = ref1.title.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? ref1.title
                sections.append(ForYouCuratedSection(
                    id: "slot1_\(ref1.id.uuidString)",
                    title: "Eftersom du älskade \(shortTitle)",
                    badge: "Liknar din favorit",
                    icon: "heart.fill",
                    accentColor: Color.ds.brandRed,
                    kind: .referenceGame(slot: 1, game: ref1),
                    games: similar1
                ))
            }
        }

        // Sektion C: Referensspel 2 (T.ex. Kingdom Come / RDR2 / Baldur's Gate)
        if let ref2 = selectedReferenceGame2, ref2.id != selectedReferenceGame1?.id {
            let similar2 = await fetchSmartSimilarGames(for: ref2, fp: fp, seenIDs: &seenGameIDs)
            if !similar2.isEmpty {
                let shortTitle = ref2.title.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? ref2.title
                sections.append(ForYouCuratedSection(
                    id: "slot2_\(ref2.id.uuidString)",
                    title: "Eftersom du älskade \(shortTitle)",
                    badge: "Liknar din favorit",
                    icon: "heart.fill",
                    accentColor: Color.ds.brandRed,
                    kind: .referenceGame(slot: 2, game: ref2),
                    games: similar2
                ))
            }
        }

        // Sektion D: Studio i fokus
        let studioName = selectedStudio ?? fp.topDevelopers.first ?? "Rockstar Games"
        let studioGames = await fetchStudioGames(studio: studioName, fp: fp, seenIDs: &seenGameIDs)
        if !studioGames.isEmpty {
            sections.append(ForYouCuratedSection(
                id: "studio_\(studioName)",
                title: "Mästerverk från \(studioName)",
                badge: "Studio i fokus",
                icon: "sparkles",
                accentColor: .orange,
                kind: .studio(name: studioName),
                games: studioGames
            ))
        }

        // Sektion E: Topprankade pärlor i dina favoritgenrer
        let mainGenres = Array(fp.topGenres.prefix(2))
        if !mainGenres.isEmpty {
            if let topRanked = try? await IGDBService.shared.discoverGames(
                startYear: 2012,
                genres: mainGenres,
                minRating: 82,
                sortOption: .popularity,
                limit: 12
            ) {
                let filtered = topRanked.filter {
                    !fp.ownedIGDBIDs.contains($0.id) &&
                    !fp.ownedTitles.contains($0.name.lowercased()) &&
                    !seenGameIDs.contains($0.id)
                }
                if !filtered.isEmpty {
                    sections.append(ForYouCuratedSection(
                        id: "top_rated_genre",
                        title: "Kritiskt hyllade pärlor",
                        badge: "Toppbetyg",
                        icon: "star.fill",
                        accentColor: .yellow,
                        kind: .topRated,
                        games: filtered
                    ))
                }
            }
        }

        // Sektion: Dagens Vibe (om profilen har ett aktivt spelhumör)
        if !profile.playingMood.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let mood = profile.playingMood.trimmingCharacters(in: .whitespacesAndNewlines)
            let moodGames = await fetchMoodGames(mood: mood, fp: fp, seenIDs: &seenGameIDs)
            if !moodGames.isEmpty {
                let cleanTitle = mood.components(separatedBy: " ").dropFirst().joined(separator: " ")
                sections.append(ForYouCuratedSection(
                    id: "mood_\(mood)",
                    title: cleanTitle.isEmpty ? mood : cleanTitle,
                    badge: "Dagens Vibe",
                    icon: moodIcon(for: mood),
                    accentColor: .teal,
                    kind: .playingMood(mood: mood),
                    games: moodGames
                ))
            }
        }

        self.curatedSections = sections
        self.isLoading = false
    }

    // MARK: - 3. Interaktiva uppdateringar av sektioner

    /// Byter referensspel för slot 1 eller 2 och uppdaterar sektionen direkt
    func changeReferenceGame(slot: Int, newGame: Game) async {
        guard let fp = fingerprint else { return }
        if slot == 1 {
            self.selectedReferenceGame1 = newGame
        } else {
            self.selectedReferenceGame2 = newGame
        }

        var seenIDs = Set<Int>()
        for sec in curatedSections {
            if case .referenceGame(let s, _) = sec.kind, s == slot { continue }
            for g in sec.games { seenIDs.insert(g.id) }
        }

        let newGames = await fetchSmartSimilarGames(for: newGame, fp: fp, seenIDs: &seenIDs)
        let shortTitle = newGame.title.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? newGame.title

        withAnimation {
            if let idx = curatedSections.firstIndex(where: {
                if case .referenceGame(let s, _) = $0.kind { return s == slot }
                return false
            }) {
                curatedSections[idx].title = "Eftersom du älskade \(shortTitle)"
                curatedSections[idx].kind = .referenceGame(slot: slot, game: newGame)
                curatedSections[idx].games = newGames
            }
        }
    }

    /// Byter studio i fokus och uppdaterar sektionen direkt
    func changeStudio(newStudio: String) async {
        guard let fp = fingerprint else { return }
        self.selectedStudio = newStudio

        var seenIDs = Set<Int>()
        for sec in curatedSections {
            if case .studio = sec.kind { continue }
            for g in sec.games { seenIDs.insert(g.id) }
        }

        let newGames = await fetchStudioGames(studio: newStudio, fp: fp, seenIDs: &seenIDs)

        withAnimation {
            if let idx = curatedSections.firstIndex(where: {
                if case .studio = $0.kind { return true }
                return false
            }) {
                curatedSections[idx].title = "Mästerverk från \(newStudio)"
                curatedSections[idx].kind = .studio(name: newStudio)
                curatedSections[idx].games = newGames
            }
        }
    }

    /// Byter Spel-DNA fokus och uppdaterar sektionen direkt
    func changeDNAFocus(newFocus: String) async {
        guard let fp = fingerprint, let dna = fp.spelDNA else { return }
        self.selectedDNAFocus = newFocus

        let newGames = await fetchArchetypeGames(dna: dna, fp: fp, focus: newFocus)

        withAnimation {
            if let idx = curatedSections.firstIndex(where: {
                if case .spelDNA = $0.kind { return true }
                return false
            }) {
                curatedSections[idx].kind = .spelDNA(focus: newFocus)
                curatedSections[idx].games = newGames
            }
        }
    }

    // MARK: - 4. Smarta Relevans- & Kvalitetsmotorer

    /// Hämtar liknande spel med kvalitetsspärr + smart genrekontroll + automatisk påfyllnad
    private func fetchSmartSimilarGames(for game: Game, fp: ForYouFingerprint, seenIDs: inout Set<Int>) async -> [IGDBGame] {
        var results: [IGDBGame] = []
        let refGenres = Set(game.genres.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })

        // Steg 1: Officiella IGDB similar_games med betyg >= 70 och genreöverlapp
        if let igdbID = game.igdbID {
            if let similar = try? await IGDBService.shared.fetchSimilarGames(forGameID: igdbID, limit: 14) {
                for g in similar {
                    guard !fp.ownedIGDBIDs.contains(g.id),
                          !fp.ownedTitles.contains(g.name.lowercased()),
                          !seenIDs.contains(g.id) else { continue }

                    // Kasta bort spel med lågt betyg
                    if let r = g.totalRating, r < 70 { continue }

                    // Filtrera bort irrelevanta skräp-/memespel som saknar genreöverlapp (t.ex. Dude Simulator vs Kingdom Come)
                    let simGenres = Set(g.genres?.map { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) } ?? [])
                    if !refGenres.isEmpty && !simGenres.isEmpty && refGenres.isDisjoint(with: simGenres) {
                        continue
                    }

                    results.append(g)
                    seenIDs.insert(g.id)
                }
            }
        }

        // Steg 2: Komplettera med hyllade spel från samma genre så att hyllan alltid blir fylld med 10-14 starka titlar
        if results.count < 10, let mainGenre = game.genres.first {
            if let genrePicks = try? await IGDBService.shared.discoverGames(
                startYear: 2012,
                genres: [mainGenre],
                minRating: 76,
                sortOption: .popularity,
                limit: 16
            ) {
                for g in genrePicks {
                    guard !fp.ownedIGDBIDs.contains(g.id),
                          !fp.ownedTitles.contains(g.name.lowercased()),
                          !seenIDs.contains(g.id) else { continue }
                    results.append(g)
                    seenIDs.insert(g.id)
                    if results.count >= 14 { break }
                }
            }
        }

        return Array(results.prefix(14))
    }

    /// Hämtar spel för användarens arketyp utan att blanda in 90-tals retro eller obskyra moddar
    private func fetchArchetypeGames(dna: SpelDNAProfile, fp: ForYouFingerprint, focus: String) async -> [IGDBGame] {
        let dnaGenres = extractGenresForArchetype(dna.archetypeID, fallback: fp.topGenres)

        let startYear: Int?
        let endYear: Int?
        let sort: DiscoverSortOption
        let minRating: Int

        switch focus {
        case "highest_rated":
            startYear = 2008
            endYear = nil
            sort = .rating
            minRating = 84
        case "classic":
            startYear = 1998
            endYear = 2014
            sort = .popularity
            minRating = 80
        default: // "modern"
            startYear = 2014
            endYear = nil
            sort = .popularity
            minRating = 76
        }

        if let games = try? await IGDBService.shared.discoverGames(
            startYear: startYear,
            endYear: endYear,
            genres: dnaGenres,
            minRating: minRating,
            sortOption: sort,
            limit: 16
        ) {
            return games.filter {
                !fp.ownedIGDBIDs.contains($0.id) &&
                !fp.ownedTitles.contains($0.name.lowercased())
            }
        }
        return []
    }

    /// Hämtar hyllade spel från vald studio
    private func fetchStudioGames(studio: String, fp: ForYouFingerprint, seenIDs: inout Set<Int>) async -> [IGDBGame] {
        if let devGames = try? await IGDBService.shared.discoverGames(
            startYear: 2000,
            developer: studio,
            minRating: 72,
            sortOption: .popularity,
            limit: 12
        ) {
            var items: [IGDBGame] = []
            for g in devGames {
                guard !fp.ownedIGDBIDs.contains(g.id),
                      !fp.ownedTitles.contains(g.name.lowercased()),
                      !seenIDs.contains(g.id) else { continue }
                items.append(g)
                seenIDs.insert(g.id)
            }
            return items
        }
        return []
    }

    /// Hämtar spel som matchar profilens aktuella Spelhumör & Vibe
    private func fetchMoodGames(mood: String, fp: ForYouFingerprint, seenIDs: inout Set<Int>) async -> [IGDBGame] {
        let genres: [String]
        let minRating: Int
        let startYear: Int?

        let lower = mood.lowercased()
        if lower.contains("utforska") {
            genres = ["Adventure", "Role-playing (RPG)"]
            minRating = 75
            startYear = 2015
        } else if lower.contains("mysigt") || lower.contains("avkopplande") {
            genres = ["Puzzle", "Simulator", "Indie", "Adventure"]
            minRating = 74
            startYear = 2016
        } else if lower.contains("boss") || lower.contains("brutal") {
            genres = ["Action", "Hack and slash/Beat 'em up", "Role-playing (RPG)"]
            minRating = 76
            startYear = 2015
        } else if lower.contains("story") || lower.contains("lore") {
            genres = ["Role-playing (RPG)", "Adventure"]
            minRating = 78
            startYear = 2014
        } else if lower.contains("action") || lower.contains("tempo") || lower.contains("snabb") {
            genres = ["Action", "Shooter", "Fighting"]
            minRating = 75
            startYear = 2017
        } else if lower.contains("taktik") || lower.contains("hjärngympa") {
            genres = ["Strategy", "Tactical", "Puzzle"]
            minRating = 75
            startYear = 2015
        } else if lower.contains("nostalgi") || lower.contains("retro") {
            genres = ["Platform", "Arcade", "Adventure"]
            minRating = 75
            startYear = 1995
        } else {
            genres = Array(fp.topGenres.prefix(2))
            minRating = 75
            startYear = 2015
        }

        if let results = try? await IGDBService.shared.discoverGames(
            startYear: startYear,
            platformIDs: fp.userPlatformIDs,
            genres: genres,
            minRating: minRating,
            sortOption: .popularity,
            limit: 16
        ) {
            var items: [IGDBGame] = []
            for g in results {
                guard !fp.ownedIGDBIDs.contains(g.id),
                      !fp.ownedTitles.contains(g.name.lowercased()),
                      !seenIDs.contains(g.id) else { continue }
                items.append(g)
                seenIDs.insert(g.id)
                if items.count >= 12 { break }
            }
            return items
        }
        return []
    }

    private func moodIcon(for mood: String) -> String {
        let lower = mood.lowercased()
        if lower.contains("utforska") { return "safari.fill" }
        if lower.contains("mysigt") { return "cup.and.saucer.fill" }
        if lower.contains("boss") { return "shield.lefthalf.filled" }
        if lower.contains("story") { return "book.closed.fill" }
        if lower.contains("action") || lower.contains("tempo") { return "bolt.fill" }
        if lower.contains("taktik") { return "brain.head.profile" }
        if lower.contains("nostalgi") { return "clock.arrow.circlepath" }
        return "sparkles"
    }

    // MARK: - 4b. Startsida: Kurerade rekommendationer för 'För dig' med 24h cache
    func loadHomeCuratedRecommendations(
        games: [Game],
        profile: ProfileStore,
        forceReload: Bool = false
    ) async {
        let oneDay: TimeInterval = 86400 // 24 timmar
        let libraryCount = games.count

        // Om vi redan har rekommendationer och det gått under 24 timmar samt biblioteksstorleken inte ändrats kraftigt
        if !forceReload,
           !homeCuratedRecommendations.isEmpty,
           let last = lastHomeFetched,
           Date().timeIntervalSince(last) < oneDay,
           abs(libraryCount - lastHomeGameCount) < 2 {
            return
        }

        isLoadingHomeRecommendations = true
        let libraryTitles = Set(games.map { $0.title.lowercased() })
        let libraryIDs = Set(games.compactMap { $0.igdbID })

        // 1. Primär signal: Användarens Favoritspel från profilen
        let favoriteGames: [Game] = profile.favoriteGameIDs.compactMap { favID in
            let lower = favID.lowercased()
            return games.first(where: {
                $0.id.uuidString.lowercased() == lower ||
                ($0.igdbID != nil && String($0.igdbID!) == favID)
            })
        }

        // 2. Aktiva spel som spelas just nu
        let activeGames = games.filter { $0.status == .playing }

        // 3. Högt betygsatta spel (>= 7)
        let rated = games.filter { ($0.rating ?? 0) >= 7 }.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }

        var referenceItems: [(game: Game, badgePrefix: String)] = []
        for fav in favoriteGames.prefix(3) {
            referenceItems.append((fav, "Favorit"))
        }
        for act in activeGames.prefix(2) {
            if !referenceItems.contains(where: { $0.game.id == act.id }) {
                referenceItems.append((act, "Passar"))
            }
        }
        for r in rated.prefix(2) {
            if !referenceItems.contains(where: { $0.game.id == r.id }) {
                referenceItems.append((r, "Toppval"))
            }
        }
        if referenceItems.isEmpty {
            for g in games.prefix(2) {
                referenceItems.append((g, "Liknar"))
            }
        }

        var allCurated: [CuratedRecommendation] = []
        var seenIDs = Set<Int>()

        // Kurerar rekommendationer för varje referensspel
        for ref in referenceItems {
            let refGame = ref.game
            var refResults: [IGDBGame] = []
            if let igdbID = refGame.igdbID {
                refResults = (try? await IGDBService.shared.fetchSimilarGames(forGameID: igdbID, limit: 8)) ?? []
            }
            if refResults.isEmpty {
                let genres = refGame.genres.filter { !$0.isEmpty }
                if !genres.isEmpty {
                    refResults = (try? await IGDBService.shared.fetchRecommendations(forGenres: genres, limit: 8)) ?? []
                }
            }

            // Filtrera bort biblioteksspel och redan tillagda
            refResults.removeAll { game in
                libraryIDs.contains(game.id) || libraryTitles.contains(game.name.lowercased()) || seenIDs.contains(game.id)
            }

            let shortTitle = refGame.title.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? refGame.title
            let badgeText = "\(ref.badgePrefix): \(shortTitle)"

            for g in refResults {
                seenIDs.insert(g.id)
                allCurated.append(CuratedRecommendation(game: g, matchedReason: badgeText))
            }
        }

        // Fallback om för få hittades - prioritera profilens favoritgenrer först!
        if allCurated.count < 6 {
            let profileGenres = Array(profile.favoriteGenres)
            var counts: [String: Int] = [:]
            for game in games {
                for g in game.genres where !g.isEmpty {
                    counts[g, default: 0] += 1
                }
            }
            let userTopGenres = counts.sorted { $0.value > $1.value }.map(\.key)
            let fallbackGenres = !profileGenres.isEmpty ? profileGenres : (userTopGenres.isEmpty ? ["Action", "Role-playing (RPG)", "Adventure"] : userTopGenres)
            if let fallback = try? await IGDBService.shared.fetchRecommendations(forGenres: fallbackGenres, limit: 10) {
                for g in fallback where !libraryIDs.contains(g.id) && !seenIDs.contains(g.id) {
                    seenIDs.insert(g.id)
                    allCurated.append(CuratedRecommendation(game: g, matchedReason: "Toppval i din smak"))
                }
            }
        }

        self.homeCuratedRecommendations = Array(allCurated.prefix(16))
        self.lastHomeFetched = Date()
        self.lastHomeGameCount = libraryCount
        self.isLoadingHomeRecommendations = false
    }

    // MARK: - 5. Flik 2: Spelminnen & Nostalgi Radar
    func loadNostalgiaRadar(
        games: [Game],
        profile: ProfileStore,
        era: CompassEra = .all,
        platformID: Int? = nil,
        forceReload: Bool = false
    ) async {
        if !nostalgiaItems.isEmpty && !forceReload && era == .all && platformID == nil {
            return
        }

        let fp = fingerprint ?? buildFingerprint(games: games, profile: profile)
        var pIDs: [Int] = []
        if let p = platformID {
            pIDs = [p]
        }

        let startYear: Int?
        let endYear: Int?

        switch era {
        case .all:
            startYear = 1995
            endYear = 2018
        case .era90s:
            startYear = 1990
            endYear = 1999
        case .era2000s:
            startYear = 2000
            endYear = 2009
        case .era2010s:
            startYear = 2010
            endYear = 2019
        case .era2020s:
            startYear = 2020
            endYear = 2024
        }

        do {
            let fetched = try await IGDBService.shared.discoverGames(
                startYear: startYear,
                endYear: endYear,
                platformIDs: pIDs,
                genres: Array(fp.topGenres.prefix(4)),
                minRating: 78,
                sortOption: .popularity,
                limit: 36
            )

            let missingGames = fetched.filter { game in
                !fp.ownedIGDBIDs.contains(game.id) &&
                !fp.ownedTitles.contains(game.name.lowercased())
            }

            var items: [NostalgiaGameItem] = []
            for g in missingGames {
                let y = g.releaseYear ?? 2005
                let eraLabel: String
                let reason: String

                if y <= 1999 {
                    eraLabel = "90-talet"
                    reason = "Klassiker från 90-talet"
                } else if y <= 2009 {
                    eraLabel = "2000-talet"
                    reason = "Gyllene 2000-talspärla"
                } else if y <= 2015 {
                    eraLabel = "PS3/360-eran"
                    reason = "Hyllad milstolpe"
                } else {
                    eraLabel = "Modern klassiker"
                    reason = "Hyllad storfavorit"
                }

                let plat = g.platforms?.first?.name ?? "Retro"
                items.append(NostalgiaGameItem(
                    game: g,
                    nostalgiaReason: reason,
                    eraLabel: eraLabel,
                    platformLabel: plat
                ))
            }

            self.nostalgiaItems = items
        } catch {
            print("⚠️ ForYouEngine loadNostalgiaRadar error: \(error)")
        }
    }

    // MARK: - 6. Spelkompassen: Kör filtrering
    func applyCompass(
        games: [Game],
        profile: ProfileStore,
        mood: CompassMood,
        playtime: CompassPlaytime,
        era: CompassEra,
        platformID: Int?
    ) async {
        isLoadingCompass = true
        let fp = fingerprint ?? buildFingerprint(games: games, profile: profile)

        let startYear = era.yearRange.start
        let endYear = era.yearRange.end
        let genres = mood.igdbGenres
        var platformIDs: [Int] = []
        if let p = platformID {
            platformIDs = [p]
        }

        do {
            let results = try await IGDBService.shared.discoverGames(
                startYear: startYear,
                endYear: endYear,
                platformIDs: platformIDs,
                genres: genres,
                minRating: 72,
                sortOption: .popularity,
                limit: 30
            )

            let filtered = results.filter {
                !fp.ownedIGDBIDs.contains($0.id) &&
                !fp.ownedTitles.contains($0.name.lowercased())
            }

            self.compassResults = filtered
            self.isLoadingCompass = false
        } catch {
            print("⚠️ ForYouEngine applyCompass error: \(error)")
            self.isLoadingCompass = false
        }
    }

    /// Snabbfilter för upptäckt (Dolda pärlor, Korta spel, 90+ Mästerverk)
    func applyQuickPreset(
        games: [Game],
        profile: ProfileStore,
        preset: String
    ) async {
        isLoadingCompass = true
        let fp = fingerprint ?? buildFingerprint(games: games, profile: profile)
        let userPlatforms = fp.userPlatformIDs
 
        do {
            let results: [IGDBGame]
            switch preset {
            case "hidden_gems":
                // Betyg 80+, men lägre count / indie / mindre kända
                results = try await IGDBService.shared.discoverGames(
                    startYear: 2014,
                    platformIDs: userPlatforms,
                    genres: ["Indie", "Adventure", "Role-playing (RPG)", "Puzzle"],
                    minRating: 80,
                    sortOption: .rating,
                    limit: 30
                )
            case "short_games":
                // Korta upplevelser (äventyr/plattform/pussel)
                results = try await IGDBService.shared.discoverGames(
                    startYear: 2016,
                    platformIDs: userPlatforms,
                    genres: ["Platform", "Puzzle", "Indie", "Adventure"],
                    minRating: 78,
                    sortOption: .popularity,
                    limit: 30
                )
            case "masterpieces":
                // 90+ på IGDB
                results = try await IGDBService.shared.discoverGames(
                    startYear: 2005,
                    platformIDs: userPlatforms,
                    genres: [],
                    minRating: 90,
                    sortOption: .rating,
                    limit: 30
                )
            default:
                results = []
            }

            let filtered = results.filter {
                !fp.ownedIGDBIDs.contains($0.id) &&
                !fp.ownedTitles.contains($0.name.lowercased())
            }

            self.compassResults = filtered
            self.isLoadingCompass = false
        } catch {
            print("⚠️ ForYouEngine applyQuickPreset error: \(error)")
            self.isLoadingCompass = false
        }
    }

    // MARK: - Helpers
    private func extractGenresForArchetype(_ id: SpelDNAArchetypeID, fallback: [String]) -> [String] {
        switch id {
        case .storyDrivenExplorer, .atmosphereHunter:
            return ["Adventure", "Role-playing (RPG)"]
        case .rpgCompletionist, .completionistPrime:
            return ["Role-playing (RPG)", "Adventure"]
        case .indieConnoisseur, .pixelPurist, .zenCultivator:
            return ["Indie", "Platform", "Puzzle"]
        case .cozyAdventurer:
            return ["Adventure", "Puzzle", "Simulator"]
        case .tacticalOperator, .grandStrategist, .squadStrategist:
            return ["Strategy", "Shooter", "Tactical"]
        case .hardcoreChallenger, .soulsSurvivor:
            return ["Action", "Role-playing (RPG)", "Hack and slash/Beat 'em up"]
        case .retroArchivist:
            return ["Platform", "Adventure", "Arcade"]
        case .openWorldWanderer:
            return ["Adventure", "Role-playing (RPG)", "Action"]
        default:
            return Array(fallback.prefix(2))
        }
    }

    func removeNostalgiaItem(id: Int) {
        withAnimation {
            nostalgiaItems.removeAll { $0.id == id }
        }
    }
}
