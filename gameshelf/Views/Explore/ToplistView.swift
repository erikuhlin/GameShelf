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
            // Omslag med rank-overlay (Letterboxd / App Store-stil)
            AsyncImage(url: item.coverURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "gamecontroller")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 52, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                // Rank-badge overlay i hörnet
                Group {
                    if rank == 1 {
                        Text("1")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.black)
                            .frame(width: 20, height: 20)
                            .background(Color.yellow, in: RoundedRectangle(cornerRadius: 4))
                    } else if rank == 2 {
                        Text("2")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.black)
                            .frame(width: 20, height: 20)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 4))
                    } else if rank == 3 {
                        Text("3")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color(red: 0.8, green: 0.5, blue: 0.2), in: RoundedRectangle(cornerRadius: 4))
                    } else {
                        Text("#\(rank)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(3)
                .shadow(radius: 2)
            }

            // Info (Mitten)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Kompakt metadata: år • genre
                HStack(spacing: 4) {
                    if let year = item.release_year {
                        Text(String(year))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if item.release_year != nil && !(item.genres?.isEmpty ?? true) {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let genre = item.genres?.first {
                        let cleanGenre = genre == "Role-playing (RPG)" ? "RPG" : genre
                        Text(cleanGenre)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
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

            Spacer(minLength: 4)

            // Betyg och röster (Höger)
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
                    let voteText = votes >= 1000
                        ? String(format: "%.1fk", Double(votes) / 1000.0) + " röster"
                        : "\(votes) röster"
                    Text(voteText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
