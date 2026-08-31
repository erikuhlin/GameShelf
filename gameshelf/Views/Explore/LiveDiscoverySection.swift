//
//  LiveDiscoverySection.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

struct VisualGenreItem: Identifiable, Equatable {
    let id: String
    let name: String
    let queryName: String
}

enum DiscoveryDisplayMode {
    case all
    case forYouOnly
    case upcomingOnly
    case genreOnly
}

struct CuratedRecommendation: Identifiable {
    var id: Int { game.id }
    let game: IGDBGame
    let matchedReason: String
}

struct LiveDiscoverySection: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var profile: ProfileStore

    var refreshTrigger: UUID = UUID()
    var mode: DiscoveryDisplayMode = .all

    @State private var curatedRecommendations: [CuratedRecommendation] = []
    @State private var popularGames: [IGDBGame] = []
    @State private var upcomingGames: [IGDBGame] = []

    // Genre State
    @State private var selectedGenreGames: [IGDBGame] = []
    @State private var selectedGenre: VisualGenreItem = VisualGenreItem(id: "Action", name: "Action", queryName: "Action")
    @State private var genreSort: String = "popularity" // "popularity", "rating", "newest"
    @State private var genreLimit: Int = 12

    @State private var isLoadingRecommended = false
    @State private var isLoadingPopular = false
    @State private var isLoadingUpcoming = false
    @State private var isLoadingGenre = false
    @State private var isLoadingMoreGenre = false

    private let genres: [VisualGenreItem] = [
        VisualGenreItem(id: "Action", name: "Action", queryName: "Action"),
        VisualGenreItem(id: "RPG", name: "RPG", queryName: "Role-playing (RPG)"),
        VisualGenreItem(id: "Adventure", name: "Äventyr", queryName: "Adventure"),
        VisualGenreItem(id: "Shooter", name: "Skjutspel", queryName: "Shooter"),
        VisualGenreItem(id: "Horror", name: "Skräck", queryName: "Horror"),
        VisualGenreItem(id: "Indie", name: "Indie", queryName: "Indie"),
        VisualGenreItem(id: "Strategy", name: "Strategi", queryName: "Strategy"),
        VisualGenreItem(id: "Platform", name: "Plattform", queryName: "Platform"),
        VisualGenreItem(id: "Racing", name: "Racing", queryName: "Racing"),
        VisualGenreItem(id: "Fighting", name: "Fighting", queryName: "Fighting"),
        VisualGenreItem(id: "Simulator", name: "Simulator", queryName: "Simulator"),
        VisualGenreItem(id: "Puzzle", name: "Pussel", queryName: "Puzzle"),
        VisualGenreItem(id: "Sport", name: "Sport", queryName: "Sport")
    ]

    private var sortedGenres: [VisualGenreItem] {
        genres.sorted { g1, g2 in
            let fav1 = isGenreFavorite(g1)
            let fav2 = isGenreFavorite(g2)
            if fav1 && !fav2 { return true }
            if !fav1 && fav2 { return false }
            return false
        }
    }

    private func isGenreFavorite(_ item: VisualGenreItem) -> Bool {
        profile.favoriteGenres.contains(where: {
            $0.localizedCaseInsensitiveContains(item.name) ||
            item.name.localizedCaseInsensitiveContains($0) ||
            $0.localizedCaseInsensitiveContains(item.id)
        })
    }

    private var userTopGenres: [String] {
        var counts: [String: Int] = [:]
        for game in store.games {
            for g in game.genres where !g.isEmpty {
                counts[g, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            switch mode {
            case .all:
                forYouSubSection
                popularSubSection
                upcomingSubSection
                genreSubSection
            case .forYouOnly:
                forYouSubSection
            case .upcomingOnly:
                upcomingSubSection
            case .genreOnly:
                genreSubSection
            }
        }
        .task(id: refreshTrigger) {
            await loadAllDiscovery()
            loadGenreGames(selectedGenre, limit: 12)
        }
    }

    @ViewBuilder
    private var forYouSubSection: some View {
        if !curatedRecommendations.isEmpty || isLoadingRecommended {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.ds.brandRed)
                        Text("För dig")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                    }

                    let activeGames = store.games.filter { $0.status == .playing }
                    if !activeGames.isEmpty {
                        let titles = activeGames.map(\.title).prefix(3).joined(separator: ", ")
                        Text("Kurerat efter alla dina aktiva spel: \(titles)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else if let fav = store.games.filter({ ($0.rating ?? 0) >= 7 }).first {
                        Text("Kurerat efter ditt favoritspel \(fav.title) (\(fav.rating ?? 9)/10)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Kurerat efter dina plattformar och favoritgenrer.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if isLoadingRecommended {
                    ProgressView()
                        .padding(.vertical, 20)
                } else {
                    horizontalCuratedList(items: curatedRecommendations)
                }
            }
        }
    }

    @ViewBuilder
    private var popularSubSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.red)
                    Text("Trendar just nu")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }

                Spacer()

                NavigationLink(destination: AddGameView()) {
                    Text("Sök fler")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }

            if isLoadingPopular {
                ProgressView()
                    .padding(.vertical, 20)
            } else {
                horizontalIGDBList(games: popularGames, showRank: true)
            }
        }
    }

    @ViewBuilder
    private var upcomingSubSection: some View {
        if !upcomingGames.isEmpty || isLoadingUpcoming {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.red)
                    Text("Kommande releaser")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }

                if isLoadingUpcoming {
                    ProgressView()
                        .padding(.vertical, 20)
                } else {
                    horizontalIGDBList(games: upcomingGames, showReleaseDate: true)
                }
            }
        }
    }

    @ViewBuilder
    private var genreSubSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundStyle(.red)
                    Text("Utforska per genre")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }

                Spacer()

                // Sortering
                Menu {
                    Button("Mest populära") {
                        genreSort = "popularity"
                        loadGenreGames(selectedGenre, limit: 12)
                    }
                    Button("Högst betyg") {
                        genreSort = "rating"
                        loadGenreGames(selectedGenre, limit: 12)
                    }
                    Button("Nyast först") {
                        genreSort = "newest"
                        loadGenreGames(selectedGenre, limit: 12)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(genreSortTitle)
                            .font(.caption.bold())
                        Text("Utforska per genre")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    // Sortering
                    Menu {
                        Button("Mest populära") {
                            genreSort = "popularity"
                            loadGenreGames(selectedGenre, limit: 12)
                        }
                        Button("Högst betyg") {
                            genreSort = "rating"
                            loadGenreGames(selectedGenre, limit: 12)
                        }
                        Button("Nyast först") {
                            genreSort = "newest"
                            loadGenreGames(selectedGenre, limit: 12)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(genreSortTitle)
                                .font(.caption.bold())
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                        .foregroundStyle(.primary)
                    }
                }

                // Horisontell Genre-rad (favoritgenrer visas först med hjärtikon)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sortedGenres) { item in
                            let isSelected = selectedGenre.id == item.id
                            let isFav = isGenreFavorite(item)
                            Button {
                                if !isSelected {
                                    selectedGenre = item
                                    genreLimit = 12
                                    loadGenreGames(item, limit: 12)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if isFav {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(isSelected ? Color.white : Color.red)
                                    }
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(isSelected ? Color.red : Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Genre Grid
                if isLoadingGenre && selectedGenreGames.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Laddar \(selectedGenre.name)...")
                            .padding(.vertical, 24)
                        Spacer()
                    }
                } else if selectedGenreGames.isEmpty {
                    Text("Inga spel hittades inom \(selectedGenre.name).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 16)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 16) {
                        ForEach(selectedGenreGames, id: \.id) { game in
                            NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ZStack(alignment: .topTrailing) {
                                        CoverView(title: game.name, url: game.coverURL, corner: 14, height: 190)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 190)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                                        if let rating = game.totalRating, rating > 0 {
                                            HStack(spacing: 2) {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.yellow)
                                                Text(String(format: "%.0f", rating))
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(.black.opacity(0.75), in: Capsule())
                                            .padding(6)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(game.name)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        if let year = game.releaseYear {
                                            Text("\(String(year)) • \(selectedGenre.name)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        } else if let platform = game.platforms?.first?.name {
                                            Text(platform)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Sömlös "Visa fler"-knapp
                    if genreLimit < 48 {
                        Button {
                            loadMoreGenreGames()
                        } label: {
                            HStack(spacing: 6) {
                                if isLoadingMoreGenre {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Visa fler \(selectedGenre.name)-spel")
                                        .font(.caption.bold())
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.primary)
                        }
                        .disabled(isLoadingMoreGenre)
                        .padding(.top, 6)
                    }
                }
            }
        }
        .task(id: refreshTrigger) {
            await loadAllDiscovery()
            loadGenreGames(selectedGenre, limit: 12)
        }
    }

    private var genreSortTitle: String {
        switch genreSort {
        case "rating": return "Högst betyg"
        case "newest": return "Nyast först"
        default: return "Mest populära"
        }
    }

    private func horizontalCuratedList(items: [CuratedRecommendation]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(items) { item in
                    let game = item.game
                    NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topLeading) {
                                CoverView(title: game.name, url: game.coverURL, corner: 12, height: 140)
                                    .frame(width: 105, height: 140)
                                    .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)

                                Text(item.matchedReason)
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2.5)
                                    .background(Color.ds.brandRed.opacity(0.9), in: Capsule())
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .frame(maxWidth: 95, alignment: .leading)
                                    .padding(4)

                                if let rating = game.totalRating, rating > 0 {
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            HStack(spacing: 2) {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 7))
                                                    .foregroundStyle(.yellow)
                                                Text(String(format: "%.0f", rating))
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(.black.opacity(0.75), in: Capsule())
                                            .padding(4)
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(game.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if let platform = game.platforms?.first?.name {
                                    Text(platform)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 105, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func horizontalIGDBList(games: [IGDBGame], showReleaseDate: Bool = false, showRank: Bool = false, isPersonalized: Bool = false) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Array(games.enumerated()), id: \.element.id) { idx, game in
                    NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topLeading) {
                                CoverView(title: game.name, url: game.coverURL, corner: 12, height: 140)
                                    .frame(width: 105, height: 140)
                                    .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)

                                if showRank {
                                    Text("#\(idx + 1)")
                                        .font(.system(size: 9, weight: .black))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(idx == 0 ? Color.yellow : (idx == 1 ? Color.white : (idx == 2 ? Color.orange : Color.black.opacity(0.8))))
                                        .foregroundStyle(idx < 2 ? Color.black : Color.white)
                                        .clipShape(Capsule())
                                        .padding(4)
                                } else if isPersonalized && idx < 4 {
                                    Text("Matchning")
                                        .font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2.5)
                                        .background(Color.ds.brandRed.opacity(0.85), in: Capsule())
                                        .foregroundStyle(.white)
                                        .padding(4)
                                }

                                if let rating = game.totalRating, rating > 0 {
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            HStack(spacing: 2) {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 7))
                                                    .foregroundStyle(.yellow)
                                                Text(String(format: "%.0f", rating))
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(.black.opacity(0.75), in: Capsule())
                                            .padding(4)
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(game.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if showReleaseDate, let dateStr = game.releaseDateFormatted {
                                    HStack(spacing: 4) {
                                        Text(dateStr)
                                            .font(.caption2.bold())
                                            .foregroundStyle(.red)
                                            .lineLimit(1)

                                        Spacer()

                                        let isInWishlist = store.games.contains { $0.igdbID == game.id }
                                        Button {
                                            if !isInWishlist {
                                                let newGame = Game(
                                                    title: game.name,
                                                    platforms: PlatformMatcher.resolvePlatforms(availableIGDBPlatforms: game.platforms?.map(\.name) ?? []),
                                                    releaseYear: game.releaseYear ?? 0,
                                                    genres: game.genres?.map(\.name) ?? [],
                                                    developers: game.developerName.map { [$0] } ?? [],
                                                    status: .wishlist,
                                                    rating: 0,
                                                    igdbRating: game.totalRating.map { $0 / 10 },
                                                    coverURL: game.coverURL,
                                                    igdbID: game.id,
                                                    firstReleaseDate: game.firstReleaseDate
                                                )
                                                store.add(newGame)
                                            }
                                        } label: {
                                            Image(systemName: isInWishlist ? "checkmark.circle.fill" : "plus.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(isInWishlist ? Color.green : Color.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } else if let platform = game.platforms?.first?.name {
                                    Text(platform)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 105, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func loadAllDiscovery() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadRecommendations() }
            group.addTask { await loadPopular() }
            group.addTask { await loadUpcoming() }
        }
    }

    private func loadRecommendations() async {
        isLoadingRecommended = true
        let libraryTitles = Set(store.games.map { $0.title.lowercased() })
        let libraryIDs = Set(store.games.compactMap { $0.igdbID })

        // 1. Primär signal: Användarens Favoritspel från profilen
        let favoriteGames: [Game] = profile.favoriteGameIDs.compactMap { favID in
            store.games.first(where: { $0.id.uuidString == favID })
        }

        // 2. Aktiva spel som spelas just nu
        let activeGames = store.games.filter { $0.status == .playing }

        // 3. Högt betygsatta spel (>= 7)
        let rated = store.games.filter { ($0.rating ?? 0) >= 7 }.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }

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
            for g in store.games.prefix(2) {
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
            let badgeText = "\(ref.badgePrefix): \(shortTitle.prefix(13))"

            for g in refResults {
                seenIDs.insert(g.id)
                allCurated.append(CuratedRecommendation(game: g, matchedReason: badgeText))
            }
        }

        // Fallback om för få hittades - prioritera profilens favoritgenrer först!
        if allCurated.count < 6 {
            let profileGenres = Array(profile.favoriteGenres)
            let fallbackGenres = !profileGenres.isEmpty ? profileGenres : (userTopGenres.isEmpty ? ["Action", "Role-playing (RPG)", "Adventure"] : userTopGenres)
            if let fallback = try? await IGDBService.shared.fetchRecommendations(forGenres: fallbackGenres, limit: 10) {
                for g in fallback where !libraryIDs.contains(g.id) && !seenIDs.contains(g.id) {
                    seenIDs.insert(g.id)
                    allCurated.append(CuratedRecommendation(game: g, matchedReason: "Toppval i din smak"))
                }
            }
        }

        await MainActor.run {
            self.curatedRecommendations = Array(allCurated.prefix(16))
            self.isLoadingRecommended = false
        }
    }

    private func loadPopular() async {
        isLoadingPopular = true
        do {
            let results = try await IGDBService.shared.fetchTrendingGames(platformIDs: [])
            await MainActor.run {
                self.popularGames = Array(results.prefix(12))
                self.isLoadingPopular = false
            }
        } catch {
            await MainActor.run { self.isLoadingPopular = false }
        }
    }

    private func loadUpcoming() async {
        isLoadingUpcoming = true
        do {
            let results = try await IGDBService.shared.fetchUpcomingGames(limit: 12)
            await MainActor.run {
                self.upcomingGames = results
                self.isLoadingUpcoming = false
            }
        } catch {
            await MainActor.run { self.isLoadingUpcoming = false }
        }
    }

    private func loadGenreGames(_ genre: VisualGenreItem, limit: Int = 12) {
        isLoadingGenre = true
        Task {
            do {
                let results = try await IGDBService.shared.fetchPopularGames(genre: genre.queryName, sort: genreSort, limit: limit)
                await MainActor.run {
                    self.selectedGenreGames = results
                    self.isLoadingGenre = false
                }
            } catch {
                await MainActor.run { self.isLoadingGenre = false }
            }
        }
    }

    private func loadMoreGenreGames() {
        let nextLimit = genreLimit + 12
        isLoadingMoreGenre = true
        Task {
            do {
                let results = try await IGDBService.shared.fetchPopularGames(genre: selectedGenre.queryName, sort: genreSort, limit: nextLimit)
                await MainActor.run {
                    self.selectedGenreGames = results
                    self.genreLimit = nextLimit
                    self.isLoadingMoreGenre = false
                }
            } catch {
                await MainActor.run { self.isLoadingMoreGenre = false }
            }
        }
    }
}
