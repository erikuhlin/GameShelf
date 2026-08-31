//
//  AddFavoriteGameSheet.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-31.
//

import SwiftUI

struct AddFavoriteGameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var profile: ProfileStore

    @State private var query = ""
    @State private var igdbResults: [IGDBGame] = []
    @State private var isSearchingIGDB = false

    private var filteredLibraryGames: [Game] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lowerFavIDs = Set(profile.favoriteGameIDs.map { $0.lowercased() })
        if q.isEmpty {
            return store.games.filter {
                let uuid = $0.id.uuidString.lowercased()
                let igdbStr = $0.igdbID != nil ? String($0.igdbID!) : nil
                return !lowerFavIDs.contains(uuid) && (igdbStr == nil || !lowerFavIDs.contains(igdbStr!))
            }
        }
        return store.games.filter {
            let uuid = $0.id.uuidString.lowercased()
            let igdbStr = $0.igdbID != nil ? String($0.igdbID!) : nil
            let notFav = !lowerFavIDs.contains(uuid) && (igdbStr == nil || !lowerFavIDs.contains(igdbStr!))
            return notFav && $0.title.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sökfält
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Sök spel att lägga till...", text: $query)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, newQuery in
                            performIGDBSearch(query: newQuery)
                        }
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                List {
                    // 1. Spel från användarens bibliotek
                    if !filteredLibraryGames.isEmpty {
                        Section("Från ditt bibliotek") {
                            ForEach(filteredLibraryGames.prefix(20)) { game in
                                Button {
                                    addGameAsFavorite(game)
                                } label: {
                                    HStack(spacing: 12) {
                                        CoverView(title: game.title, url: game.coverURL, corner: 6, height: 50)
                                            .frame(width: 38, height: 50)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(game.title)
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.primary)
                                            if game.releaseYear > 0 {
                                                Text("\(game.releaseYear)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(Color.red)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 2. Resultat från IGDB
                    if isSearchingIGDB {
                        Section("Söker på IGDB...") {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    } else if !igdbResults.isEmpty {
                        Section("Från IGDB") {
                            ForEach(igdbResults) { game in
                                Button {
                                    addIGDBGameAsFavorite(game)
                                } label: {
                                    HStack(spacing: 12) {
                                        CoverView(title: game.name, url: game.coverURL, corner: 6, height: 50)
                                            .frame(width: 38, height: 50)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(game.name)
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.primary)
                                            if let year = game.releaseYear, year > 0 {
                                                Text("\(year)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(Color.red)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Välj favoritspel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                    .font(.body.bold())
                    .foregroundStyle(Color.red)
                }
            }
        }
    }

    private func addGameAsFavorite(_ game: Game) {
        withAnimation {
            profile.addFavoriteGame(id: game.id.uuidString)
        }
        if profile.favoriteGameIDs.count >= 10 {
            dismiss()
        }
    }

    private func addIGDBGameAsFavorite(_ igdbGame: IGDBGame) {
        // Kontrollera om spelet redan finns i store
        if let existing = store.games.first(where: { $0.igdbID == igdbGame.id }) {
            addGameAsFavorite(existing)
            return
        }

        // Annars lägg till spelet i biblioteket först (som ägt eller favorit)
        let newGame = Game(
            title: igdbGame.name,
            platforms: igdbGame.platforms?.compactMap { $0.name } ?? [],
            releaseYear: igdbGame.releaseYear ?? 0,
            genres: igdbGame.genres?.compactMap { $0.name } ?? [],
            developers: igdbGame.developerName.map { [$0] } ?? [],
            status: .completed,
            rating: nil,
            coverURL: igdbGame.coverURL,
            igdbID: igdbGame.id
        )
        store.add(newGame)
        withAnimation {
            profile.addFavoriteGame(id: newGame.id.uuidString)
        }
        if profile.favoriteGameIDs.count >= 10 {
            dismiss()
        }
    }

    private func performIGDBSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            igdbResults = []
            return
        }

        Task {
            isSearchingIGDB = true
            do {
                let results = try await IGDBService.shared.searchGames(query: trimmed)
                await MainActor.run {
                    self.igdbResults = results.filter { igdbG in
                        !profile.favoriteGameIDs.contains(where: { favID in
                            let lower = favID.lowercased()
                            return store.games.first(where: {
                                $0.id.uuidString.lowercased() == lower ||
                                ($0.igdbID != nil && String($0.igdbID!) == favID)
                            })?.igdbID == igdbG.id
                        })
                    }
                    self.isSearchingIGDB = false
                }
            } catch {
                await MainActor.run {
                    self.isSearchingIGDB = false
                }
            }
        }
    }
}
