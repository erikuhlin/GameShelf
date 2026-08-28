//
//  AddGamesToCollectionSheet.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

struct AddGamesToCollectionSheet: View {
    var collection: GameCollection?
    @Binding var selectedGameIDs: Set<UUID>
    private let isUsingBinding: Bool

    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var igdbResults: [IGDBGame] = []
    @State private var isSearchingIGDB = false
    @State private var igdbErrorMessage: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    init(collection: GameCollection) {
        self.collection = collection
        self._selectedGameIDs = .constant([])
        self.isUsingBinding = false
    }

    init(selectedGameIDs: Binding<Set<UUID>>) {
        self.collection = nil
        self._selectedGameIDs = selectedGameIDs
        self.isUsingBinding = true
    }

    private var currentCollection: GameCollection? {
        guard let col = collection else { return nil }
        return store.collections.first(where: { $0.id == col.id }) ?? col
    }

    /// Spel från biblioteket som matchar sökningen
    private var filteredLocalGames: [Game] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return store.games
        }
        return store.games.filter {
            $0.title.lowercased().contains(query) ||
            $0.genres.contains(where: { $0.lowercased().contains(query) }) ||
            $0.platforms.contains(where: { $0.lowercased().contains(query) })
        }
    }

    private func isGameSelected(_ gameID: UUID) -> Bool {
        if isUsingBinding {
            return selectedGameIDs.contains(gameID)
        } else if let col = currentCollection {
            return col.gameIDs.contains(gameID)
        }
        return false
    }

    private func toggleGameSelection(_ gameID: UUID) {
        if isUsingBinding {
            if selectedGameIDs.contains(gameID) {
                selectedGameIDs.remove(gameID)
            } else {
                selectedGameIDs.insert(gameID)
            }
        } else if let col = currentCollection {
            store.toggleGame(gameID, in: col.id)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Sektion 1: Från ditt bibliotek
                Section("Ditt bibliotek (\(filteredLocalGames.count))") {
                    if filteredLocalGames.isEmpty {
                        Text(searchText.isEmpty ? "Inga spel i biblioteket" : "Inga matchande spel i ditt bibliotek")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredLocalGames) { game in
                            let isSelected = isGameSelected(game.id)
                            Button {
                                toggleGameSelection(game.id)
                            } label: {
                                HStack(spacing: 12) {
                                    CoverView(title: game.title, url: game.coverURL, corner: 6, height: 44)
                                        .frame(width: 32, height: 44)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(game.title)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)

                                        HStack(spacing: 6) {
                                            StatusBadge(status: game.status)

                                            if game.releaseYear > 0 {
                                                Text(String(game.releaseYear))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(isSelected ? Color.blue : Color.secondary.opacity(0.5))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Sektion 2: Sökning på IGDB (när söktext inte är tom)
                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Hitta i IGDB (\(igdbResults.count))") {
                        if isSearchingIGDB {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 6)
                                Text("Söker i IGDB...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        } else if let errorMsg = igdbErrorMessage {
                            Text(errorMsg)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else if igdbResults.isEmpty {
                            Text("Inga fler spel hittades på IGDB.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(igdbResults, id: \.id) { igdbGame in
                                let existingLocal = store.games.first(where: {
                                    $0.igdbID == igdbGame.id || $0.title.lowercased() == igdbGame.name.lowercased()
                                })
                                let isAdded = existingLocal != nil && isGameSelected(existingLocal!.id)

                                Button {
                                    handleIGDBGameTap(igdbGame, existingLocal: existingLocal)
                                } label: {
                                    HStack(spacing: 12) {
                                        CoverView(title: igdbGame.name, url: igdbGame.coverURL, corner: 6, height: 44)
                                            .frame(width: 32, height: 44)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(igdbGame.name)
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.primary)

                                            HStack(spacing: 6) {
                                                if let year = igdbGame.releaseYear, year > 0 {
                                                    Text(String(year))
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                if let firstPlatform = igdbGame.platforms?.first?.name {
                                                    Text("• \(firstPlatform)")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                        }

                                        Spacer()

                                        if isAdded {
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(.blue)
                                            }
                                        } else {
                                            Label("Lägg till", systemImage: "plus.circle.fill")
                                                .font(.caption.bold())
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Sök i bibliotek & IGDB...")
            .navigationTitle("Hantera spel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                        .font(.headline)
                }
            }
            .onChange(of: searchText) { _, newValue in
                performDebouncedIGDBSearch(query: newValue)
            }
        }
    }

    private func performDebouncedIGDBSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            igdbResults = []
            isSearchingIGDB = false
            igdbErrorMessage = nil
            return
        }

        isSearchingIGDB = true
        igdbErrorMessage = nil

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // 350ms debounce
            if Task.isCancelled { return }

            do {
                let results = try await IGDBService.shared.searchGames(query: trimmed)
                if Task.isCancelled { return }
                await MainActor.run {
                    self.igdbResults = results
                    self.isSearchingIGDB = false
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.igdbErrorMessage = "Kunde inte söka i IGDB (\(error.localizedDescription))."
                    self.isSearchingIGDB = false
                }
            }
        }
    }

    private func handleIGDBGameTap(_ igdbGame: IGDBGame, existingLocal: Game?) {
        let gameID: UUID
        if let local = existingLocal {
            gameID = local.id
        } else {
            // Skapa spelet i biblioteket
            let genres = igdbGame.genres?.map { $0.name } ?? []
            let platforms = igdbGame.platforms?.map { $0.name } ?? []
            let normalizedRating = (igdbGame.totalRating ?? 0.0) / 20.0
            let est = igdbGame.timeToBeat?.mainStoryHours ?? igdbGame.timeToBeat?.mainExtraHours

            let newGame = Game(
                title: igdbGame.name,
                platforms: platforms,
                releaseYear: igdbGame.releaseYear ?? 0,
                genres: genres,
                developers: igdbGame.developerName.map { [$0] } ?? [],
                status: .backlog,
                rating: 0,
                igdbRating: normalizedRating,
                coverURL: igdbGame.coverURL,
                igdbID: igdbGame.id,
                firstReleaseDate: igdbGame.firstReleaseDate,
                estimatedHours: est
            )

            store.add(newGame)
            gameID = newGame.id
        }

        toggleGameSelection(gameID)
    }
}
