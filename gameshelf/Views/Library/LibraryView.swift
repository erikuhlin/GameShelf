// LibraryView.swift
// gameshelf

import SwiftUI

enum ViewStyle {
    case list
    case grid
}

// MARK: - Sorteringsalternativ
enum SortOption: String, CaseIterable, Identifiable {
    case title = "Titel (A-Ö)"
    case rating = "Högst betyg"
    case releaseYear = "Lanseringsår"

    var id: String { rawValue }
}

// MARK: - Filteralternativ
enum PlayStatusFilter: String, CaseIterable, Identifiable {
    case all = "Alla"
    case playing = "Spelar nu"
    case backlog = "Backlog"
    case paused = "Pausat"
    case completed = "Klara"
    case abandoned = "Avbrutet"
    case wishlist = "Önskelista"

    var id: String { rawValue }

    var status: PlayStatus? {
        switch self {
        case .all: return nil
        case .playing: return .playing
        case .backlog: return .backlog
        case .paused: return .paused
        case .completed: return .completed
        case .abandoned: return .abandoned
        case .wishlist: return .wishlist
        }
    }
}

// MARK: - Ägarskapsfilter
enum OwnershipFilter: String, CaseIterable, Identifiable {
    case all = "Alla spel"
    case owned = "I ägo 🎮"
    case memories = "Spelminnen 📜"

    var id: String { rawValue }
}

struct LibraryView: View {
    @EnvironmentObject var store: LibraryStore

    @State private var ownershipFilter: OwnershipFilter = .all
    @State private var selectedFilter: PlayStatusFilter = .all
    @State private var selectedSort: SortOption = .title
    @State private var viewStyle: ViewStyle = .list
    @State private var showingAddGameSheet = false
    @State private var showingCreateCollectionSheet = false
    @State private var searchText = ""
    @State private var isSearching = false

    private var filteredAndSortedGames: [Game] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.games.filter { game in
            let matchesOwnership: Bool = {
                switch ownershipFilter {
                case .all: return true
                case .owned: return game.isOwned
                case .memories: return !game.isOwned
                }
            }()
            let matchesStatus = (selectedFilter.status == nil) || (game.status == selectedFilter.status)
            let matchesSearch = query.isEmpty ||
                game.title.lowercased().contains(query) ||
                game.developers.contains(where: { $0.lowercased().contains(query) }) ||
                game.genres.contains(where: { $0.lowercased().contains(query) }) ||
                game.platforms.contains(where: { $0.lowercased().contains(query) })
            return matchesOwnership && matchesStatus && matchesSearch
        }
        .sorted { g1, g2 in
            switch selectedSort {
            case .title:
                return g1.title.localizedCaseInsensitiveCompare(g2.title) == .orderedAscending
            case .rating:
                return (g1.rating ?? 0) > (g2.rating ?? 0)
            case .releaseYear:
                return g1.releaseYear > g2.releaseYear
            }
        }
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Expanderbar sökruta
                if isSearching {
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)

