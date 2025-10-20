//
//  LibraryView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var store: LibraryStore

    @State private var search = ""
    @State private var showGrid = true
    @AppStorage("showFilters") private var showFilters = true
    @State private var showAdd = false
    @State private var showFilterSheet = false
    @StateObject private var rawgVM = RawgSearchViewModel(api: RawgClient(), localTitles: { [] })
    @FocusState private var searchFocused: Bool
    @State private var prefillTitle: String? = nil

    // Toggle debug logs (only active in DEBUG)
    #if DEBUG
    private let debugLogs = true
    #else
    private let debugLogs = false
    #endif

    private var hasActiveFilters: Bool {
        selectedStatus != nil
        || (selectedPlatform != nil && selectedPlatform != "All")
        || sortOption != .title
    }

    private var filterSummary: String {
        var parts: [String] = []
        if let s = selectedStatus { parts.append(s.rawValue) }
        if let p = selectedPlatform { parts.append(p) }
        if sortOption != .title { parts.append("Sort: \(sortOption.label)") }
        return parts.isEmpty ? "No filters" : parts.joined(separator: " · ")
    }

    private func clearFilters() {
        selectedStatus = nil
        selectedPlatform = nil
        sortOption = .title
    }

    private var resultCount: Int {
        if search.isEmpty { return filtered.count }
        return filtered.count + rawgVM.results.count
    }

    // Filters & sorting
    @State private var selectedStatus: PlayStatus? = nil
    @State private var selectedPlatform: String? = nil
    @State private var sortOption: SortOption = .title

    private enum SortOption: String, CaseIterable, Identifiable {
        case title, year, rating
        var id: String { rawValue }
        var label: String {
            switch self {
            case .title:  return "Title"
            case .year:   return "Year"
            case .rating: return "Rating"
            }
        }
    }

    private var allPlatforms: [String] {
        let names = store.games.flatMap { $0.platforms }
        let set = Set(names)
        return ["All"] + set.sorted()
    }

    private var filtered: [Game] {
        var list = store.games

        // Sök
        if !search.isEmpty {
            list = list.filter { game in
                game.title.localizedCaseInsensitiveContains(search)
                || game.platforms.joined(separator: ", ").localizedCaseInsensitiveContains(search)
                || game.genres.joined(separator: ", ").localizedCaseInsensitiveContains(search)
            }
        }
        // Statusfilter
        if let status = selectedStatus {
            list = list.filter { $0.status == status }
        }
        // Plattformfilter
        if let platform = selectedPlatform, platform != "All" {
            list = list.filter { $0.platforms.contains(platform) }
        }
        // Sortering
        switch sortOption {
        case .title:
            list.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .year:
            list.sort { $0.releaseYear > $1.releaseYear }
        case .rating:
            list.sort { ($0.rating ?? -1) > ($1.rating ?? -1) }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                // Keep header & searchBar mounted at the same level to avoid focus loss
                headerRow
                searchBar

                if search.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            filtersSummaryRow
                            contentSection
                            LibraryStatsView(games: filtered)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, Spacing.xxl)
                    }
                } else {
                    List {
                        Section("In your library") {
                            let local = filtered
                            if local.isEmpty {
                                Text("No local matches").foregroundStyle(.secondary)
                            } else {
                                ForEach(local) { game in
                                    NavigationLink(destination: GameDetailView(game: game)) {
                                        LocalRow(game: game) { }
                                    }
                                }
                            }
                        }
                        Section("From RAWG") {
                            if rawgVM.isLoading && rawgVM.results.isEmpty {
                                HStack { Spacer(); ProgressView("Searching…"); Spacer() }
                            }
                            if !search.isEmpty && rawgVM.results.isEmpty {
                                Button {
                                    presentAddManually(prefillTitle: search)
                                } label: {
                                    Label("Add manually \"\(search)\"", systemImage: "plus")
                                }
                            }
                            ForEach(rawgVM.results) { item in
                                RawgSearchRow(
                                    item: item,
                                    added: rawgVM.isAlreadyAdded(item),
                                    onAdd: { quickAdd(item) }
                                )
                            }
                            if rawgVM.hasMore && !rawgVM.isLoading {
                                HStack { Spacer(); Button("Load more…") { rawgVM.loadMoreIfNeeded() }; Spacer() }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .onChange(of: search) {
                rawgVM.query = search
                if !search.isEmpty { searchFocused = true }
                dbg("[LibraryView] search changed:", search)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !search.isEmpty {
                        Button("Back") {
                            withAnimation { search = "" }
                            rawgVM.reset()
                            searchFocused = false
                            dbg("[LibraryView] back tapped, clearing search and resetting RAWG VM")
                        }
                    }
                }
                // No trailing menu
            }
            .sheet(isPresented: $showAdd) {
                AddGameView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(
                    selectedStatus: $selectedStatus,
                    selectedPlatform: $selectedPlatform,
                    sortOption: $sortOption,
                    allPlatforms: allPlatforms,
                    clearAction: { clearFilters() }
                )
            }
            .background(Color.ds.background.ignoresSafeArea())
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .onAppear {
                rawgVM.localTitles = { store.games.map { $0.title } }
                dbg("[LibraryView] appeared. Games:", store.games.count)
            }
        }
        .background(Color.ds.background.ignoresSafeArea())
        .tint(.ds.brandRed)
        .toolbarBackground(.hidden, for: .navigationBar)
        .containerBackground(Color.ds.background, for: .navigation)
        .transaction { t in t.disablesAnimations = true }
    }
}

