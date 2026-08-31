// LibraryView.swift
// gameshelf

import SwiftUI

enum ViewStyle {
    case list
    case grid
}

// MARK: - Huvudsektioner i Biblioteket
enum LibrarySectionTab: String, CaseIterable, Identifiable {
    case owned = "I ägo"
    case wishlist = "Önskelista"
    case collections = "Samlingar"

    var id: String { rawValue }
}

// MARK: - Sorteringsalternativ
enum SortOption: String, CaseIterable, Identifiable {
    case dateAdded = "Senast tillagda"
    case releaseYear = "Lanseringsdatum"
    case title = "Titel (A-Ö)"
    case rating = "Högst betyg"

    var id: String { rawValue }
}

// MARK: - Filteralternativ (Kompakta namn)
enum PlayStatusFilter: String, CaseIterable, Identifiable {
    case all = "Alla"
    case playing = "Aktiv"
    case backlog = "Backlog"
    case paused = "Paus"
    case completed = "Klar"
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

// MARK: - Ägarskapsfilter (Bakåtkompatibilitet)
enum OwnershipFilter: String, CaseIterable, Identifiable {
    case all = "Alla spel"
    case owned = "I ägo 🎮"
    case memories = "Spelminnen 📜"

    var id: String { rawValue }
}

// MARK: - Filtermodeller för Plattform och Årsgruppering
struct LibraryPlatformFilter: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let count: Int
}

struct LibraryYearGroup: Identifiable {
    let year: Int
    let title: String
    let games: [Game]
    var id: String { title }
}

