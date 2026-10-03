//
//  ToplistView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-10-02.
//

import SwiftUI

struct ToplistView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: LibraryStore

    @State private var items: [ToplistGameItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    // Filter
    @State private var selectedPlatform: String
    @State private var selectedGenre: String
    @State private var selectedPeriod: QuickPeriod = .all

    var onSelectGame: ((Int) -> Void)? = nil

    init(prefillGenre: String? = nil, prefillPlatform: String? = nil, onSelectGame: ((Int) -> Void)? = nil) {
        self._selectedGenre = State(initialValue: prefillGenre ?? "Alla")
        self._selectedPlatform = State(initialValue: prefillPlatform ?? "Alla")
        self.onSelectGame = onSelectGame
    }

    private let platformOptions = [
        "Alla",
        "PC (Microsoft Windows)",
        "PlayStation 5",
        "PlayStation 4",
        "Nintendo Switch",
        "Xbox Series X|S",
        "Xbox One",
        "PlayStation 2",
        "Super Nintendo Entertainment System"
    ]

    private let genreOptions = [
        "Alla",
        "Role-playing (RPG)",
        "Action",
        "Adventure",
        "Shooter",
        "Platform",
        "Strategy",
        "Puzzle",
        "Racing",
        "Fighting",
        "Indie"
    ]

    private var hasActiveFilters: Bool {
        selectedPlatform != "Alla" || selectedGenre != "Alla" || selectedPeriod != .all
    }

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Hämtar topplistan...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)
                    Text("Kunde inte ladda topplistan")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Försök igen") {
                        Task { await loadData() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("Inga spel matchade filtren")
                        .font(.headline)
                    Text("Testa att bredda urvalet eller nollställ filter.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if hasActiveFilters {
                        Button("Återställ filter") {
                            resetFilters()
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    // Header / Förklaring
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                Text("IGDB Weighted Rating")
                                    .font(.caption.bold())
                                    .foregroundStyle(.yellow)
                            }
                            Text("Topp 100 Spel genom tiderna")
                                .font(.title3.bold())
                            Text("Bayesiansk medelvärdesberäkning (m=100). Spel med tusentals röster premieras framför obskyra titlar med extremt snitt.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    // Spellista
                    Section {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            let rank = index + 1
                            toplistRow(item: item, rank: rank)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelectGame?(item.id)
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Topplistor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Plattform
                    Menu("Plattform: \(displayPlatformName(selectedPlatform))") {
                        ForEach(platformOptions, id: \.self) { p in
                            Button {
                                selectedPlatform = p
                                Task { await loadData() }
                            } label: {
                                if selectedPlatform == p {
                                    Label(displayPlatformName(p), systemImage: "checkmark")
                                } else {
                                    Text(displayPlatformName(p))
                                }
                            }
                        }
                    }

                    // Genre
                    Menu("Genre: \(selectedGenre == "Role-playing (RPG)" ? "RPG" : selectedGenre)") {
                        ForEach(genreOptions, id: \.self) { g in
                            Button {
                                selectedGenre = g
                                Task { await loadData() }
                            } label: {
                                let labelText = g == "Role-playing (RPG)" ? "RPG" : g
                                if selectedGenre == g {
                                    Label(labelText, systemImage: "checkmark")
                                } else {
                                    Text(labelText)
                                }
                            }
                        }
                    }

                    // Tidsperiod
                    Menu("Period: \(selectedPeriod.rawValue)") {
                        ForEach(QuickPeriod.allCases) { period in
                            Button {
                                selectedPeriod = period
                                Task { await loadData() }
                            } label: {
                                if selectedPeriod == period {
                                    Label(period.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(period.rawValue)
                                }
                            }
                        }
                    }

                    if hasActiveFilters {
                        Divider()
                        Button(role: .destructive) {
                            resetFilters()
                        } label: {
                            Label("Återställ filter", systemImage: "arrow.counterclockwise")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(hasActiveFilters ? .yellow : .primary)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    private func displayPlatformName(_ raw: String) -> String {
        if raw == "PC (Microsoft Windows)" { return "PC" }
        return raw
    }

    private func resetFilters() {
        selectedPlatform = "Alla"
        selectedGenre = "Alla"
        selectedPeriod = .all
        Task { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        let range = selectedPeriod.range
        do {
            let fetched = try await ToplistService.shared.fetchToplist(
                platform: selectedPlatform == "Alla" ? nil : selectedPlatform,
                genre: selectedGenre == "Alla" ? nil : selectedGenre,
                yearFrom: range.start,
                yearTo: range.end,
                limit: 100
            )
            await MainActor.run {
                self.items = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    @ViewBuilder
    private func toplistRow(item: ToplistGameItem, rank: Int) -> some View {
        HStack(spacing: 12) {
            // Rank Badge
            ZStack {
                if rank == 1 {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                    Text("1")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                } else if rank == 2 {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                    Text("2")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                } else if rank == 3 {
                    Circle()
                        .fill(Color.brown.opacity(0.2))
                    Text("3")
                        .font(.subheadline.bold())
                        .foregroundStyle(.brown)
                } else {
                    Text("#\(rank)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 32, height: 32)

            // Omslag
            AsyncImage(url: item.coverURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "gamecontroller")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 48, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    if let year = item.release_year {
                        Text("(\(String(year)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let genres = item.genres, !genres.isEmpty {
                    Text(genres.prefix(2).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if item.isLowVotes {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                        Text("Få röster (\(item.total_rating_count ?? 0))")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            Spacer()

            // Betyg och röster
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(item.formattedScore)
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                }

                if let votes = item.total_rating_count {
                    Text("\(votes) röster")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
