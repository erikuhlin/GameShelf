//
//  AddGameView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

struct AddGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: LibraryStore

    @State private var searchText = ""
    @State private var searchResults: [IGDBGame] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var searchDebounceTask: Task<Void, Never>? = nil

    // Avancerade filter
    @State private var filterConfig = SearchFilterConfig()
    @State private var showingFilterSheet = false

    // Förslag & Rekommendationer
    @State private var recommendedGames: [IGDBGame] = []
    @State private var popularGames: [IGDBGame] = []
    @State private var isLoadingDiscovery = false
    @State private var selectedGenreFilter: String? = nil
    @State private var discoveryDebounceTask: Task<Void, Never>? = nil

    let prefillTitle: String?

    init(prefillTitle: String? = nil) {
        self.prefillTitle = prefillTitle
        self._searchText = State(initialValue: prefillTitle ?? "")
    }

    private var isSearchingOrFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || filterConfig.isActive
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Aktiva filter-chips under sökfältet
                if filterConfig.isActive {
                    activeFilterChipsBar
                }

                Group {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.red)
                            Text(filterConfig.isActive ? "Filtrerar spel från IGDB..." : "Söker i IGDB...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMsg = errorMessage {
                        errorView(message: errorMsg)
                    } else if searchResults.isEmpty && isSearchingOrFiltering {
                        ContentUnavailableView(
                            "Inga spel hittades",
                            systemImage: "magnifyingglass",
                            description: Text("Inga resultat matchar din sökning och dina filter. Prova att ändra filtren eller sökorden.")
                        )
                        .padding(.top, 40)
                    } else if !searchResults.isEmpty {
                        searchResultsList
                    } else {
                        discoveryView
                    }
                }
            }
            .background(Color.ds.background.ignoresSafeArea())
            .navigationTitle("Lägg till spel")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Int.self) { gameID in
                GameDetailView(igdbID: gameID)
            }
            .searchable(text: $searchText, prompt: "Sök spel på titel...")
            .onSubmit(of: .search) {
                performSearch()
            }
            .onChange(of: searchText) { _, newValue in
                searchDebounceTask?.cancel()
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !filterConfig.isActive {
                    searchResults = []
                    isLoading = false
                    errorMessage = nil
                    return
                }

                searchDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if Task.isCancelled { return }
                    await performSearchAsync()
                }
            }
            .task {
                if let prefill = prefillTitle, !prefill.trimmingCharacters(in: .whitespaces).isEmpty {
                    await performSearchAsync()
                } else {
                    await loadDiscoveryData()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Klar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filterConfig.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            if filterConfig.isActive {
                                Text("\(filterConfig.activeFilterCount)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.red, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .foregroundStyle(filterConfig.isActive ? Color.red : Color.primary)
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                AdvancedSearchFilterSheet(config: $filterConfig) {
                    Task { await performSearchAsync() }
                }
            }
        }
    }

    // MARK: - Aktiva Filter Chips Bar
    private var activeFilterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Period
                if let s = filterConfig.startYear, let e = filterConfig.endYear {
                    filterChip(label: s == e ? "📅 \(s)" : "📅 \(s)–\(e)") {
                        filterConfig.startYear = nil
                        filterConfig.endYear = nil
                        Task { await performSearchAsync() }
                    }
                } else if let s = filterConfig.startYear {
                    filterChip(label: "📅 Från \(s)") {
                        filterConfig.startYear = nil
                        Task { await performSearchAsync() }
                    }
                } else if let e = filterConfig.endYear {
                    filterChip(label: "📅 Till \(e)") {
                        filterConfig.endYear = nil
                        Task { await performSearchAsync() }
                    }
                }

                // Plattform
                if let platID = filterConfig.platformID {
                    let platName = platformNameFor(platID)
                    filterChip(label: "🎮 \(platName)") {
                        filterConfig.platformID = nil
                        Task { await performSearchAsync() }
                    }
                }

                // Utvecklare
                if !filterConfig.developer.isEmpty {
                    filterChip(label: "🏢 \(filterConfig.developer)") {
                        filterConfig.developer = ""
                        Task { await performSearchAsync() }
                    }
                }

                // Genre
                if let g = filterConfig.genre {
                    filterChip(label: "⚔️ \(g)") {
                        filterConfig.genre = nil
                        Task { await performSearchAsync() }
                    }
                }

                // Sortering
                if filterConfig.sortOption != .popularity {
                    filterChip(label: "⭐️ \(filterConfig.sortOption.rawValue)") {
                        filterConfig.sortOption = .popularity
                        Task { await performSearchAsync() }
                    }
                }

                // Rensa alla
                Button {
                    withAnimation {
                        filterConfig.reset()
                        if searchText.isEmpty {
                            searchResults = []
                        } else {
                            Task { await performSearchAsync() }
                        }
                    }
                } label: {
                    Text("Rensa alla")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func filterChip(label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.red.opacity(0.12))
        .foregroundStyle(.red)
        .clipShape(Capsule())
    }

    private func platformNameFor(_ id: Int) -> String {
        switch id {
        case 167: return "PS5"
        case 48: return "PS4"
        case 9: return "PS3"
        case 169: return "Xbox Series"
        case 49: return "Xbox One"
        case 12: return "Xbox 360"
        case 130: return "Switch"
        case 6: return "PC"
        default: return "Plattform"
        }
    }

    // MARK: - Error view
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Kunde inte hämta spel")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    if isSearchingOrFiltering {
                        await performSearchAsync()
                    } else {
                        await loadDiscoveryData()
                    }
                }
            } label: {
                Label("Försök igen", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(24)
    }

    // MARK: - Sökresultat-lista med 1-Klicks Tillägg
    private var searchResultsList: some View {
        List {
            Section {
                ForEach(searchResults, id: \.id) { game in
                    let localGame = store.games.first(where: {
                        ($0.igdbID != nil && $0.igdbID == game.id) ||
                        $0.title.lowercased() == game.name.lowercased()
                    })

                    NavigationLink(value: game.id) {
                        IGDBSearchRow(
                            igdbGame: game,
                            localGame: localGame,
                            onQuickAdd: { status in
                                quickAdd(game: game, status: status)
                            }
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } header: {
                HStack {
                    Text("Resultat (\(searchResults.count))")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if filterConfig.sortOption != .popularity {
                        Text(filterConfig.sortOption.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Utforska-vy (När man inte söker)
    private var discoveryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // 1. Genre-chips
                VStack(alignment: .leading, spacing: 10) {
                    Text("Utforska per genre")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([
                                "Alla", "RPG", "Action", "Skjutspel", "Äventyr",
                                "Strategi", "Skräck", "Simulator", "Racing", "Sport",
                                "Plattform", "Pussel", "Fighting", "Indie", "Arkad"
                            ], id: \.self) { genre in
                                let isSelected = (selectedGenreFilter == genre) || (genre == "Alla" && selectedGenreFilter == nil)
                                Button {
                                    let newFilter = (genre == "Alla") ? nil : genre
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedGenreFilter = newFilter
                                    }
                                    discoveryDebounceTask?.cancel()
                                    discoveryDebounceTask = Task {
                                        await loadDiscoveryData(genre: newFilter)
                                    }
                                } label: {
                                    Text(genre)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Color.red : Color(.secondarySystemGroupedBackground))
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .clipShape(Capsule())
                                        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // 2. Förslag baserade på biblioteket
                if !recommendedGames.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Rekommenderat för dig")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            Spacer()
                        }

                        LazyVStack(spacing: 10) {
                            ForEach(recommendedGames.prefix(5), id: \.id) { game in
                                let localGame = store.games.first(where: {
                                    ($0.igdbID != nil && $0.igdbID == game.id) ||
                                    $0.title.lowercased() == game.name.lowercased()
                                })
                                NavigationLink(value: game.id) {
                                    IGDBSearchRow(
                                        igdbGame: game,
                                        localGame: localGame,
                                        onQuickAdd: { status in
                                            quickAdd(game: game, status: status)
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // 3. Populära spel just nu
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(selectedGenreFilter != nil ? "Populärt inom \(selectedGenreFilter!)" : "Populärt just nu")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                    }

                    if isLoadingDiscovery {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    } else if popularGames.isEmpty {
                        Text("Inga spel hittades för denna genre.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 16)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(popularGames, id: \.id) { game in
                                let localGame = store.games.first(where: {
                                    ($0.igdbID != nil && $0.igdbID == game.id) ||
                                    $0.title.lowercased() == game.name.lowercased()
                                })
                                NavigationLink(value: game.id) {
                                    IGDBSearchRow(
                                        igdbGame: game,
                                        localGame: localGame,
                                        onQuickAdd: { status in
                                            quickAdd(game: game, status: status)
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - Snabb-lägg till i biblioteket
    private func quickAdd(game: IGDBGame, status: PlayStatus) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let platforms = game.platforms?.map(\.name) ?? []
        let genres = game.genres?.map(\.name) ?? []
        let normalizedRating = (game.totalRating ?? 0.0) / 20.0
        let est = game.timeToBeat?.mainStoryHours ?? game.timeToBeat?.mainExtraHours

        let newGame = Game(
            title: game.name,
            platforms: platforms,
            releaseYear: game.releaseYear ?? 0,
            genres: genres,
            developers: game.developerName.map { [$0] } ?? [],
            status: status,
            rating: 0,
            igdbRating: normalizedRating,
            coverURL: game.coverURL,
            igdbID: game.id,
            firstReleaseDate: game.firstReleaseDate,
            estimatedHours: est
        )

        store.add(newGame)
    }

    // MARK: - Söklogik
    private func performSearch() {
        searchDebounceTask?.cancel()
        Task {
            await performSearchAsync()
        }
    }

    private func performSearchAsync() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty && !filterConfig.isActive {
            await MainActor.run {
                searchResults = []
                isLoading = false
                errorMessage = nil
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let platformIDs = filterConfig.platformID.map { [$0] } ?? []
            let results = try await IGDBService.shared.discoverGames(
                query: trimmed.isEmpty ? nil : trimmed,
                startYear: filterConfig.startYear,
                endYear: filterConfig.endYear,
                platformIDs: platformIDs,
                genre: filterConfig.genre,
                developer: filterConfig.developer.isEmpty ? nil : filterConfig.developer,
                sortOption: filterConfig.sortOption,
                limit: 35
            )

            await MainActor.run {
                self.searchResults = results
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Kunde inte slutföra sökningen (\(error.localizedDescription))."
                self.isLoading = false
            }
        }
    }

    // MARK: - Ladda Förslag & Rekommendationer
    private func loadDiscoveryData(genre: String? = nil) async {
        await MainActor.run {
            isLoadingDiscovery = true
        }

        let targetGenre = genre ?? selectedGenreFilter
        let mappedGenre = targetGenre.flatMap(mapGenreName)

        do {
            async let recommendedFetch: [IGDBGame] = {
                if !recommendedGames.isEmpty { return recommendedGames }
                let userTopGenres = store.games.flatMap(\.genres)
                var counts: [String: Int] = [:]
                for g in userTopGenres where !g.isEmpty { counts[g, default: 0] += 1 }
                let top = counts.sorted { $0.value > $1.value }.prefix(3).map(\.key)
                if top.isEmpty { return [] }
                return try await IGDBService.shared.fetchRecommendations(forGenres: Array(top), limit: 5)
            }()

            async let popularFetch: [IGDBGame] = {
                return try await IGDBService.shared.fetchPopularGames(genre: mappedGenre, limit: 12)
            }()

            let (recommended, popular) = try await (recommendedFetch, popularFetch)
            if Task.isCancelled { return }

            await MainActor.run {
                self.recommendedGames = recommended
                self.popularGames = popular
                self.isLoadingDiscovery = false
            }
        } catch {
            if Task.isCancelled { return }
            await MainActor.run {
                self.isLoadingDiscovery = false
            }
        }
    }

    private func mapGenreName(_ genre: String) -> String? {
        let lower = genre.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower == "alla" || lower.isEmpty { return nil }
        if lower.contains("rpg") || lower.contains("role") { return "Role-playing (RPG)" }
        if lower.contains("action") { return "Action" }
        if lower.contains("skjut") || lower.contains("shooter") || lower.contains("fps") { return "Shooter" }
        if lower.contains("adventure") || lower.contains("äventyr") { return "Adventure" }
        if lower.contains("strategy") || lower.contains("strategi") { return "Strategy" }
        if lower.contains("skräck") || lower.contains("horror") { return "Horror" }
        if lower.contains("simulator") || lower.contains("simulering") { return "Simulator" }
        if lower.contains("racing") { return "Racing" }
        if lower.contains("sport") { return "Sport" }
        if lower.contains("platform") || lower.contains("plattform") { return "Platform" }
        if lower.contains("puzzle") || lower.contains("pussel") { return "Puzzle" }
        if lower.contains("fighting") || lower.contains("slagsmål") { return "Fighting" }
        if lower.contains("indie") { return "Indie" }
        if lower.contains("arcade") || lower.contains("arkad") { return "Arcade" }
        return genre
    }
}

// MARK: - Radvy för Sök och Förslag med 1-Klicks Tillägg
private struct IGDBSearchRow: View {
    @EnvironmentObject var store: LibraryStore
    let igdbGame: IGDBGame
    let localGame: Game?
    var onQuickAdd: (PlayStatus) -> Void

    var body: some View {
        HStack(spacing: 12) {
            CoverView(title: igdbGame.name, url: igdbGame.coverURL, corner: 8, height: 75)
                .frame(width: 55, height: 75)
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(igdbGame.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    if let year = igdbGame.releaseYear, year > 0 {
                        Text(String(year))
                    }
                    if let rating = igdbGame.totalRating, rating > 0 {
                        Text("•")
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating / 10))
                        }
                    }
                    if let genres = igdbGame.genres, !genres.isEmpty {
                        Text("•")
                        Text(genres.prefix(1).map(\.name).joined(separator: ", "))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            // 1-Trycks Snabb-knapp eller Statusbadge
            if let local = localGame {
                Menu {
                    ForEach(PlayStatus.allCases) { st in
                        Button {
                            updateStatus(st, for: local)
                        } label: {
                            HStack {
                                if local.status == st {
                                    Image(systemName: "checkmark")
                                }
                                Label(st.rawValue, systemImage: st.icon)
                            }
                        }
                    }
                } label: {
                    StatusBadge(status: local.status)
                }
                .buttonStyle(.plain)
            } else {
                Menu {
                    Button {
                        onQuickAdd(.backlog)
                    } label: {
                        Label("Lägg till i Backlog", systemImage: "archivebox.fill")
                    }

                    Button {
                        onQuickAdd(.playing)
                    } label: {
                        Label("Lägg till som Spelar nu", systemImage: "play.fill")
                    }

                    Button {
                        onQuickAdd(.completed)
                    } label: {
                        Label("Lägg till som Klar", systemImage: "checkmark.seal.fill")
                    }

                    Button {
                        onQuickAdd(.wishlist)
                    } label: {
                        Label("Lägg till i Önskelista", systemImage: "heart.fill")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption2.bold())
                        Text("Lägg till")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                } primaryAction: {
                    onQuickAdd(.backlog)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func updateStatus(_ status: PlayStatus, for g: Game) {
        var updated = g
        updated.status = status
        store.update(updated)
    }
}