struct LibraryView: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: LibrarySectionTab = .owned
    @State private var selectedStatusFilter: PlayStatusFilter = .all
    @State private var selectedSort: SortOption = .title
    @State private var showingCreateCollectionSheet = false
    @State private var searchText = ""
    @State private var selectedPlatformIDs: Set<String> = []
    @State private var groupByYear: Bool = true
    @State private var collapsedYears: Set<Int> = []
    @State private var isSearching = false

    // 3 kolumner för Poster Grid med topplinjering
    private let posterGridColumns = [
        GridItem(.flexible(), spacing: 10, alignment: .top),
        GridItem(.flexible(), spacing: 10, alignment: .top),
        GridItem(.flexible(), spacing: 10, alignment: .top)
    ]

    // 2 kolumner för Samlingar
    private let collectionGridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // Aktiva spel som spelas just nu
    private var playingNowGames: [Game] {
        store.games.filter { $0.status == .playing }
    }

    // Dynamiska plattformar baserade på spelen i den aktuella fliken
    private var availablePlatforms: [LibraryPlatformFilter] {
        let currentPool: [Game] = {
            switch selectedTab {
            case .owned:
                return store.games.filter { $0.isOwned && $0.status != .wishlist }
            case .wishlist:
                return store.games.filter { $0.status == .wishlist || !$0.isOwned }
            case .collections:
                return []
            }
        }()

        var counts: [String: (name: String, icon: String, count: Int)] = [:]

        for game in currentPool {
            for platform in game.platforms {
                let lower = platform.lowercased()
                let key: String
                let displayName: String
                let icon: String

                if lower.contains("playstation 5") || lower == "ps5" {
                    key = "ps5"; displayName = "PS5"; icon = "playstation.logo"
                } else if lower.contains("playstation 4") || lower == "ps4" {
                    key = "ps4"; displayName = "PS4"; icon = "playstation.logo"
                } else if lower.contains("playstation") {
                    key = "playstation"; displayName = "PlayStation"; icon = "playstation.logo"
                } else if lower.contains("switch") || lower.contains("nintendo") {
                    key = "switch"; displayName = "Switch"; icon = "gamecontroller"
                } else if lower.contains("xbox") {
                    key = "xbox"; displayName = "Xbox"; icon = "xbox.logo"
                } else if lower.contains("pc") || lower.contains("windows") {
                    key = "pc"; displayName = "PC"; icon = "desktopcomputer"
                } else if lower.contains("mac") {
                    key = "mac"; displayName = "Mac"; icon = "laptopcomputer"
                } else {
                    key = platform.trimmingCharacters(in: .whitespacesAndNewlines)
                    displayName = key
                    icon = "gamecontroller.fill"
                }

                if let existing = counts[key] {
                    counts[key] = (existing.name, existing.icon, existing.count + 1)
                } else {
                    counts[key] = (displayName, icon, 1)
                }
            }
        }

        var options: [LibraryPlatformFilter] = [
            LibraryPlatformFilter(id: "all", name: "Alla (\(currentPool.count))", icon: "sparkles", count: currentPool.count)
        ]

        let priorityOrder = ["ps5", "switch", "pc", "xbox", "ps4", "mac", "playstation"]
        let sortedKeys = counts.keys.sorted { k1, k2 in
            let idx1 = priorityOrder.firstIndex(of: k1) ?? 999
            let idx2 = priorityOrder.firstIndex(of: k2) ?? 999
            if idx1 != idx2 { return idx1 < idx2 }
            return (counts[k1]?.count ?? 0) > (counts[k2]?.count ?? 0)
        }

        for key in sortedKeys {
            guard let item = counts[key] else { continue }
            options.append(LibraryPlatformFilter(id: key, name: "\(item.name) (\(item.count))", icon: item.icon, count: item.count))
        }

        return options
    }

    private func gameMatchesPlatform(game: Game, platformID: String) -> Bool {
        if platformID == "all" { return true }
        return game.platforms.contains { p in
            let lower = p.lowercased()
            switch platformID {
            case "ps5": return lower.contains("playstation 5") || lower == "ps5"
            case "ps4": return lower.contains("playstation 4") || lower == "ps4"
            case "playstation": return lower.contains("playstation")
            case "switch": return lower.contains("switch") || lower.contains("nintendo")
            case "xbox": return lower.contains("xbox")
            case "pc": return lower.contains("pc") || lower.contains("windows")
            case "mac": return lower.contains("mac")
            default: return p.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == platformID.lowercased()
            }
        }
    }

    private func gameMatchesSelectedPlatform(_ game: Game) -> Bool {
        if selectedPlatformIDs.isEmpty { return true }
        return selectedPlatformIDs.contains { platformID in
            gameMatchesPlatform(game: game, platformID: platformID)
        }
    }

    private var platformFilterSummary: String? {
        if selectedPlatformIDs.isEmpty { return nil }
        if selectedPlatformIDs.count == 1, let first = selectedPlatformIDs.first, let plat = availablePlatforms.first(where: { $0.id == first }) {
            return plat.name.components(separatedBy: " ").first ?? plat.name
        }
        return "\(selectedPlatformIDs.count) konsoler"
    }

    private func togglePlatform(_ id: String) {
        if selectedPlatformIDs.contains(id) {
            selectedPlatformIDs.remove(id)
        } else {
            selectedPlatformIDs.insert(id)
        }
    }

    private func removePlatform(_ id: String) {
        selectedPlatformIDs.remove(id)
    }

    private func clearPlatforms() {
        selectedPlatformIDs.removeAll()
    }

    // Filtrerade spel för "I ägo"
    private var ownedGames: [Game] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let resolvedQuery = GameAliasResolver.resolve(query: searchText.trimmingCharacters(in: .whitespacesAndNewlines)).lowercased()

        return store.games.filter { game in
            // I ägo: Exkludera wishlist och ej ägda
            guard game.isOwned && game.status != .wishlist else { return false }

            let matchesStatus = (selectedStatusFilter.status == nil) || (game.status == selectedStatusFilter.status)
            let matchesPlatform = gameMatchesSelectedPlatform(game)
            let matchesSearch = query.isEmpty ||
                game.title.lowercased().contains(query) ||
                game.title.lowercased().contains(resolvedQuery) ||
                game.developers.contains(where: { $0.lowercased().contains(query) || $0.lowercased().contains(resolvedQuery) }) ||
                game.genres.contains(where: { $0.lowercased().contains(query) || $0.lowercased().contains(resolvedQuery) }) ||
                game.platforms.contains(where: { $0.lowercased().contains(query) })
            return matchesStatus && matchesPlatform && matchesSearch
        }
        .sorted(by: sortComparator)
    }

    // Filtrerade spel för "Önskelista"
    private var wishlistGames: [Game] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let resolvedQuery = GameAliasResolver.resolve(query: searchText.trimmingCharacters(in: .whitespacesAndNewlines)).lowercased()

        return store.games.filter { game in
            guard game.status == .wishlist || !game.isOwned else { return false }

            let matchesPlatform = gameMatchesSelectedPlatform(game)
            let matchesSearch = query.isEmpty ||
                game.title.lowercased().contains(query) ||
                game.title.lowercased().contains(resolvedQuery) ||
                game.developers.contains(where: { $0.lowercased().contains(query) || $0.lowercased().contains(resolvedQuery) }) ||
                game.genres.contains(where: { $0.lowercased().contains(query) || $0.lowercased().contains(resolvedQuery) }) ||
                game.platforms.contains(where: { $0.lowercased().contains(query) })
            return matchesPlatform && matchesSearch
        }
        .sorted(by: sortComparator)
    }

    // Grupperade spel per år för tidslinjevy
    private var groupedOwnedGames: [LibraryYearGroup] {
        var groups: [Int: [Game]] = [:]
        for game in ownedGames {
            let year = game.releaseYear > 0 ? game.releaseYear : 0
            groups[year, default: []].append(game)
        }

        let sortedYears = groups.keys.filter { $0 > 0 }.sorted(by: >)
        var result = sortedYears.map { year in
            LibraryYearGroup(year: year, title: "\(year)", games: groups[year] ?? [])
        }

        if let unassigned = groups[0], !unassigned.isEmpty {
            result.append(LibraryYearGroup(year: 0, title: "Kommande / Odefinierat", games: unassigned))
        }

        return result
    }

    private var groupedWishlistGames: [LibraryYearGroup] {
        var groups: [Int: [Game]] = [:]
        for game in wishlistGames {
            let year = game.releaseYear > 0 ? game.releaseYear : 0
            groups[year, default: []].append(game)
        }

        let sortedYears = groups.keys.filter { $0 > 0 }.sorted(by: >)
        var result = sortedYears.map { year in
            LibraryYearGroup(year: year, title: "\(year)", games: groups[year] ?? [])
        }

        if let unassigned = groups[0], !unassigned.isEmpty {
            result.append(LibraryYearGroup(year: 0, title: "Kommande / Odefinierat", games: unassigned))
        }

        return result
    }

    private func sortComparator(_ g1: Game, _ g2: Game) -> Bool {
        switch selectedSort {
        case .dateAdded:
            if g1.dateAdded != g2.dateAdded {
                return g1.dateAdded > g2.dateAdded
            }
            return g1.title.localizedCaseInsensitiveCompare(g2.title) == .orderedAscending

        case .releaseYear:
            // Jämför lanseringsdatum kronologiskt fallande (nyast först)
            let date1 = releaseDateForSorting(g1)
            let date2 = releaseDateForSorting(g2)

            if let d1 = date1, let d2 = date2 {
                if d1 != d2 {
                    return d1 > d2
                }
            } else if date1 != nil {
                return true
            } else if date2 != nil {
                return false
            }

            // Fallback på titel vid identiska datum eller om båda saknar datum
            return g1.title.localizedCaseInsensitiveCompare(g2.title) == .orderedAscending

        case .title:
            return g1.title.localizedCaseInsensitiveCompare(g2.title) == .orderedAscending

        case .rating:
            let r1 = g1.rating ?? 0
            let r2 = g2.rating ?? 0
            if r1 != r2 {
                return r1 > r2
            }
            return g1.title.localizedCaseInsensitiveCompare(g2.title) == .orderedAscending
        }
    }

    private func releaseDateForSorting(_ game: Game) -> Date? {
        if let date = game.releaseDate {
            // Om det är ett platshållardatum för kommande spel (31 dec) men ett år är angivet
            if game.isUnreleased && date.isYearPlaceholderDate && game.releaseYear > 0 {
                var components = DateComponents()
                components.year = game.releaseYear
                components.month = 1
                components.day = 1
                return Calendar.current.date(from: components)
            }
            return date
        }
        if game.releaseYear > 0 {
            var components = DateComponents()
            components.year = game.releaseYear
            components.month = 1
            components.day = 1
            return Calendar.current.date(from: components)
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    // Sektion: I ägo / Önskelista / Samlingar
                Picker("Sektion", selection: $selectedTab) {
                    ForEach(LibrarySectionTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 4)

                // Statusfilter (visas för "I ägo")
                if selectedTab == .owned {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(PlayStatusFilter.allCases.filter { $0 != .wishlist }) { filter in
                                let isSelected = selectedStatusFilter == filter
                                let count = countForStatus(filter)
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        selectedStatusFilter = filter
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        if filter == .playing {
                                            Circle()
                                                .fill(isSelected ? Color.white : Color.green)
                                                .frame(width: 6, height: 6)
                                        } else if filter == .completed {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 7, weight: .bold))
                                                .foregroundStyle(isSelected ? Color.white : Color.yellow)
                                        }
                                        Text(filter == .all ? "Alla" : filter.rawValue)
                                            .font(.caption2.weight(isSelected ? .bold : .medium))
                                        if count > 0 {
                                            Text("(\(count))")
                                                .font(.caption2.weight(.medium))
                                                .opacity(isSelected ? 0.9 : 0.6)
                                        }
                                    }
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.red : Color(.secondarySystemGroupedBackground))
                                    )
                                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.8)
                                    )
                                    .shadow(color: .black.opacity(isSelected ? 0.15 : 0.02), radius: 2, y: 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 1)
                    }
                }
            }
            .padding(.bottom, 6)

            // Huvudinnehåll
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .owned:
                        ownedSection
                    case .wishlist:
                        wishlistSection
                    case .collections:
                        collectionsSection
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 56) // Extra marginal så sista raden scrollas helt ovanför flytande tab-baren
            }
            .refreshable {
                await store.syncWithRemote()
            }
        }
        .navigationTitle("Bibliotek")
        .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingCreateCollectionSheet) {
                CreateOrEditCollectionSheet()
            }
            .onAppear {
                if store.games.isEmpty {
                    Task {
                        await store.syncWithRemote()
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await store.syncWithRemote()
                    }
                }
            }
        }
    }

    // MARK: - Sektion: I ägo (Spelar nu + Poster Grid)
    @ViewBuilder
    private var ownedSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Slank "Spelar nu"-strip (visas om filter är "Alla" och man inte söker)
            if selectedStatusFilter == .all && searchText.isEmpty && !playingNowGames.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Spelar nu")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("(\(playingNowGames.count))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(playingNowGames) { game in
                                NavigationLink(destination: GameDetailView(game: game)) {
                                    PlayingNowCard(game: game)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    gameContextMenu(for: game)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }

            // Huvudrutnät: Mina spel i ägo
            VStack(alignment: .leading, spacing: 10) {
                if !ownedGames.isEmpty || isSearching || !searchText.isEmpty {
                    HStack(alignment: .center, spacing: 8) {
                        if isSearching || !searchText.isEmpty {
                            // Kompakt integrerad filtreringsremsa som tar över raden utan att ta extra vertikalt utrymme
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.red)

                                TextField("Filtrera i samlingen...", text: $searchText)
                                    .font(.subheadline)
                                    .textFieldStyle(.plain)
                                    .autocorrectionDisabled()

                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button("Klar") {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        isSearching = false
                                        searchText = ""
                                    }
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                            .overlay(Capsule().stroke(Color.red.opacity(0.35), lineWidth: 0.8))
                        } else {
                            let titleText: String = {
                                switch selectedStatusFilter {
                                case .all: return "Alla (\(ownedGames.count))"
                                case .playing: return "Spelar (\(ownedGames.count))"
                                case .backlog: return "Backlog (\(ownedGames.count))"
                                case .paused: return "Pausat (\(ownedGames.count))"
                                case .completed: return "Klart (\(ownedGames.count))"
                                case .abandoned: return "Avbrutet (\(ownedGames.count))"
                                case .wishlist: return "Önskelista (\(ownedGames.count))"
                                }
                            }()

                            Text(titleText)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            Spacer()

                            // 1. Kompakt sökknapp
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    isSearching = true
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5.5)
                                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                                    .foregroundStyle(Color.primary)
                                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)

                            // 2. Växlare för Årsvy vs Rutnät
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    groupByYear.toggle()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: groupByYear ? "calendar" : "square.grid.3x3.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(groupByYear ? "Årsvy" : "Rutnät")
                                        .font(.caption.weight(.bold))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5.5)
                                .background(groupByYear ? Color.red.opacity(0.12) : Color(.secondarySystemGroupedBackground), in: Capsule())
                                .foregroundStyle(groupByYear ? Color.red : Color.primary)
                                .overlay(Capsule().stroke(groupByYear ? Color.red.opacity(0.25) : Color.white.opacity(0.12), lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)

                            // 3. Sortera & Filtrera Plattform (Flerval med bibehållen meny!)
                            Menu {
                                if availablePlatforms.count > 1 {
                                    Section("Filtrera Plattform (Välj flera)") {
                                        Button {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                clearPlatforms()
                                            }
                                        } label: {
                                            Label("Alla plattformar", systemImage: selectedPlatformIDs.isEmpty ? "checkmark" : "")
                                        }

                                        ForEach(availablePlatforms.filter { $0.id != "all" }) { plat in
                                            let isSelected = selectedPlatformIDs.contains(plat.id)
                                            Button {
                                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                    togglePlatform(plat.id)
                                                }
                                            } label: {
                                                Label(plat.name, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                                            }
                                            .menuActionDismissBehavior(.disabled)
                                        }
                                    }
                                }

                                Section("Sortera efter") {
                                    ForEach(SortOption.allCases) { option in
                                        Button {
                                            selectedSort = option
                                        } label: {
                                            Label(option.rawValue, systemImage: iconForSort(option))
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: !selectedPlatformIDs.isEmpty ? "line.3.horizontal.decrease.circle.fill" : "arrow.up.arrow.down")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundStyle(Color.red)

                                    Text(shortSortTitle(selectedSort))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    if !selectedPlatformIDs.isEmpty {
                                        Text("\(selectedPlatformIDs.count)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 14, height: 14)
                                            .background(Color.red, in: Circle())
                                    }

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5.5)
                                .background(!selectedPlatformIDs.isEmpty ? Color.red.opacity(0.12) : Color(.secondarySystemGroupedBackground), in: Capsule())
                                .overlay(Capsule().stroke(!selectedPlatformIDs.isEmpty ? Color.red.opacity(0.3) : Color.white.opacity(0.16), lineWidth: 0.8))
                                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                }

                if !ownedGames.isEmpty {
                    if groupByYear {
                        // Årsvy med tidslinjesektioner
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(groupedOwnedGames) { group in
                                let isCollapsed = collapsedYears.contains(group.year)
                                VStack(alignment: .leading, spacing: 10) {
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            if isCollapsed {
                                                collapsedYears.remove(group.year)
                                            } else {
                                                collapsedYears.insert(group.year)
                                            }
                                        }
                                    } label: {
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text(group.title)
                                                .font(.headline.weight(.bold))
                                                .foregroundStyle(.primary)

                                            Text("• \(group.games.count) spel")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)

                                            Spacer()

                                            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.secondary)
                                                .padding(6)
                                                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    .buttonStyle(.plain)

                                    if !isCollapsed {
                                        LazyVGrid(columns: posterGridColumns, spacing: 14) {
                                            ForEach(group.games) { game in
                                                NavigationLink(destination: GameDetailView(game: game)) {
                                                    LibraryPosterCard(game: game, showYearBadge: false)
                                                }
                                                .buttonStyle(.plain)
                                                .contextMenu {
                                                    gameContextMenu(for: game)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                    } else {
                        // Platt rutnät
                        LazyVGrid(columns: posterGridColumns, spacing: 14) {
                            ForEach(ownedGames) { game in
                                NavigationLink(destination: GameDetailView(game: game)) {
                                    LibraryPosterCard(game: game, showYearBadge: true)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    gameContextMenu(for: game)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                } else {
                    emptyState(
                        title: searchText.isEmpty ? "Inga spel funna" : "Inga träffar för \"\(searchText)\"",
                        subtitle: searchText.isEmpty ? "Hitta och lägg till spel via Sök-fliken." : "Prova ett annat sökord eller ändra plattformsfilter."
                    )
                }
            }
        }
    }

    // MARK: - Sektion: Önskelista
    @ViewBuilder
    private var wishlistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !wishlistGames.isEmpty || isSearching || !searchText.isEmpty {
                HStack(alignment: .center, spacing: 8) {
                    if isSearching || !searchText.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.red)

                            TextField("Filtrera i önskelistan...", text: $searchText)
                                .font(.subheadline)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()

                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            Button("Klar") {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    isSearching = false
                                    searchText = ""
                                }
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.35), lineWidth: 0.8))
                    } else {
                        Text("Önskelista (\(wishlistGames.count))")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Spacer()

                        // 1. Kompakt sökknapp
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                isSearching = true
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5.5)
                                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                                .foregroundStyle(Color.primary)
                                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)

                        // 2. Växlare för Årsvy vs Rutnät
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                groupByYear.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: groupByYear ? "calendar" : "square.grid.3x3.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text(groupByYear ? "Årsvy" : "Rutnät")
                                    .font(.caption.weight(.bold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5.5)
                            .background(groupByYear ? Color.red.opacity(0.12) : Color(.secondarySystemGroupedBackground), in: Capsule())
                            .foregroundStyle(groupByYear ? Color.red : Color.primary)
                            .overlay(Capsule().stroke(groupByYear ? Color.red.opacity(0.25) : Color.white.opacity(0.12), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)

                        // 3. Sortera & Filtrera Plattform (Flerval)
                        Menu {
                            if availablePlatforms.count > 1 {
                                Section("Filtrera Plattform (Välj flera)") {
                                    Button {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            clearPlatforms()
                                        }
                                    } label: {
                                        Label("Alla plattformar", systemImage: selectedPlatformIDs.isEmpty ? "checkmark" : "")
                                    }

                                    ForEach(availablePlatforms.filter { $0.id != "all" }) { plat in
                                        let isSelected = selectedPlatformIDs.contains(plat.id)
                                        Button {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                togglePlatform(plat.id)
                                            }
                                        } label: {
                                            Label(plat.name, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                                        }
                                        .menuActionDismissBehavior(.disabled)
                                    }
                                }
                            }

                            Section("Sortera efter") {
                                ForEach(SortOption.allCases) { option in
                                    Button {
                                        selectedSort = option
                                    } label: {
                                        Label(option.rawValue, systemImage: iconForSort(option))
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: !selectedPlatformIDs.isEmpty ? "line.3.horizontal.decrease.circle.fill" : "arrow.up.arrow.down")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(Color.red)

                                Text(shortSortTitle(selectedSort))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if !selectedPlatformIDs.isEmpty {
                                    Text("\(selectedPlatformIDs.count)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 14, height: 14)
                                        .background(Color.red, in: Circle())
                                }

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5.5)
                            .background(!selectedPlatformIDs.isEmpty ? Color.red.opacity(0.12) : Color(.secondarySystemGroupedBackground), in: Capsule())
                            .overlay(Capsule().stroke(!selectedPlatformIDs.isEmpty ? Color.red.opacity(0.3) : Color.white.opacity(0.16), lineWidth: 0.8))
                            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)

                if groupByYear {
                    // Årsvy med tidslinjesektioner för önskelistan
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedWishlistGames) { group in
                            let isCollapsed = collapsedYears.contains(group.year)
                            VStack(alignment: .leading, spacing: 10) {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        if isCollapsed {
                                            collapsedYears.remove(group.year)
                                        } else {
                                            collapsedYears.insert(group.year)
                                        }
                                    }
                                } label: {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(group.title)
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.primary)

                                        Text("• \(group.games.count) spel")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.secondary)
                                            .padding(6)
                                            .background(Color(.secondarySystemGroupedBackground), in: Circle())
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)

                                if !isCollapsed {
                                    LazyVGrid(columns: posterGridColumns, spacing: 14) {
                                        ForEach(group.games) { game in
                                            NavigationLink(destination: GameDetailView(game: game)) {
                                                LibraryPosterCard(game: game, showWishlistInfo: true, showYearBadge: false)
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                gameContextMenu(for: game)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: posterGridColumns, spacing: 14) {
                        ForEach(wishlistGames) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                                LibraryPosterCard(game: game, showWishlistInfo: true, showYearBadge: true)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                gameContextMenu(for: game)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                emptyState(
                    title: "Önskelistan är tom",
                    subtitle: "Sök efter spel i IGDB och lägg till dem i din önskelista."
                )
            }
        }
    }

    // MARK: - Sektion: Samlingar
    @ViewBuilder
    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Mina samlingar (\(store.collections.count))")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    showingCreateCollectionSheet = true
                } label: {
                    Label("Ny samling", systemImage: "plus")
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
                LazyVGrid(columns: collectionGridColumns, spacing: 14) {
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
            }
        }
    }

    // MARK: - Context Menu för spel
    @ViewBuilder
    private func gameContextMenu(for game: Game) -> some View {
        Menu("Ändra status") {
            ForEach(PlayStatus.allCases, id: \.self) { status in
                Button {
                    var copy = game
                    copy.status = status
                    store.update(copy)
                } label: {
                    Label(status.rawValue, systemImage: status.icon)
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

        Button {
            var copy = game
            copy.isOwned.toggle()
            store.update(copy)
        } label: {
            Label(game.isOwned ? "Flytta till Spelminnen" : "Markera som i ägo", systemImage: "archivebox")
        }

        Divider()

        Button(role: .destructive) {
            store.delete(game)
        } label: {
            Label("Ta bort", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func emptyState(title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func shortSortTitle(_ sort: SortOption) -> String {
        switch sort {
        case .dateAdded: return "Tillagda"
        case .releaseYear: return "Lansering"
        case .title: return "A–Ö"
        case .rating: return "Betyg"
        }
    }

    private func iconForSort(_ option: SortOption) -> String {
        switch option {
        case .dateAdded: return "clock"
        case .releaseYear: return "calendar"
        case .title: return "textformat"
        case .rating: return "star"
        }
    }

    private func countForStatus(_ filter: PlayStatusFilter) -> Int {
        let base = store.games.filter { $0.isOwned }
        switch filter {
        case .all:
            return base.count
        case .playing:
            return base.filter { $0.status == .playing }.count
        case .backlog:
            return base.filter { $0.status == .backlog }.count
        case .paused:
            return base.filter { $0.status == .paused }.count
        case .completed:
            return base.filter { $0.status == .completed }.count
        case .abandoned:
            return base.filter { $0.status == .abandoned }.count
        case .wishlist:
            return store.games.filter { $0.status == .wishlist }.count
        }
    }

    private func iconForStatus(_ filter: PlayStatusFilter) -> String {
        switch filter {
        case .all: return "circle.grid.2x2"
        case .playing: return "circle.fill"
        case .backlog: return "clock"
        case .paused: return "pause.fill"
        case .completed: return "checkmark"
        case .abandoned: return "xmark"
        case .wishlist: return "bookmark"
        }
    }

    private func colorForStatus(_ filter: PlayStatusFilter) -> Color {
        switch filter {
        case .playing: return .green
        case .completed: return .yellow
        case .backlog: return .blue
        case .paused: return .orange
        case .abandoned: return .gray
        default: return .secondary
        }
    }
}

// MARK: - 3-Kolumners Poster Card (Koncept 2)
struct LibraryPosterCard: View {
    let game: Game
    var showWishlistInfo: Bool = false
    var showYearBadge: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .top) {
                CoverView(title: game.title, url: game.coverURL, corner: 10, height: 155, fullWidth: true)
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

                // Badges Overlay
                HStack(alignment: .top) {
                    // Vänster badge: Årtal (döljs i årsvy så det inte blir tår på tår)
                    if showYearBadge && game.releaseYear > 0 {
                        Text(String(game.releaseYear))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.38), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    }

                    Spacer(minLength: 4)

                    // Höger badge: Betyg (framhävt med guld-accent) eller Kommande
                    if let rating = game.rating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.yellow)
                            Text("\(rating)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(Color.black.opacity(0.8), in: Capsule())
                        .overlay(Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 0.5))
                    } else if showWishlistInfo && game.isUnreleased {
                        Text("Kommande")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2.5)
                            .background(Color.purple.opacity(0.85), in: Capsule())
                    }
                }
                .padding(5)
            }

            // Speltitel under omslaget - Fast minHeight så 1- och 2-rads titlar linjerar perfekt
            Text(game.title)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
        }
    }
}

// MARK: - Slank "Spelar nu"-kort för horisontell strip
struct PlayingNowCard: View {
    let game: Game

    private var todoProgress: (completed: Int, total: Int)? {
        guard !game.todos.isEmpty else { return nil }
        let done = game.todos.filter(\.isDone).count
        return (done, game.todos.count)
    }

    var body: some View {
        HStack(spacing: 10) {
            CoverView(title: game.title, url: game.coverURL, corner: 8, height: 80)
                .frame(width: 60)
                .shadow(color: .black.opacity(0.15), radius: 3, y: 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if let platform = game.platforms.first {
                        Text(platform)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(Color.green)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if let rating = game.rating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                            Text("\(rating)")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Text(game.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)

                if let progress = todoProgress {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(progress.completed) av \(progress.total) delmål")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)

                        ProgressView(value: Double(progress.completed), total: Double(progress.total))
                            .tint(.green)
                            .scaleEffect(x: 1, y: 0.7, anchor: .center)
                    }
                } else if let hours = game.estimatedHours, hours > 0 {
                    Text("~ \(hours)h uppskattat")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("I din aktiva rotation")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        }
        .padding(8)
        .frame(width: 260, height: 94)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
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
