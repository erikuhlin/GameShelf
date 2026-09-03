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
    @EnvironmentObject var profile: ProfileStore

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

    // Paginering (Ladda fler)
    @State private var currentOffset: Int = 0
    @State private var hasMoreResults: Bool = false
    @State private var isLoadingMore: Bool = false
    private let pageSize = 20

    // Senaste sökningar
    @AppStorage("gameshelf_ios_recent_searches") private var recentSearchesRaw: String = ""

    let prefillTitle: String?
    let isModal: Bool

    init(prefillTitle: String? = nil, isModal: Bool = true) {
        self.prefillTitle = prefillTitle
        self.isModal = isModal
        self._searchText = State(initialValue: prefillTitle ?? "")
    }

    private var recentSearches: [String] {
        recentSearchesRaw.split(separator: "|||").map(String.init)
    }

    private func saveSearchTerm(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        var current = recentSearches.filter { $0.lowercased() != trimmed.lowercased() }
        current.insert(trimmed, at: 0)
        recentSearchesRaw = current.prefix(6).joined(separator: "|||")
    }

    private func removeSearchTerm(_ term: String) {
        let current = recentSearches.filter { $0 != term }
        recentSearchesRaw = current.joined(separator: "|||")
    }

    private var matchingLocalGames: [Game] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.games.filter {
            $0.title.lowercased().contains(q) ||
            $0.genres.contains(where: { $0.lowercased().contains(q) }) ||
            $0.platforms.contains(where: { $0.lowercased().contains(q) }) ||
            $0.developers.contains(where: { $0.lowercased().contains(q) })
        }
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
            .navigationTitle(isModal ? "Lägg till spel" : "Sök")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Int.self) { gameID in
                GameDetailView(igdbID: gameID)
            }
            .searchable(text: $searchText, prompt: "Sök och lägg till spel...")
            .onSubmit(of: .search) {
                let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count >= 2 {
                    saveSearchTerm(trimmed)
                }
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
                if isModal {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Klar") {
                            dismiss()
                        }
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

                // Min-betyg
                if filterConfig.minRating > 0 {
                    filterChip(label: "⭐ \(filterConfig.minRating)+") {
                        filterConfig.minRating = 0
                        Task { await performSearchAsync() }
                    }
                }

                // Dölj ägda
                if filterConfig.hideOwned {
                    filterChip(label: "👁️ Döljer ägda") {
                        filterConfig.hideOwned = false
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

    // MARK: - Sökresultat-lista med Universal Multi-Source
    private var searchResultsList: some View {
        List {
            // 1. I ditt bibliotek
            if !matchingLocalGames.isEmpty {
                Section {
                    ForEach(matchingLocalGames) { localGame in
                        NavigationLink(destination: GameDetailView(game: localGame)) {
                            HStack(spacing: 12) {
                                CoverView(title: localGame.title, url: localGame.coverURL, corner: 8, height: 60)
                                    .frame(width: 45, height: 60)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(localGame.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    HStack(spacing: 6) {
                                        StatusBadge(status: localGame.status)

                                        if let rating = localGame.rating {
                                            Text("⭐ \(rating)/10")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.yellow)
                                        }

                                        if localGame.releaseYear > 0 {
                                            Text(String(localGame.releaseYear))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                } header: {
                    HStack {
                        Image(systemName: "books.vertical.fill")
                            .foregroundStyle(.green)
                        Text("I ditt bibliotek (\(matchingLocalGames.count))")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 2. IGDB Resultat
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
                            onQuickAdd: { option in
                                quickAdd(game: game, option: option)
                            }
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } header: {
                HStack {
                    Image(systemName: "globe")
                        .foregroundStyle(.red)
                    Text("Hitta på IGDB (\(searchResults.count))")
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
            } footer: {
                if hasMoreResults {
                    HStack {
                        Spacer()
                        if isLoadingMore {
                            ProgressView()
                                .tint(.red)
                        } else {
                            Button {
                                Task { await performSearchAsync(loadMore: true) }
                            } label: {
                                Label("Ladda fler resultat", systemImage: "arrow.down.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Utforska-vy (När man inte söker)
    private var discoveryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // 0. Senaste sökningar
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Senaste sökningar", systemImage: "clock.arrow.circlepath")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Rensa") {
                                recentSearchesRaw = ""
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recentSearches, id: \.self) { term in
                                    Button {
                                        searchText = term
                                        saveSearchTerm(term)
                                        Task { await performSearchAsync() }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(term)
                                                .font(.subheadline)
                                            Button {
                                                removeSearchTerm(term)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .foregroundStyle(.primary)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Smarta Sökförslag
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.yellow)
                        Text("Smarta sökförslag")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(SmartSearchPreset.allCases) { preset in
                            Button {
                                filterConfig = preset.config
                                Task { await performSearchAsync() }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.rawValue)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Text(preset.description)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

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
                                        await loadDiscoveryData(genre: newFilter, forceGenre: true)
                                    }
                                } label: {
                                    Text(genre)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Color.red : Color(.secondarySystemGroupedBackground))
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 0.8))
                                        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Om en specifik genre är vald: Visa genrens spel direkt här
                if let activeGenre = selectedGenreFilter {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Toppspel inom \(activeGenre)")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            Spacer()
                        }

                        if isLoadingDiscovery {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(.red)
                                Text("Hämtar \(activeGenre)-spel...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else if popularGames.isEmpty {
                            Text("Inga spel hittades för \(activeGenre).")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 20)
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
                                            onQuickAdd: { option in
                                                quickAdd(game: game, option: option)
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                } else {
                    // Om "Alla" är valt:
                    // 2. Förslag baserade på biblioteket (exkluderar redan tillagda spel)
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
                                            onQuickAdd: { option in
                                                quickAdd(game: game, option: option)
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
                            Text("Populärt just nu")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            Spacer()
                        }

                        if isLoadingDiscovery {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                        } else if popularGames.isEmpty {
                            Text("Inga populära spel hittades just nu.")
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
                                            onQuickAdd: { option in
                                                quickAdd(game: game, option: option)
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
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
    enum QuickAddOption {
        case backlog
        case playing
        case completed
        case wishlist
    }

    private func quickAdd(game: IGDBGame, option: QuickAddOption) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let available = game.platforms?.map(\.name) ?? []
        let platforms = PlatformMatcher.resolvePlatforms(availableIGDBPlatforms: available, userProfilePlatforms: profile.platforms)
        let genres = game.genres?.map(\.name) ?? []
        let normalizedRating = (game.totalRating ?? 0.0) / 20.0
        let est = game.timeToBeat?.mainStoryHours ?? game.timeToBeat?.mainExtraHours
        let inferredTypes = Game.inferPlayTypes(
            genres: genres,
            title: game.name,
            gameModes: game.gameModes?.map(\.name)
        )

        let status: PlayStatus
        let isBacklog: Bool
        let isOwned: Bool

        switch option {
        case .backlog:
            status = .notStarted
            isBacklog = true
            isOwned = true
        case .playing:
            status = .playing
            isBacklog = false
            isOwned = true
        case .completed:
            status = .completed
            isBacklog = false
            isOwned = true
        case .wishlist:
            status = .notStarted
            isBacklog = false
            isOwned = false
        }

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
            estimatedHours: est,
            isOwned: isOwned,
            playTypes: inferredTypes,
            isBacklog: isBacklog,
            lastPlayedDate: status == .playing ? Date() : nil
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

    private func performSearchAsync(loadMore: Bool = false) async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty && !filterConfig.isActive {
            await MainActor.run {
                searchResults = []
                isLoading = false
                errorMessage = nil
                currentOffset = 0
                hasMoreResults = false
            }
            return
        }

        let offset = loadMore ? currentOffset + pageSize : 0

        if loadMore {
            await MainActor.run { isLoadingMore = true }
        } else {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
                currentOffset = 0
                hasMoreResults = false
            }
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
                minRating: filterConfig.minRating,
                sortOption: filterConfig.sortOption,
                limit: pageSize,
                offset: offset
            )

            // Apply hideOwned filter in-memory
            let libraryIDs = Set(store.games.compactMap { $0.igdbID })
            let libraryTitles = Set(store.games.map { $0.title.lowercased() })
            let filtered = filterConfig.hideOwned
                ? results.filter { !libraryIDs.contains($0.id) && !libraryTitles.contains($0.name.lowercased()) }
                : results

            await MainActor.run {
                if loadMore {
                    self.searchResults.append(contentsOf: filtered)
                    self.currentOffset = offset
                } else {
                    self.searchResults = filtered
                }
                self.hasMoreResults = results.count == pageSize
                self.isLoading = false
                self.isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                if !loadMore {
                    self.errorMessage = "Kunde inte slutföra sökningen (\(error.localizedDescription))."
                }
                self.isLoading = false
                self.isLoadingMore = false
            }
        }
    }

    // MARK: - Ladda Förslag & Rekommendationer
    private func loadDiscoveryData(genre: String? = nil, forceGenre: Bool = false) async {
        await MainActor.run {
            isLoadingDiscovery = true
        }

        let targetGenre = forceGenre ? genre : (genre ?? selectedGenreFilter)
        let mappedGenre = targetGenre.flatMap(mapGenreName)
        let currentGames = store.games
        let libraryIDs = Set(currentGames.compactMap { $0.igdbID })
        let libraryTitles = Set(currentGames.map { $0.title.lowercased() })
        let userTopGenres = currentGames.flatMap(\.genres)

        do {
            async let recommendedFetch: [IGDBGame] = {
                // Bara för "Alla": hämta kurerade rekommendationer och filtrera bort spel som redan finns i biblioteket
                if targetGenre != nil { return [] }
                var counts: [String: Int] = [:]
                for g in userTopGenres where !g.isEmpty { counts[g, default: 0] += 1 }
                let top = counts.sorted { $0.value > $1.value }.prefix(3).map(\.key)
                if top.isEmpty { return [] }
                let candidates = try await IGDBService.shared.fetchRecommendations(forGenres: Array(top), limit: 35)
                let unowned = candidates.filter { !libraryIDs.contains($0.id) && !libraryTitles.contains($0.name.lowercased()) }
                return Array(unowned.shuffled().prefix(8))
            }()

            let userPlatforms = Array(profile.platforms)
            let platformIDs = TrendingFetcher.platformIDs(forFamilies: userPlatforms)

            async let popularFetch: [IGDBGame] = {
                return try await IGDBService.shared.fetchPopularGames(genre: mappedGenre, platformIDs: platformIDs, limit: 15)
            }()

            let (recommended, popular) = try await (recommendedFetch, popularFetch)
            if Task.isCancelled { return }

            await MainActor.run {
                if targetGenre == nil {
                    self.recommendedGames = recommended
                }
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
    var onQuickAdd: (AddGameView.QuickAddOption) -> Void

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
                    Section("Status") {
                        ForEach(PlayStatus.allCases) { st in
                            Button {
                                updateStatus(st, for: local)
                            } label: {
                                HStack {
                                    if local.status == st {
                                        Image(systemName: "checkmark")
                                    }
                                    Label(
                                        st.title(for: local.playTypes),
                                        systemImage: st.icon(for: local.playTypes)
                                    )
                                }
                            }
                        }
                    }

                    Section("Backlog") {
                        Button {
                            var copy = local
                            copy.isBacklog.toggle()
                            store.update(copy)
                        } label: {
                            Label(
                                local.isBacklog ? "Ta bort från Backlog" : "Lägg till i Backlog",
                                systemImage: local.isBacklog ? "archivebox.fill" : "archivebox"
                            )
                        }
                    }
                } label: {
                    StatusBadge(game: local)
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
                        Label("Lägg till som Genomspelat", systemImage: "checkmark.seal.fill")
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
        if status == .playing {
            updated.isBacklog = false
            if updated.lastPlayedDate == nil {
                updated.lastPlayedDate = Date()
            }
        }
        store.update(updated)
    }
}