private extension LibraryView {
    func presentAddManually(prefillTitle title: String? = nil) {
        prefillTitle = title
        showAdd = true
        dbg("[LibraryView] presentAddManually prefill:", title ?? "nil")
    }
    func openGame(_ game: Game) {
        // Navigation is currently handled via NavigationLink in grid/shelves.
        // Here we can push a detail view using a NavigationLink destination inside the row.
        // For simplicity, LocalRow uses onTap to open via a temporary sheet or future navigation.
        dbg("[LibraryView] openGame:", game.title)
    }

    func quickAdd(_ item: RawgGame) {
        let title = item.name
        let year = item.released.flatMap { Int($0.prefix(4)) } ?? 0
        let firstPlatform = (item.platforms ?? []).first?.platform.name
        let platforms = firstPlatform.map { [$0] } ?? []

        // Kandidater: primary, additional, första screenshot
        let candidates: [String] = [
            item.background_image,
            item.background_image_additional,
            item.short_screenshots?.first?.image
        ].compactMap { $0 }

        // Använd normalize för första fungerande URL
        let cover: URL? = {
            for s in candidates {
                if let normalized = RawgImage.normalize(from: s, width: 600) {
                    return normalized
                }
                if let original = URL(string: s) {
                    return original
                }
            }
            return nil
        }()

        let newGame = Game(
            title: title,
            platforms: platforms,
            releaseYear: year,
            genres: [],
            developers: [],
            status: .wishlist,
            rating: nil,
            rawgRating: item.rating,
            coverURL: cover
        )
        store.add(newGame)
        dbg("[LibraryView] quickAdd:", title, "year:", year, "platforms:", platforms.joined(separator: ", "), "cover:", cover?.absoluteString ?? "nil")
    }
}

