//
//  LiveDiscoverySection.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

struct VisualGenreItem: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let queryName: String
}

struct LiveDiscoverySection: View {
    @EnvironmentObject var store: LibraryStore

    var refreshTrigger: UUID = UUID()

    @State private var recommendedGames: [IGDBGame] = []
    @State private var popularGames: [IGDBGame] = []
    @State private var upcomingGames: [IGDBGame] = []
    @State private var selectedGenreGames: [IGDBGame] = []
    @State private var selectedGenre: VisualGenreItem? = nil

    @State private var isLoadingRecommended = false
    @State private var isLoadingPopular = false
    @State private var isLoadingUpcoming = false
    @State private var isLoadingGenre = false

    private let genres: [VisualGenreItem] = [
        VisualGenreItem(name: "RPG", emoji: "⚔️", queryName: "Role-playing (RPG)"),
        VisualGenreItem(name: "Skjutspel", emoji: "🔫", queryName: "Shooter"),
        VisualGenreItem(name: "Äventyr", emoji: "🗡️", queryName: "Adventure"),
        VisualGenreItem(name: "Skräck", emoji: "👻", queryName: "Horror"),
        VisualGenreItem(name: "Strategi", emoji: "🧠", queryName: "Strategy"),
        VisualGenreItem(name: "Racing", emoji: "🏎️", queryName: "Racing"),
        VisualGenreItem(name: "Simulator", emoji: "✈️", queryName: "Simulator"),
        VisualGenreItem(name: "Plattform", emoji: "🍄", queryName: "Platform")
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
        VStack(alignment: .leading, spacing: 24) {
            // 1. För dig (Baserat på dina genrer)
            if !recommendedGames.isEmpty || isLoadingRecommended {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
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

            // 2. Populärt just nu
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Populärt just nu")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

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
                    horizontalIGDBList(games: popularGames)
                }
            }

            // 3. Upptäck genrer (Visuella kategorier)
            VStack(alignment: .leading, spacing: 12) {
                Text("Upptäck genrer")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(genres) { item in
                            let isSelected = selectedGenre?.name == item.name
                            Button {
                                withAnimation {
                                    if isSelected {
                                        selectedGenre = nil
                                        selectedGenreGames = []
                                    } else {
                                        selectedGenre = item
                                        loadGenreGames(item)
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(item.emoji)
                                        .font(.subheadline)
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.red : Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                if let currentGenre = selectedGenre {
                    if isLoadingGenre {
                        ProgressView("Laddar \(currentGenre.name)...")
                            .padding(.vertical, 10)
                    } else if !selectedGenreGames.isEmpty {
                        horizontalIGDBList(games: selectedGenreGames)
                            .transition(.opacity)
                    }
                }
            }

            // 4. Kommande spel
            if !upcomingGames.isEmpty || isLoadingUpcoming {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kommande releaser")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    if isLoadingUpcoming {
                        ProgressView()
                            .padding(.vertical, 20)
                    } else {
                        horizontalIGDBList(games: upcomingGames, showReleaseDate: true)
                    }
                }
            }
        }
        .task(id: refreshTrigger) {
            await loadAllDiscovery()
            if let sel = selectedGenre {
                loadGenreGames(sel)
            }
        }
    }

    private func horizontalIGDBList(games: [IGDBGame], showReleaseDate: Bool = false) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(games, id: \.id) { game in
                    NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .bottomTrailing) {
                                CoverView(title: game.name, url: game.coverURL, corner: 12, height: 140)
                                    .frame(width: 105, height: 140)
                                    .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)

                                if let rating = game.totalRating, rating > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.yellow)
                                        Text(String(format: "%.0f", rating))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(5)
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

    private func loadGenreGames(_ genre: VisualGenreItem) {
        isLoadingGenre = true
        selectedGenreGames = []
        Task {
            do {
                let results = try await IGDBService.shared.fetchPopularGames(genre: genre.queryName, limit: 15)
                await MainActor.run {
                    self.selectedGenreGames = results
                    self.isLoadingGenre = false
                }
            } catch {
                await MainActor.run { self.isLoadingGenre = false }
            }
        }
    }
}