                            TextField("Sök i ditt bibliotek...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.subheadline)

                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button("Avbryt") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                searchText = ""
                                isSearching = false
                            }
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Ägarskapsväljare & Statusfilter
                VStack(spacing: 6) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(OwnershipFilter.allCases) { opt in
                                let isSelected = ownershipFilter == opt
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        ownershipFilter = opt
                                    }
                                } label: {
                                    Text(opt.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.red : Color(.secondarySystemGroupedBackground))
                                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                                        .clipShape(Capsule())
                                        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                            }

                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 1, height: 20)
                                .padding(.horizontal, 4)

                            ForEach(PlayStatusFilter.allCases) { filter in
                                SelectableChip(
                                    label: filter.rawValue,
                                    isSelected: selectedFilter == filter
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedFilter = filter
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                }
                Divider()

                // Innehåll
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // --- Mina samlingar (Karusell) ---
                        collectionsSection

                        // --- Mina spel ---
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Mina spel (\(filteredAndSortedGames.count))")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 16)

                            if !filteredAndSortedGames.isEmpty {
                                if viewStyle == .list {
                                    LazyVStack(spacing: 12) {
                                        ForEach(filteredAndSortedGames) { game in
                                            NavigationLink(destination: GameDetailView(game: game)) {
                                                LibraryGameCardRow(game: game)
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    store.delete(game)
                                                } label: {
                                                    Label("Ta bort", systemImage: "trash")
                                                }
                                                Menu("Ändra status") {
                                                    ForEach(PlayStatus.allCases, id: \.self) { status in
                                                        Button {
                                                            var copy = game
                                                            copy.status = status
                                                            store.update(copy)
                                                        } label: {
                                                            Label(status.rawValue, systemImage: icon(for: status))
                                                        }
                                                    }
                                                }
                                                Menu("Samlingar") {
                                                    ForEach(store.collections) { col in
                                                        let inCol = col.gameIDs.contains(game.id)
                                                        Button {
                                                            store.toggleGame(game.id, in: col.id)
                                                        } label: {
                                                            Label(col.name, systemImage: inCol ? "checkmark.circle.fill" : "circle")
                                                        }
                                                    }
                                                    Divider()
                                                    Button {
                                                        showingCreateCollectionSheet = true
                                                    } label: {
                                                        Label("Ny samling...", systemImage: "plus")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                } else {
                                    LazyVGrid(columns: gridColumns, spacing: 16) {
                                        ForEach(filteredAndSortedGames) { game in
                                            NavigationLink(destination: GameDetailView(game: game)) {
                                                LibraryGameGridCard(game: game)
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    store.delete(game)
                                                } label: {
                                                    Label("Ta bort", systemImage: "trash")
                                                }
                                                Menu("Ändra status") {
                                                    ForEach(PlayStatus.allCases, id: \.self) { status in
                                                        Button {
                                                            var copy = game
                                                            copy.status = status
                                                            store.update(copy)
                                                        } label: {
                                                            Label(status.rawValue, systemImage: icon(for: status))
                                                        }
                                                    }
                                                }
                                                Menu("Samlingar") {
                                                    ForEach(store.collections) { col in
                                                        let inCol = col.gameIDs.contains(game.id)
                                                        Button {
                                                            store.toggleGame(game.id, in: col.id)
                                                        } label: {
                                                            Label(col.name, systemImage: inCol ? "checkmark.circle.fill" : "circle")
                                                        }
                                                    }
                                                    Divider()
                                                    Button {
                                                        showingCreateCollectionSheet = true
                                                    } label: {
                                                        Label("Ny samling...", systemImage: "plus")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 12)

                    if filteredAndSortedGames.isEmpty && store.collections.isEmpty {
                        ContentUnavailableView(
                            "Inga spel i biblioteket",
                            systemImage: "gamecontroller",
                            description: Text("Tryck på +-knappen för att lägga till spel.")
                        )
                        .padding(.top, 40)
                    }
                }
                .refreshable {
                    await store.syncWithRemote()
                }
            }
            .navigationTitle("Bibliotek")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAddGameSheet = true
                    } label: {
                        Label("Lägg till", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Sök-ikon (expanderar sökrutan)
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSearching.toggle()
                                if !isSearching {
                                    searchText = ""
                                }
                            }
                        } label: {
                            Image(systemName: isSearching ? "magnifyingglass.circle.fill" : "magnifyingglass")
                        }

                        // Växla mellan list- och gridvy
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewStyle = (viewStyle == .list) ? .grid : .list
                            }
                        } label: {
                            Image(systemName: viewStyle == .list ? "square.grid.2x2" : "list.bullet")
                        }

                        // Sorteringsmeny
                        Menu {
                            Picker("Sortera efter", selection: $selectedSort) {
                                ForEach(SortOption.allCases) { option in
                                    Label(option.rawValue, systemImage: iconForSort(option)).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddGameSheet) {
                AddGameView()
            }
            .sheet(isPresented: $showingCreateCollectionSheet) {
                CreateOrEditCollectionSheet()
            }
        }
    }

    // MARK: - Samlingskarusell
    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Mina samlingar (\(store.collections.count))")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    showingCreateCollectionSheet = true
                } label: {
                    Label("Ny", systemImage: "plus")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.horizontal, 16)

            if store.collections.isEmpty {
                Button {
                    showingCreateCollectionSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Skapa din första samling")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("Organisera dina spel efter tema, genre eller humör")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.collections) { collection in
                            NavigationLink(destination: CollectionDetailView(collection: collection)) {
                                CollectionCard(collection: collection)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.deleteCollection(collection)
                                } label: {
                                    Label("Ta bort samling", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func iconForSort(_ option: SortOption) -> String {
        switch option {
        case .title: return "textformat"
        case .rating: return "star"
        case .releaseYear: return "calendar"
        }
    }

    private func icon(for status: PlayStatus) -> String {
        status.icon
    }
}

// MARK: - Förbättrad Radvy (Kortformat i Lista)
struct LibraryGameCardRow: View {
    let game: Game

    var body: some View {
        HStack(spacing: 14) {
            CoverView(title: game.title, url: game.coverURL, corner: 8, height: 80)
                .frame(width: 60)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(game.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    StatusBadge(status: game.status)

                    if game.releaseYear > 0 {
                        Text(String(game.releaseYear))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let rating = game.rating, rating > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("\(rating)")
                        }
                        .font(.subheadline.bold())
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Ny Gridvy-kortkomponent
struct LibraryGameGridCard: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverView(title: game.title, url: game.coverURL, corner: 10, height: 180)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack {
                    StatusBadge(status: game.status)

                    Spacer()

                    if let rating = game.rating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("\(rating)")
                        }
                        .font(.caption.bold())
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
