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

    private var resultCount: Int { filtered.count }

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
        let set = Set(store.games.map { $0.platform })
        return ["All"] + set.sorted()
    }

    private var filtered: [Game] {
        var list = store.games

        // Sök
        if !search.isEmpty {
            list = list.filter { game in
                game.title.localizedCaseInsensitiveContains(search)
                || game.platform.localizedCaseInsensitiveContains(search)
                || game.genres.joined(separator: ", ").localizedCaseInsensitiveContains(search)
            }
        }
        // Statusfilter
        if let status = selectedStatus {
            list = list.filter { $0.status == status }
        }
        // Plattformfilter
        if let platform = selectedPlatform, platform != "All" {
            list = list.filter { $0.platform == platform }
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header + layout toggle
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
                            withAnimation(.snappy) { showFilters.toggle() }
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
                        .frame(width: 140)
                    }

                    // Search
                    TextField("Search games, platform, genre", text: $search)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, Spacing.m)

                    // Filters (expandable)
                    if showFilters {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            // Status
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.s) {
                                    SelectableChip(label: "All Statuses", isSelected: selectedStatus == nil) { selectedStatus = nil }
                                    ForEach(PlayStatus.allCases) { st in
                                        SelectableChip(label: st.rawValue, isSelected: selectedStatus == st) { selectedStatus = st }
                                    }
                                }
                                .padding(.horizontal, Spacing.m)
                            }

                            // Platform
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.s) {
                                    ForEach(allPlatforms, id: \.self) { p in
                                        SelectableChip(label: p, isSelected: (selectedPlatform ?? "All") == p) {
                                            selectedPlatform = (p == "All" ? nil : p)
                                        }
                                    }
                                }
                                .padding(.horizontal, Spacing.m)
                            }

                            // Sort
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Spacing.s) {
                                    ForEach(SortOption.allCases) { opt in
                                        SelectableChip(label: "Sort: \(opt.label)", isSelected: sortOption == opt) { sortOption = opt }
                                    }
                                    if hasActiveFilters {
                                        SelectableChip(label: "Clear", isSelected: false) { clearFilters() }
                                    }
                                }
                                .padding(.horizontal, Spacing.m)
                            }
                        }
                    } else {
                        // Collapsed summary row
                        HStack(spacing: 12) {
                            Label(filterSummary, systemImage: "slider.horizontal.3")
                                .font(Typography.footnote)
                                .foregroundColor(hasActiveFilters ? .ds.textPrimary : .ds.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            if hasActiveFilters {
                                Button("Clear") { clearFilters() }
                                    .font(Typography.footnote)
                            }
                        }
                        .padding(.horizontal, Spacing.m)
                    }

                    if showGrid {
                        GridSection(games: filtered)
                            .environmentObject(store)
                    } else {
                        ShelvesSection(shelves: store.shelvesByPlatform)
                            .environmentObject(store)
                    }

                    LibraryStatsView(games: filtered)
                        .padding(.horizontal)
                }
                .padding(.bottom, Spacing.xxl)
                .animation(.snappy, value: showFilters)
                .animation(.snappy, value: selectedStatus)
                .animation(.snappy, value: selectedPlatform)
                .animation(.snappy, value: sortOption)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add Game")
                }
            }
            .sheet(isPresented: $showAdd) {
                AddGameView()
                    .environmentObject(store)
            }
            .background(Color.ds.background.ignoresSafeArea())
            .tint(.ds.brandRed)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Grid

struct GridSection: View {
    @EnvironmentObject var store: LibraryStore
    let games: [Game]

    // Stabil två–tre kolumner beroende på skärm (öka till 160 vid behov)
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: Spacing.l)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: Spacing.l) {
            ForEach(games) { game in
                NavigationLink(destination: GameDetailView(game: game)) {
                    GameCard(game: game)
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

private extension Collection where Element == Int {
    var averageOrNil: Double? {
        guard !isEmpty else { return nil }
        let total = reduce(0, +)
        return Double(total) / Double(count)
    }
}