private extension LibraryView {
    @ViewBuilder
    var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Library")
                    .font(Typography.h1)
                    .foregroundColor(.ds.textPrimary)
                Text("\(store.games.count) games total")
                    .font(Typography.footnote)
                    .foregroundColor(.ds.textSecondary)
            }
            Spacer()
            Button {
                showFilterSheet = true
                dbg("[LibraryView] filters tapped")
            } label: {
                HStack(spacing: 6) {
                    Label("Filters", systemImage: showFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")

                    if hasActiveFilters || !search.isEmpty {
                        Text("\(resultCount)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.ds.brandRed.opacity(0.12))
                                    .overlay(Capsule().stroke(Color.ds.brandRed, lineWidth: 1))
                            )
                            .foregroundColor(.ds.brandRed)
                            .accessibilityLabel("\(resultCount) results")
                    }
                }
            }
            Picker("Layout", selection: $showGrid) {
                Image(systemName: "square.grid.2x2").tag(true)
                Image(systemName: "rectangle.3.offgrid").tag(false)
            }
            .pickerStyle(.segmented)
            .tint(.ds.brandRed)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.ds.surface.opacity(0.3))
            )
            .frame(width: 140)
        }
    }

    @ViewBuilder
    var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search games, platform, genre", text: $search)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($searchFocused)
            if !search.isEmpty {
                Button {
                    search = ""
                    rawgVM.reset()
                    dbg("[LibraryView] clear search")
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            if search.isEmpty {
                Button { presentAddManually() } label: {
                    Image(systemName: "plus.circle.fill").imageScale(.medium)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.ds.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, Spacing.m)
    }

    @ViewBuilder
    var filtersBlock: some View { EmptyView() }

    @ViewBuilder
    var filtersSummaryRow: some View {
        HStack(spacing: 12) {
            Label(filterSummary, systemImage: "slider.horizontal.3")
                .font(Typography.footnote)
                .foregroundColor(hasActiveFilters ? .ds.textPrimary : .ds.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .onTapGesture { showFilterSheet = true }
            Spacer()
            if hasActiveFilters {
                Button("Clear") {
                    clearFilters()
                    dbg("[LibraryView] clear filters")
                }
                .font(Typography.footnote)
            }
        }
        .padding(.horizontal, Spacing.m)
    }


    private struct FilterSheet: View {
        @Binding var selectedStatus: PlayStatus?
        @Binding var selectedPlatform: String?
        @Binding var sortOption: LibraryView.SortOption
        let allPlatforms: [String]
        var clearAction: () -> Void

        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                Form {
                    Section(header: Text("Status")) {
                        Picker("Status", selection: $selectedStatus) {
                            Text("All").tag(PlayStatus?.none)
                            ForEach(PlayStatus.allCases) { st in
                                Text(st.rawValue).tag(PlayStatus?.some(st))
                            }
                        }
                    }
                    Section(header: Text("Platform")) {
                        Picker("Platform", selection: $selectedPlatform) {
                            Text("All").tag(String?.none)
                            ForEach(allPlatforms.filter { $0 != "All" }, id: \.self) { p in
                                Text(p).tag(String?.some(p))
                            }
                        }
                    }
                    Section(header: Text("Sort")) {
                        Picker("Sort by", selection: $sortOption) {
                            ForEach(LibraryView.SortOption.allCases) { opt in
                                Text(opt.label).tag(opt)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .navigationTitle("Filters")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear") { clearAction() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var contentSection: some View {
        if showGrid {
            GridSection(games: filtered)
                .environmentObject(store)
        } else {
            ShelvesSection(shelves: store.shelvesByPlatform)
                .environmentObject(store)
        }
    }
}

// MARK: - Grid

struct GridSection: View {
    @EnvironmentObject var store: LibraryStore
    let games: [Game]

    // Stabil två–tre kolumner beroende på skärm (öka till 160 vid behov)
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: Spacing.xl)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: Spacing.xl) {
            ForEach(games) { game in
                NavigationLink(destination: GameDetailView(game: game)) {
                    GameCard(game: game)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                store.delete(game)
                                // dbg in nested struct would require plumbing; keeping silent here
                            }
                        } preview: {
                            EmptyView() // ← ingen lyft/zoom
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.l)
    }
}

// MARK: - Shelves (horisontell hylla)
struct ShelvesSection: View {
    @EnvironmentObject var store: LibraryStore
    var shelves: [Shelf]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            ForEach(shelves) { shelf in
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text(shelf.title)
                        .font(.title3.bold())
                        .padding(.horizontal, Spacing.m)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.l) {
                            ForEach(shelf.games) { game in
                                NavigationLink(destination: GameDetailView(game: game)) {
                                    GameCard(game: game)
                                        .frame(width: 140)   // bara bredd – låt kortet bestämma höjd själv
                                        .contextMenu {
                                            Button("Delete", role: .destructive) {
                                                store.delete(game)
                                            }
                                        } preview: {
                                            EmptyView() // ← ingen lyft/zoom
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Spacing.m)
                    }
                }
            }
        }
    }
}

// MARK: - Search Rows
struct LocalRow: View {
    let game: Game
    var onTap: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            CoverView(title: game.title, url: game.coverURL)
                .frame(width: 52, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title).font(.headline)
                Text("\(game.platforms.first ?? "") \(game.releaseYear > 0 ? "· \(game.releaseYear)" : "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}


// MARK: - Stats
struct LibraryStatsView: View {
    let games: [Game]
    var body: some View {
        let total = games.count
        let playing = games.filter { $0.status == .playing }.count
        let completed = games.filter { $0.status == .completed }.count
        let wishlist = games.filter { $0.status == .wishlist }.count
        let avg = games.compactMap { $0.rating }.averageOrNil
        return VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Text("Total: \(total)")
                Spacer()
                Text("Playing: \(playing)")
                Spacer()
                Text("Completed: \(completed)")
                Spacer()
                Text("Wishlist: \(wishlist)")
            }
            .font(Typography.footnote)
            if let avg {
                Text("Average rating: \(String(format: "%.1f", avg))")
                    .font(Typography.footnote)
                    .foregroundColor(.ds.textSecondary)
            }
        }
    }
}

private extension LibraryView {
    func dbg(_ items: Any...) {
        #if DEBUG
        if debugLogs {
            let line = items.map { String(describing: $0) }.joined(separator: " ")
            print(line)
        }
        #endif
    }
}

private extension Collection where Element == Int {
    var averageOrNil: Double? {
        guard !isEmpty else { return nil }
        let total = reduce(0, +)
        return Double(total) / Double(count)
    }
}
