//
//  CompanyGamesView.swift
//  gameshelf
//
//  Created by Antigravity on 2026-08-31.
//

import SwiftUI

struct CompanyGamesView: View {
    let companyName: String
    let role: CompanyRole
    let companyID: Int?

    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var games: [IGDBGame] = []
    @State private var company: IGDBCompany? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var selectedSort: DiscoverSortOption = .popularity
    @State private var showFullBio = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    init(companyName: String, role: CompanyRole, companyID: Int? = nil) {
        self.companyName = companyName
        self.role = role
        self.companyID = companyID
    }

    // Spel i användarens bibliotek som matchar företaget
    private var gamesInUserLibrary: [Game] {
        store.games.filter { game in
            let devMatch = game.developers.contains { $0.localizedCaseInsensitiveContains(companyName) }
            let titleMatch = games.contains { $0.id == game.igdbID || $0.name.lowercased() == game.title.lowercased() }
            return devMatch || titleMatch
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Företagsprofil / Header
                companyHeader

                // Spel i användarens bibliotek
                if !gamesInUserLibrary.isEmpty {
                    userLibrarySection
                }

                // Alla utgivningar / spel från IGDB
                allGamesSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(companyName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Header
    private var companyHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                // Logotyp eller ikon
                if let logoURL = company?.logoURL {
                    AsyncImage(url: logoURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 54, height: 54)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            defaultIcon
                        }
                    }
                } else {
                    defaultIcon
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(companyName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        // Rollbricka
                        HStack(spacing: 4) {
                            Image(systemName: role.icon)
                                .font(.system(size: 9, weight: .bold))
                            Text(role.rawValue)
                                .font(.caption2.weight(.bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.red)

                        if let year = company?.foundedYear {
                            Text("• Grundat \(year)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Beskrivning / Bio om tillgänglig
            if let desc = company?.description, !desc.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(showFullBio ? nil : 3)
                        .animation(.easeInOut(duration: 0.2), value: showFullBio)

                    if desc.count > 140 {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showFullBio.toggle()
                            }
                        } label: {
                            Text(showFullBio ? "Visa mindre" : "Läs mer")
                                .font(.caption2.bold())
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }

    private var defaultIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.15))
                .frame(width: 54, height: 54)
            Image(systemName: role.icon)
                .font(.title3)
                .foregroundStyle(Color.red)
        }
    }

    // MARK: - Spel i ditt bibliotek
    private var userLibrarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "books.vertical.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.red)
                Text("I ditt bibliotek (\(gamesInUserLibrary.count))")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(gamesInUserLibrary) { userGame in
                        NavigationLink(destination: GameDetailView(game: userGame)) {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    CoverView(title: userGame.title, url: userGame.coverURL, corner: 10, height: 135)
                                        .frame(width: 95, height: 135)
                                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                                    // Statusbricka
                                    statusBadge(for: userGame.status)
                                        .padding(5)
                                }

                                Text(userGame.title)
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if userGame.releaseYear > 0 {
                                    Text("\(userGame.releaseYear)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 95)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func statusBadge(for status: PlayStatus) -> some View {
        switch status {
        case .playing:
            Circle().fill(Color.green).frame(width: 8, height: 8)
                .padding(4).background(Color.black.opacity(0.7), in: Circle())
        case .completed:
            Image(systemName: "checkmark").font(.system(size: 7, weight: .black)).foregroundStyle(Color.yellow)
                .padding(4).background(Color.black.opacity(0.7), in: Circle())
        case .paused:
            Image(systemName: "pause.fill").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.orange)
                .padding(4).background(Color.black.opacity(0.7), in: Circle())
        case .abandoned:
            Image(systemName: "xmark").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.gray)
                .padding(4).background(Color.black.opacity(0.7), in: Circle())
        case .notStarted:
            EmptyView()
        }
    }

    // MARK: - Alla spel (IGDB)
    private var allGamesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Spel & Utgivningar")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if !games.isEmpty {
                    Text("(\(games.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Sorteringsväljare
                Menu {
                    ForEach([DiscoverSortOption.popularity, .rating, .releaseDateDesc, .releaseDateAsc]) { opt in
                        Button {
                            selectedSort = opt
                            Task { await loadGames() }
                        } label: {
                            HStack {
                                Text(opt.rawValue)
                                if selectedSort == opt {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.red)
                        Text(selectedSort.rawValue)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5.5)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                }
            }

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.red)
                        .scaleEffect(1.2)
                    Text("Hämtar spel från \(companyName)...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Försök igen") {
                        Task { await loadData() }
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if games.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Inga spel hittades för denna studio.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(games) { game in
                        NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                            gameCard(game)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func gameCard(_ game: IGDBGame) -> some View {
        let userMatch = store.games.first(where: {
            ($0.igdbID != nil && $0.igdbID == game.id) ||
            $0.title.lowercased() == game.name.lowercased()
        })

        return VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                CoverView(title: game.name, url: game.coverURL, corner: 10, height: 145)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3/4, contentMode: .fit)
                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)

                if let match = userMatch {
                    statusBadge(for: match.status)
                        .padding(5)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(game.name)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    if let year = game.releaseYear, year > 0 {
                        Text("\(year)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let rating = game.totalRating {
                        Spacer()
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating / 10.0))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        errorMessage = nil

        async let compTask = IGDBService.shared.fetchCompanyDetails(name: companyName, companyID: companyID)

        do {
            async let gamesTask = IGDBService.shared.fetchGamesForCompany(
                name: companyName,
                companyID: companyID,
                role: role,
                sortOption: selectedSort,
                limit: 60
            )

            let (fetchedComp, fetchedGames) = try await (compTask, gamesTask)
            self.company = fetchedComp
            self.games = fetchedGames
            self.isLoading = false
        } catch {
            self.company = await compTask
            self.errorMessage = "Kunde inte hämta spel: \(error.localizedDescription)"
            self.isLoading = false
        }
    }

    private func loadGames() async {
        isLoading = true
        errorMessage = nil
        do {
            self.games = try await IGDBService.shared.fetchGamesForCompany(
                name: companyName,
                companyID: companyID,
                role: role,
                sortOption: selectedSort,
                limit: 60
            )
            self.isLoading = false
        } catch {
            self.errorMessage = "Kunde inte hämta spel: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
}
