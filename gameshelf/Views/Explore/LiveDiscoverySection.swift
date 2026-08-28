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

struct LiveDiscoverySection: View {
    @EnvironmentObject var store: LibraryStore

    var refreshTrigger: UUID = UUID()

    @State private var recommendedGames: [IGDBGame] = []
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
        VStack(alignment: .leading, spacing: 28) {
            // 1. För dig (Personliga rekommendationer)
            if !recommendedGames.isEmpty || isLoadingRecommended {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("För dig")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)

                        if let top = userTopGenres.first {
                            Text("Eftersom du gillar \(top) och liknande spel.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Personliga rekommendationer från IGDB.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if isLoadingRecommended {
                        ProgressView()
                            .padding(.vertical, 20)
                    } else {
                        horizontalIGDBList(games: recommendedGames)
                    }
                }
            }

            // 2. Trendar just nu (med rankningsbadge)
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

            // 3. Kommande releaser
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

            // 4. Utforska per genre (Ren & Modern Design)
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

                // Horisontell Genre-rad
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(genres) { item in
                            let isSelected = selectedGenre.id == item.id
                            Button {
                                if !isSelected {
                                    selectedGenre = item
                                    genreLimit = 12
                                    loadGenreGames(item, limit: 12)
                                }
                            } label: {
                                Text(item.name)
                                    .font(.subheadline.weight(.semibold))
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

    private func horizontalIGDBList(games: [IGDBGame], showReleaseDate: Bool = false, showRank: Bool = false) -> some View {
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
                                    Text(dateStr)
                                        .font(.caption2.bold())
                                        .foregroundStyle(.red)
                                        .lineLimit(1)
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
        do {
            let genres = userTopGenres.isEmpty ? ["Action", "Role-playing (RPG)", "Adventure"] : userTopGenres
            let results = try await IGDBService.shared.fetchRecommendations(forGenres: genres, limit: 12)
            await MainActor.run {
                self.recommendedGames = results
                self.isLoadingRecommended = false
            }
        } catch {
            await MainActor.run { self.isLoadingRecommended = false }
        }
    }

    private func loadPopular() async {
        isLoadingPopular = true
        do {
            let results = try await IGDBService.shared.fetchPopularGames(limit: 12)
            await MainActor.run {
                self.popularGames = results
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
