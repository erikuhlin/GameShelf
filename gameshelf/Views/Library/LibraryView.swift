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
    case playing = "Spelar nu"
    case notStarted = "Inte påbörjat"
    case paused = "Pausat"
    case completed = "Genomspelat"
    case abandoned = "Avbrutet"

    var id: String { rawValue }

    var status: PlayStatus? {
        switch self {
        case .all: return nil
        case .playing: return .playing
        case .notStarted: return .notStarted
        case .paused: return .paused
        case .completed: return .completed
        case .abandoned: return .abandoned
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

// MARK: - Speltidsfilter (Main Story / HLTB)
enum PlaytimeFilter: String, CaseIterable, Identifiable {
    case all = "Alla speltider"
    case short = "< 5 timmar"
    case medium = "5–15 timmar"
    case long = "15–40 timmar"
    case epic = "40+ timmar"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .all: return "Speltid: Alla"
        case .short: return "< 5h"
        case .medium: return "5–15h"
        case .long: return "15–40h"
        case .epic: return "40h+"
        }
    }

    var icon: String {
        switch self {
        case .all: return "clock"
        case .short: return "bolt.fill"
        case .medium: return "target"
        case .long: return "shield.fill"
        case .epic: return "crown.fill"
        }
    }

    func matches(hours: Int?) -> Bool {
        switch self {
        case .all:
            return true
        case .short:
            guard let h = hours, h > 0 else { return false }
            return h < 5
        case .medium:
            guard let h = hours, h > 0 else { return false }
            return h >= 5 && h < 15
        case .long:
            guard let h = hours, h > 0 else { return false }
            return h >= 15 && h < 40
        case .epic:
            guard let h = hours, h > 0 else { return false }
            return h >= 40
        }
    }
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
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTab: LibrarySectionTab = .owned
    @State private var selectedStatusFilter: PlayStatusFilter = .all
    @State private var selectedSort: SortOption = .title
    @State private var showingCreateCollectionSheet = false
    @State private var showingProfileSheet = false
    @State private var searchText = ""
    @State private var selectedPlatformIDs: Set<String> = []
    @State private var selectedPlaytimeFilter: PlaytimeFilter = .all
    @State private var groupByYear: Bool = true
    @State private var collapsedYears: Set<Int> = []
    @State private var isSearching = false
    @State private var isPlayingNowCollapsed = false
    @State private var filterOnlyOnSale = false
    @ObservedObject private var priceWatcher = PriceWatcherService.shared

    // Adaptiva kolumner för Poster Grid (3 på iPhone, 5–8 på iPad)
    private var posterGridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: 135, maximum: 185), spacing: 14, alignment: .top)]
        } else {
            return [
                GridItem(.flexible(), spacing: 10, alignment: .top),
                GridItem(.flexible(), spacing: 10, alignment: .top),
                GridItem(.flexible(), spacing: 10, alignment: .top)
            ]
        }
    }

    // Adaptiva kolumner för Samlingar (2 på iPhone, 3–4 på iPad)
    private var collectionGridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 16)]
        } else {
            return [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
        }
    }

    // Aktiva spel som spelas just nu
    private var playingNowGames: [Game] {
        store.games.filter { $0.status == .playing }
    }

    // Dynamiska plattformar baserade på spelen i den aktuella fliken
    private var availablePlatforms: [LibraryPlatformFilter] {
        let currentPool: [Game] = {
            switch selectedTab {
            case .owned:
                return store.games.filter { $0.isOwned }
            case .wishlist:
                return store.games.filter { !$0.isOwned }
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
            // I ägo: Endast ägda spel
            guard game.isOwned else { return false }

            let matchesStatus = (selectedStatusFilter.status == nil) || (game.status == selectedStatusFilter.status)
            let matchesPlatform = gameMatchesSelectedPlatform(game)
            let matchesPlaytime = selectedPlaytimeFilter.matches(hours: game.estimatedHours)
            let matchesSearch = query.isEmpty ||
                game.title.lowercased().contains(query) ||
                game.title.lowercased().contains(resolvedQuery) ||
                game.developers.contains(where: { $0.lowercased().contains(query) || $0.lowercased().contains(resolvedQuery) }) ||
                game.genres.contains(where: { $0.lowercased().contains(query) || $0.lowercased().contains(resolvedQuery) }) ||
                game.platforms.contains(where: { $0.lowercased().contains(query) })
            return matchesStatus && matchesPlatform && matchesPlaytime && matchesSearch
        }
        .sorted(by: sortComparator)
    }

    // Filtrerade spel för "Önskelista"
    private var wishlistGames: [Game] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let resolvedQuery = GameAliasResolver.resolve(query: searchText.trimmingCharacters(in: .whitespacesAndNewlines)).lowercased()

        return store.games.filter { game in
            guard !game.isOwned else { return false }

            if filterOnlyOnSale {
                guard let deal = priceWatcher.deal(for: game), deal.isOnSale else {
                    return false
                }
            }

            let matchesPlatform = gameMatchesSelectedPlatform(game)
            let matchesPlaytime = selectedPlaytimeFilter.matches(hours: game.estimatedHours)
            let matchesSearch = query.isEmpty ||
                game.title.lowercased().contains(query) ||
                game.title.lowercased().contains(resolvedQuery) ||
                game.developers.contains(where: { $0.lowercased().contains(query) || $0.lowercased().contains(resolvedQuery) }) ||
                game.genres.contains(where: { $0.lowercased().contains(query) || $0.lowercased().contains(resolvedQuery) }) ||
                game.platforms.contains(where: { $0.lowercased().contains(query) })
            return matchesPlatform && matchesPlaytime && matchesSearch
        }
        .sorted(by: sortComparator)
    }

    private var wishlistOnSaleCount: Int {
        store.games.filter { !$0.isOwned && (priceWatcher.deal(for: $0)?.isOnSale == true) }.count
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

    private var currentYearGroups: [LibraryYearGroup] {
        selectedTab == .owned ? groupedOwnedGames : groupedWishlistGames
    }

    private var areAllYearsCollapsed: Bool {
        let allYears = Set(currentYearGroups.map(\.year))
        return !allYears.isEmpty && collapsedYears.isSuperset(of: allYears)
    }

    private func toggleCollapseAllYears() {
        let allYears = Set(currentYearGroups.map(\.year))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if areAllYearsCollapsed {
                collapsedYears.removeAll()
            } else {
                collapsedYears = allYears
            }
        }
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
                            ForEach(PlayStatusFilter.allCases) { filter in
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
                                                .foregroundStyle(isSelected ? Color.white : Color.teal)
                                        } else if filter == .paused {
                                            Image(systemName: "pause.fill")
                                                .font(.system(size: 7, weight: .bold))
                                                .foregroundStyle(isSelected ? Color.white : Color.orange)
                                        } else if filter == .notStarted {
                                            Circle()
                                                .strokeBorder(isSelected ? Color.white : Color.secondary, lineWidth: 1.2)
                                                .frame(width: 6, height: 6)
                                        } else if filter == .abandoned {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 7, weight: .bold))
                                                .foregroundStyle(isSelected ? Color.white : Color.secondary)
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
                .padding(.bottom, 110) // Extra marginal så sista raden scrollas helt ovanför flytande tab-baren
            }
            .refreshable {
                await profile.syncWithRemote()
                await store.syncWithRemote()
            }
        }
        .navigationTitle("Bibliotek")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingProfileSheet = true
                } label: {
                    UserAvatarView(size: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingProfileSheet) {
            NavigationStack {
                ProfileView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Klar") { showingProfileSheet = false }
                        }
                    }
            }
        }
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
            .task(id: store.games.filter { !$0.isOwned }.count) {
                let unowned = store.games.filter { !$0.isOwned }
                await priceWatcher.fetchDeals(for: unowned)
            }
        }
    }

    // MARK: - Subtoolbar Helpers
    @ViewBuilder
    private var platformFilterMenu: some View {
        if availablePlatforms.count > 1 {
            Menu {
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
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: !selectedPlatformIDs.isEmpty ? "gamecontroller.fill" : "gamecontroller")
                        .font(.system(size: 10, weight: .bold))

                    if !selectedPlatformIDs.isEmpty {
                        Text("\(selectedPlatformIDs.count)")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .background(Color.red, in: Circle())
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5.5)
                .background(!selectedPlatformIDs.isEmpty ? Color.red.opacity(0.12) : Color(.secondarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(!selectedPlatformIDs.isEmpty ? Color.red : Color.primary)
                .overlay(Capsule().stroke(!selectedPlatformIDs.isEmpty ? Color.red.opacity(0.3) : Color.white.opacity(0.12), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var playtimeFilterMenu: some View {
        Menu {
            Section("Filtrera Speltid (Main Story)") {
                ForEach(PlaytimeFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedPlaytimeFilter = filter
                        }
                    } label: {
                        Label(filter.rawValue, systemImage: selectedPlaytimeFilter == filter ? "checkmark" : filter.icon)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: selectedPlaytimeFilter != .all ? "clock.fill" : "clock")
                    .font(.system(size: 10, weight: .bold))

                if selectedPlaytimeFilter != .all {
                    Text(selectedPlaytimeFilter.shortLabel)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5.5)
            .background(selectedPlaytimeFilter != .all ? Color.red.opacity(0.12) : Color(.secondarySystemGroupedBackground), in: Capsule())
            .foregroundStyle(selectedPlaytimeFilter != .all ? Color.red : Color.primary)
            .overlay(Capsule().stroke(selectedPlaytimeFilter != .all ? Color.red.opacity(0.3) : Color.white.opacity(0.12), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var sortMenu: some View {
        Menu {
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
            HStack(spacing: 2.5) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color.red)

                Text(shortSortTitle(selectedSort))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5.5)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var collapseAllYearsButton: some View {
        if groupByYear {
            Button {
                toggleCollapseAllYears()
            } label: {
                Image(systemName: areAllYearsCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5.5)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .foregroundStyle(areAllYearsCollapsed ? Color.red : Color.secondary)
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var activeFilterChips: some View {
        if !selectedPlatformIDs.isEmpty || selectedPlaytimeFilter != .all {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if selectedPlaytimeFilter != .all {
                        HStack(spacing: 4) {
                            Image(systemName: selectedPlaytimeFilter.icon)
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(Color.red)

                            Text(selectedPlaytimeFilter.shortLabel)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedPlaytimeFilter = .all
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.red.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.25), lineWidth: 0.8))
                    }

                    ForEach(availablePlatforms.filter { selectedPlatformIDs.contains($0.id) }) { plat in
                        HStack(spacing: 4) {
                            Image(systemName: plat.icon)
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(Color.red)

                            Text(plat.name)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    togglePlatform(plat.id)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.red.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.25), lineWidth: 0.8))
                    }

                    if selectedPlatformIDs.count > 1 {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                clearPlatforms()
                            }
                        } label: {
                            Text("Rensa alla")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func subToolbar(gameCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 5) {
                if isSearching || !searchText.isEmpty {
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
                    Text("\(gameCount) spel")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Spacer(minLength: 2)

                    // 1. Sök
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isSearching = true
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10.5, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5.5)
                            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                            .foregroundStyle(Color.primary)
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)

                    // 2. Dedikerad Plattform (Kompakt ikon + badge)
                    platformFilterMenu

                    // 2b. Dedikerad Speltid (Main Story / HLTB)
                    playtimeFilterMenu

                    // 3. Årsvy vs Rutnät
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            groupByYear.toggle()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: groupByYear ? "calendar" : "square.grid.3x3.fill")
                                .font(.system(size: 9.5, weight: .bold))
                            Text(groupByYear ? "Årsvy" : "Rutnät")
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5.5)
                        .background(groupByYear ? Color.red.opacity(0.12) : Color(.secondarySystemGroupedBackground), in: Capsule())
                        .foregroundStyle(groupByYear ? Color.red : Color.primary)
                        .overlay(Capsule().stroke(groupByYear ? Color.red.opacity(0.25) : Color.white.opacity(0.12), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)

                    // 4. Fäll ihop/ut alla år i Årsvy
                    collapseAllYearsButton

                    // 5. Sortering
                    sortMenu
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)

            // Aktiva filter
            activeFilterChips
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

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isPlayingNowCollapsed.toggle()
                            }
                        } label: {
                            Image(systemName: isPlayingNowCollapsed ? "chevron.down" : "chevron.up")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(5)
                                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

                    if !isPlayingNowCollapsed {
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
            }

            // Huvudrutnät: Mina spel i ägo
            VStack(alignment: .leading, spacing: 10) {
                if !ownedGames.isEmpty || isSearching || !searchText.isEmpty {
                    subToolbar(gameCount: ownedGames.count)
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
            let totalUnownedCount = store.games.filter { !$0.isOwned }.count

            if !wishlistGames.isEmpty || isSearching || !searchText.isEmpty || filterOnlyOnSale {
                subToolbar(gameCount: wishlistGames.count)
            }

            if totalUnownedCount > 0 {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            filterOnlyOnSale.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: filterOnlyOnSale ? "flame.fill" : "flame")
                                .font(.system(size: 11, weight: .bold))
                            if wishlistOnSaleCount > 0 {
                                Text("Endast på rea (\(wishlistOnSaleCount))")
                                    .font(.caption.weight(.semibold))
                            } else {
                                Text("Endast på rea")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6.5)
                        .background(
                            filterOnlyOnSale
                                ? Color.orange.opacity(0.18)
                                : Color(.secondarySystemGroupedBackground),
                            in: Capsule()
                        )
                        .foregroundStyle(filterOnlyOnSale ? Color.orange : Color.secondary)
                        .overlay(
                            Capsule()
                                .stroke(filterOnlyOnSale ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    if priceWatcher.isLoading {
                        ProgressView()
                            .scaleEffect(0.65)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
            }

            if !wishlistGames.isEmpty {
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
            } else if filterOnlyOnSale {
                emptyState(
                    title: "Inga spel på rea just nu",
                    subtitle: "Inga av spelen på din önskelista har en aktiv rea för tillfället."
                )
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
        if game.isOwned {
            Menu("Ändra status") {
                ForEach(PlayStatus.allCases, id: \.self) { status in
                    Button {
                        var copy = game
                        copy.status = status
                        if status == .playing {
                            copy.isBacklog = false
                            if copy.lastPlayedDate == nil {
                                copy.lastPlayedDate = Date()
                            }
                        }
                        store.update(copy)
                    } label: {
                        Label(status.title(for: game.playTypes), systemImage: status.icon(for: game.playTypes))
                    }
                }
            }

            Button {
                var copy = game
                copy.isBacklog.toggle()
                store.update(copy)
            } label: {
                Label(
                    game.isBacklog ? "Ta bort från Backlog" : "Lägg till i Backlog",
                    systemImage: game.isBacklog ? "archivebox.fill" : "archivebox"
                )
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
                copy.isOwned = false
                copy.isBacklog = false
                copy.status = .notStarted
                store.update(copy)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("Flytta till önskelista", systemImage: "heart")
            }

            Divider()

            Button(role: .destructive) {
                store.delete(game)
            } label: {
                Label("Ta bort", systemImage: "trash")
            }
        } else {
            Menu("Flytta till biblioteket") {
                Button {
                    var copy = game
                    copy.isOwned = true
                    copy.isBacklog = true
                    copy.status = .notStarted
                    store.update(copy)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("Lägg i Backlog", systemImage: "archivebox.fill")
                }

                Button {
                    var copy = game
                    copy.isOwned = true
                    copy.isBacklog = false
                    copy.status = .playing
                    copy.lastPlayedDate = Date()
                    store.update(copy)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("Börja spela nu", systemImage: "play.fill")
                }

                Button {
                    var copy = game
                    copy.isOwned = true
                    copy.isBacklog = false
                    copy.status = .completed
                    copy.storyProgress = .completed
                    store.update(copy)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("Har redan klarat", systemImage: "checkmark.seal.fill")
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

            Divider()

            Button(role: .destructive) {
                store.delete(game)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("Ta bort från önskelistan", systemImage: "trash")
            }
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
        case .dateAdded: return "Datum"
        case .releaseYear: return "År"
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
        case .notStarted:
            return base.filter { $0.status == .notStarted }.count
        case .paused:
            return base.filter { $0.status == .paused }.count
        case .completed:
            return base.filter { $0.status == .completed }.count
        case .abandoned:
            return base.filter { $0.status == .abandoned }.count
        }
    }

    private func iconForStatus(_ filter: PlayStatusFilter) -> String {
        switch filter {
        case .all: return "circle.grid.2x2"
        case .playing: return "circle.fill"
        case .notStarted: return "circle"
        case .paused: return "pause.fill"
        case .completed: return "checkmark"
        case .abandoned: return "xmark"
        }
    }

    private func colorForStatus(_ filter: PlayStatusFilter) -> Color {
        switch filter {
        case .playing: return .green
        case .completed: return .teal
        case .paused: return .orange
        case .abandoned: return .gray
        case .notStarted: return Color(.systemGray)
        default: return .secondary
        }
    }
}

// MARK: - Poster Card med adaptiv höjd för iPad/iPhone
struct LibraryPosterCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let game: Game
    var showWishlistInfo: Bool = false
    var showYearBadge: Bool = false

    private var posterHeight: CGFloat {
        horizontalSizeClass == .regular ? 205 : 155
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .top) {
                CoverView(title: game.title, url: game.coverURL, corner: 10, height: posterHeight, fullWidth: true)
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

                // Badges Overlay
                HStack(alignment: .top) {
                    // Vänster badge: Årtal (döljs som standard så omslagen hålls rena)
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

                    // Höger badge: Rea (om på rea och i önskelista), Betyg eller Kommande
                    if showWishlistInfo, let deal = PriceWatcherService.shared.deal(for: game), deal.isOnSale {
                        HStack(spacing: 2) {
                            Text("🔥")
                                .font(.system(size: 7.5))
                            Text(deal.savingsFormatted)
                                .font(.system(size: 8.5, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(
                            LinearGradient(
                                colors: [Color.red, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                        .shadow(color: .red.opacity(0.4), radius: 3, x: 0, y: 1)
                    } else if let rating = game.rating, rating > 0 {
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
                .minimumScaleFactor(0.85)
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

    private var progressPercent: Int? {
        guard let p = todoProgress, p.total > 0 else { return nil }
        return Int(round(Double(p.completed) / Double(p.total) * 100))
    }

    var body: some View {
        HStack(spacing: 10) {
            CoverView(title: game.title, url: game.coverURL, corner: 8, height: 80)
                .frame(width: 60)
                .shadow(color: .black.opacity(0.15), radius: 3, y: 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    HStack(spacing: 3) {
                        Image(systemName: game.isMultiplayerOrOngoing ? "circle.fill" : "play.fill")
                            .font(.system(size: 7, weight: .bold))
                        Text(game.isMultiplayerOrOngoing ? "Aktiv" : "Spelar nu")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(Color.green)
                    .clipShape(Capsule())

                    if let platform = game.platforms.first {
                        Text(platform)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
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

                if game.isMultiplayerOrOngoing {
                    // Multiplayer / Ongoing vy
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Aktiv multiplayer")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let lastPlayed = game.lastPlayedFormatted {
                            Text(lastPlayed)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary.opacity(0.85))
                        }
                    }
                } else {
                    // Singleplayer vy: Framsteg
                    if let progress = todoProgress {
                        VStack(alignment: .leading, spacing: 2) {
                            if let pct = progressPercent {
                                Text("\(pct)% framsteg")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }

                            ProgressView(value: Double(progress.completed), total: Double(progress.total))
                                .tint(.green)
                                .scaleEffect(x: 1, y: 0.7, anchor: .center)
                        }
                    } else {
                        Text("I din aktiva rotation")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
                    StatusBadge(game: game)

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
                    StatusBadge(game: game)

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
