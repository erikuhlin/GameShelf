//
//  ActivityView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var showingProfileSheet = false

    private var games: [Game] {
        store.games
    }

    // MARK: - Beräknad statistik

    /// Spel som faktiskt ägs (exklusive önskelista)
    private var libraryGames: [Game] {
        games.filter { $0.isOwned }
    }

    /// Totalt antal spel
    private var totalGamesCount: Int {
        libraryGames.count
    }

    /// Spelar nu
    private var playingGamesCount: Int {
        libraryGames.filter { $0.status == .playing }.count
    }

    /// Genomspelade
    private var completedGamesCount: Int {
        libraryGames.filter { $0.status == .completed }.count
    }

    /// Pausade
    private var pausedGamesCount: Int {
        libraryGames.filter { $0.status == .paused }.count
    }

    /// Avbrutna
    private var abandonedGamesCount: Int {
        libraryGames.filter { $0.status == .abandoned }.count
    }

    /// Inte påbörjade
    private var notStartedGamesCount: Int {
        libraryGames.filter { $0.status == .notStarted }.count
    }

    /// Backlog (räknas separat baserat på isBacklog == true)
    private var backlogGamesCount: Int {
        libraryGames.filter { $0.isBacklog }.count
    }

    /// Avklaringsgrad i procent
    private var completionRate: Int {
        let baseCount = libraryGames.count
        guard baseCount > 0 else { return 0 }
        return Int(round(Double(completedGamesCount) / Double(baseCount) * 100.0))
    }

    /// Beräknad total speltid (timmar) från avklarade och pågående spel
    private var totalEstimatedHours: Int {
        libraryGames.reduce(0) { total, game in
            guard game.status != .notStarted else { return total }
            return total + (game.estimatedHours ?? 0)
        }
    }

    /// Genomsnittligt personligt betyg (1–10)
    private var averageRating: Double? {
        let ratedGames = games.compactMap { $0.rating }.filter { $0 > 0 }
        guard !ratedGames.isEmpty else { return nil }
        let sum = ratedGames.reduce(0, +)
        return Double(sum) / Double(ratedGames.count)
    }

    /// Antal spel per status
    private var statusCounts: [(status: PlayStatus, count: Int)] {
        PlayStatus.allCases.map { st in
            (status: st, count: libraryGames.filter { $0.status == st }.count)
        }
    }

    /// Toppgenrer sorterade efter antal spel
    private var topGenres: [(name: String, count: Int, percentage: Double)] {
        var counts: [String: Int] = [:]
        for game in games {
            for genre in game.genres where !genre.isEmpty {
                counts[genre, default: 0] += 1
            }
        }
        let total = Double(max(1, games.count))
        return counts
            .map { (name: $0.key, count: $0.value, percentage: Double($0.value) / total) }
            .sorted { $0.count > $1.count }
    }

    /// Plattformsfördelning
    private var platformCounts: [(name: String, count: Int, percentage: Double)] {
        var counts: [String: Int] = [:]
        for game in games {
            for platform in game.platforms where !platform.isEmpty {
                let norm = normalizePlatformName(platform)
                counts[norm, default: 0] += 1
            }
        }
        let total = Double(max(1, games.count))
        return counts
            .map { (name: $0.key, count: $0.value, percentage: Double($0.value) / total) }
            .sorted { $0.count > $1.count }
    }

    private func normalizePlatformName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("playstation 5") || lower == "ps5" { return "PlayStation 5" }
        if lower.contains("playstation 4") || lower == "ps4" { return "PlayStation 4" }
        if lower.contains("playstation 3") || lower == "ps3" { return "PlayStation 3" }
        if lower.contains("switch") { return "Nintendo Switch" }
        if lower.contains("series x") || lower.contains("series s") || lower.contains("xbox series") { return "Xbox Series X|S" }
        if lower.contains("xbox one") { return "Xbox One" }
        if lower.contains("xbox 360") { return "Xbox 360" }
        if lower.contains("pc") || lower.contains("windows") { return "PC" }
        if lower.contains("mac") { return "Mac" }
        if lower.contains("ios") || lower.contains("iphone") || lower.contains("ipad") { return "iOS" }
        if lower.contains("android") { return "Android" }
        return name
    }

    /// Spel fördelade över lanseringsår (toppår)
    private var releaseYearCounts: [(year: String, count: Int)] {
        var counts: [Int: Int] = [:]
        for game in games where game.releaseYear > 0 {
            counts[game.releaseYear, default: 0] += 1
        }
        return counts
            .map { (year: String($0.key), count: $0.value) }
            .sorted { $0.year > $1.year }
    }

    /// Betygsfördelning (1 till 10)
    private var ratingDistribution: [(rating: Int, count: Int)] {
        var counts: [Int: Int] = [:]
        for game in games {
            if let r = game.rating, (1...10).contains(r) {
                counts[r, default: 0] += 1
            }
        }
        return (1...10).reversed().map { r in
            (rating: r, count: counts[r, default: 0])
        }
    }

    var isEmbedded: Bool = false

    var body: some View {
        if isEmbedded {
            contentView
        } else {
            NavigationStack {
                contentView
                    .navigationTitle("Aktivitet")
            }
        }
    }

    private var contentView: some View {
        ScrollView {
            if games.isEmpty {
                emptyStateView
            } else {
                VStack(alignment: .leading, spacing: 22) {
                    overviewCard
                    statusDistributionCard
                    genreDistributionCard
                    platformDistributionCard
                    if !releaseYearCounts.isEmpty {
                        releaseYearsCard
                    }
                    if games.contains(where: { ($0.rating ?? 0) > 0 }) {
                        ratingDistributionCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Sektioner

    /// 1. Huvud-KPI:er
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Din Gameshelf")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                kpiBox(
                    icon: "gamecontroller.fill",
                    iconColor: .blue,
                    title: "Totalt spel",
                    value: "\(totalGamesCount)",
                    subtitle: "\(libraryGames.count) i samlingen"
                )

                kpiBox(
                    icon: "clock.fill",
                    iconColor: .orange,
                    title: "Speltid",
                    value: totalEstimatedHours > 0 ? "\(totalEstimatedHours) tim" : "—",
                    subtitle: "Beräknad speltid"
                )

                kpiBox(
                    icon: "checkmark.seal.fill",
                    iconColor: .green,
                    title: "Avklarat",
                    value: "\(completionRate) %",
                    subtitle: "\(completedGamesCount) av \(libraryGames.count) spel"
                )

                kpiBox(
                    icon: "star.fill",
                    iconColor: .yellow,
                    title: "Snittbetyg",
                    value: averageRating.map { String(format: "%.1f", $0) } ?? "—",
                    subtitle: "Ditt personliga snitt"
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 2. Statusfördelning
    private var statusDistributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Statusfördelning")
                .font(.headline)
                .foregroundStyle(.primary)

            // Segmenterad visuell stapel
            if totalGamesCount > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(statusCounts.filter { $0.count > 0 }, id: \.status) { item in
                            Rectangle()
                                .fill(item.status.color)
                                .frame(width: max(4, geo.size.width * CGFloat(item.count) / CGFloat(totalGamesCount)))
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 10)
            }

            // Grid med alla statusar samt Backlog
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(statusCounts, id: \.status) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.status.defaultIcon)
                            .font(.caption.bold())
                            .foregroundStyle(item.status.color)
                            .frame(width: 18)

                        Text(item.status.defaultTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(item.count)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }

                // Egen mätare för Backlog
                HStack(spacing: 8) {
                    Image(systemName: "archivebox.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color.blue)
                        .frame(width: 18)

                    Text("Backlog")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(backlogGamesCount)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 3. Genrefördelning
    private var genreDistributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mest spelade genrer")
                .font(.headline)
                .foregroundStyle(.primary)

            if topGenres.isEmpty {
                Text("Inga genrer registrerade ännu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(topGenres.prefix(5), id: \.name) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(item.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text("\(item.count) spel")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(.tertiarySystemFill))
                                        .frame(height: 8)

                                    Capsule()
                                        .fill(Color.red.opacity(0.85))
                                        .frame(width: max(8, geo.size.width * CGFloat(item.percentage)), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 4. Plattformsfördelning
    private var platformDistributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Plattformar")
                .font(.headline)
                .foregroundStyle(.primary)

            if platformCounts.isEmpty {
                Text("Inga plattformar registrerade ännu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(platformCounts, id: \.name) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Label(item.name, systemImage: iconForPlatform(item.name))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text("\(item.count) spel")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(.tertiarySystemFill))
                                        .frame(height: 8)

                                    Capsule()
                                        .fill(Color.blue.opacity(0.85))
                                        .frame(width: max(8, geo.size.width * CGFloat(item.percentage)), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 5. Lanseringsår
    private var releaseYearsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spel per lanseringsår")
                .font(.headline)
                .foregroundStyle(.primary)

            let maxCount = Double(max(1, releaseYearCounts.map(\.count).max() ?? 1))

            VStack(spacing: 10) {
                ForEach(releaseYearCounts.prefix(6), id: \.year) { item in
                    HStack(spacing: 12) {
                        Text(item.year)
                            .font(.subheadline.weight(.medium))
                            .frame(width: 46, alignment: .leading)
                            .foregroundStyle(.primary)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(height: 8)

                                Capsule()
                                    .fill(Color.purple.opacity(0.8))
                                    .frame(width: max(8, geo.size.width * CGFloat(Double(item.count) / maxCount)), height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text("\(item.count)")
                            .font(.caption.bold())
                            .frame(width: 28, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 6. Betygsfördelning
    private var ratingDistributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Betygsfördelning")
                .font(.headline)
                .foregroundStyle(.primary)

            let ratedOnly = ratingDistribution.filter { $0.count > 0 }
            let maxRatingCount = Double(max(1, ratingDistribution.map(\.count).max() ?? 1))

            if ratedOnly.isEmpty {
                Text("Betygsätt dina spel i biblioteket för att se fördelningen här.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(ratingDistribution.filter { $0.rating >= 5 || $0.count > 0 }, id: \.rating) { item in
                        HStack(spacing: 10) {
                            HStack(spacing: 2) {
                                Text("\(item.rating)")
                                    .font(.caption.bold())
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.yellow)
                            }
                            .frame(width: 36, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(.tertiarySystemFill))
                                        .frame(height: 6)

                                    Capsule()
                                        .fill(Color.yellow.opacity(0.85))
                                        .frame(width: max(item.count > 0 ? 8 : 0, geo.size.width * CGFloat(Double(item.count) / maxRatingCount)), height: 6)
                                }
                            }
                            .frame(height: 6)

                            Text("\(item.count)")
                                .font(.caption2.bold())
                                .foregroundStyle(item.count > 0 ? .primary : .secondary)
                                .frame(width: 20, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Hjälpvyer

    private func kpiBox(icon: String, iconColor: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(iconColor)
                Spacer()
            }

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func iconForPlatform(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("playstation") || lower.contains("ps") {
            return "gamecontroller.fill"
        } else if lower.contains("xbox") {
            return "xbox.logo"
        } else if lower.contains("nintendo") || lower.contains("switch") {
            return "gamecontroller"
        } else if lower.contains("pc") || lower.contains("mac") || lower.contains("windows") {
            return "desktopcomputer"
        } else if lower.contains("ios") || lower.contains("android") || lower.contains("mobil") {
            return "iphone"
        }
        return "gamecontroller.fill"
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "Ingen statistik än",
            systemImage: "chart.bar.xaxis",
            description: Text("Lägg till spel i ditt bibliotek för att se din personliga statistik och spelvanor.")
        )
        .padding(.top, 60)
    }
}
