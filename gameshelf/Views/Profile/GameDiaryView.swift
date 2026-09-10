//
//  GameDiaryView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-09-10.
//

import SwiftUI

struct GameDiaryView: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var profile: ProfileStore

    enum DiaryMode: String, CaseIterable, Identifiable {
        case active = "Speldagbok"
        case memories = "Spelminnen"

        var id: String { rawValue }
    }

    @State private var selectedMode: DiaryMode = .active
    @State private var selectedYear: Int? = Calendar.current.component(.year, from: Date())
    @State private var selectedGameForDetail: Game? = nil

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    // Active completions: has completedDate
    private var activeCompletedGames: [Game] {
        store.games
            .filter { $0.status == .completed && $0.completedDate != nil }
            .sorted { ($0.completedDate ?? .distantPast) > ($1.completedDate ?? .distantPast) }
    }

    // Spelminnen: status is completed but completedDate is nil
    private var memoryGames: [Game] {
        store.games
            .filter { $0.status == .completed && $0.completedDate == nil }
            .sorted {
                if $0.releaseYear != $1.releaseYear {
                    return $0.releaseYear > $1.releaseYear
                }
                return $0.title.localizedCompare($1.title) == .orderedAscending
            }
    }

    // Years available in active diary
    private var availableYears: [Int] {
        let years = Set(activeCompletedGames.compactMap { game -> Int? in
            if let d = game.completedDate {
                return Calendar.current.component(.year, from: d)
            }
            return nil
        })
        let sorted = Array(years).sorted(by: >)
        if sorted.contains(currentYear) {
            return sorted
        } else {
            return [currentYear] + sorted
        }
    }

    // Filtered by selected year (or all years if selectedYear == nil)
    private var filteredActiveGames: [Game] {
        guard let year = selectedYear else {
            return activeCompletedGames
        }
        return activeCompletedGames.filter {
            guard let d = $0.completedDate else { return false }
            return Calendar.current.component(.year, from: d) == year
        }
    }

    // Group active games by Month-Year (e.g. "September 2026")
    private var groupedByMonth: [(monthTitle: String, games: [Game])] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "sv_SE")
        dateFormatter.dateFormat = "LLLL yyyy"

        var groups: [String: [Game]] = [:]
        var order: [String] = []

        for game in filteredActiveGames {
            guard let date = game.completedDate else { continue }
            let key = dateFormatter.string(from: date).capitalized
            if groups[key] == nil {
                groups[key] = []
                order.append(key)
            }
            groups[key]?.append(game)
        }

        return order.compactMap { key in
            guard let items = groups[key] else { return nil }
            return (monthTitle: key, games: items)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Mode switcher
                Picker("Dagboksläge", selection: $selectedMode) {
                    ForEach(DiaryMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if selectedMode == .active {
                    activeDiaryContent
                } else {
                    memoriesContent
                }
            }
            .padding(.bottom, 70)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationDestination(item: $selectedGameForDetail) { game in
            GameDetailView(game: game)
        }
    }

    // MARK: - Active Diary
    private var activeDiaryContent: some View {
        VStack(spacing: 20) {
            // Hero card / Year stats
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedYear.map { "Spelåret \($0)" } ?? "Alla genomspelningar")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)

                        Text("\(filteredActiveGames.count) spel avklarade")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Year Picker Menu
                    Menu {
                        Button {
                            selectedYear = nil
                        } label: {
                            HStack {
                                Text("Alla år")
                                if selectedYear == nil { Image(systemName: "checkmark") }
                            }
                        }

                        ForEach(availableYears, id: \.self) { yr in
                            Button {
                                selectedYear = yr
                            } label: {
                                HStack {
                                    Text("\(String(yr))")
                                    if selectedYear == yr { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedYear.map { String($0) } ?? "Alla år")
                                .font(.subheadline.bold())
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(.purple)
                    }
                }

                // Quick stats row
                if !filteredActiveGames.isEmpty {
                    HStack(spacing: 12) {
                        let avgRating = calculatedAvgRating(filteredActiveGames)
                        statBadge(
                            icon: "star.fill",
                            color: .yellow,
                            value: avgRating > 0 ? String(format: "%.1f", avgRating) : "—",
                            label: "Snittbetyg"
                        )

                        let totalHours = filteredActiveGames.reduce(0.0) { $0 + ($1.hoursPlayed ?? Double($1.estimatedHours ?? 0)) }
                        statBadge(
                            icon: "clock.fill",
                            color: .orange,
                            value: totalHours > 0 ? "\(Int(round(totalHours)))h" : "—",
                            label: "Loggad tid"
                        )
                    }
                }
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
            .padding(.horizontal, 16)

            // Chronological Timeline
            if groupedByMonth.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.top, 24)

                    Text("Inga avklarade spel loggade än")
                        .font(.headline)

                    Text("När du markerar spel som klara i ditt bibliotek med ett klardatum dyker de upp i din speldagbok här.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 24) {
                    ForEach(groupedByMonth, id: \.monthTitle) { month in
                        VStack(alignment: .leading, spacing: 12) {
                            // Month Header
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.caption.bold())
                                    .foregroundStyle(.purple)

                                Text(month.monthTitle)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text("\(month.games.count) spel")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 20)

                            // Games list for this month
                            VStack(spacing: 12) {
                                ForEach(month.games) { game in
                                    diaryGameCard(game)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Memories / Retro Content
    private var memoriesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Info Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.yellow)
                    Text("Spelminnen & Nostalgi")
                        .font(.headline)
                }

                Text("Spel du spelat och klarat tidigare i livet som du vill ha i samlingen utan att de påverkar årets speldagbok.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
            .padding(.horizontal, 16)

            if memoryGames.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.top, 24)

                    Text("Inga spelminnen tillagda")
                        .font(.headline)

                    Text("När du söker efter spel och trycker på '+ Genomspelat' läggs de till här som ett fint spelminne!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(memoryGames.count) sparade minnen")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 10) {
                        ForEach(memoryGames) { game in
                            memoryGameRow(game)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Components
    private func diaryGameCard(_ game: Game) -> some View {
        Button {
            selectedGameForDetail = game
        } label: {
            HStack(alignment: .top, spacing: 14) {
                // Cover
                if let url = game.coverURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 64, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 64, height: 86)
                        .overlay(
                            Image(systemName: "gamecontroller.fill")
                                .foregroundStyle(.purple)
                        )
                }

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text(game.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        if let rating = game.rating, rating > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                                Text("\(rating)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.yellow)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.18), in: Capsule())
                        }
                    }

                    // Metadata
                    HStack(spacing: 8) {
                        if let date = game.completedDate {
                            Text(formatDay(date))
                                .font(.caption.bold())
                                .foregroundStyle(.purple)
                        }

                        if let plat = game.platforms.first {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(plat)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    // Review Notes preview
                    if !game.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("“\(game.notes.trimmingCharacters(in: .whitespacesAndNewlines))”")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func memoryGameRow(_ game: Game) -> some View {
        Button {
            selectedGameForDetail = game
        } label: {
            HStack(spacing: 12) {
                // Mini cover
                if let url = game.coverURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: 44, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 44, height: 58)
                        .overlay(
                            Image(systemName: "gamecontroller.fill")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(game.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if game.releaseYear > 0 {
                            Text("\(String(game.releaseYear))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let plat = game.platforms.first {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(plat)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                if let rating = game.rating, rating > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text("\(rating)")
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.18), in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func statBadge(icon: String, color: Color, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }

    private func calculatedAvgRating(_ games: [Game]) -> Double {
        let rated = games.compactMap { $0.rating }.filter { $0 > 0 }
        guard !rated.isEmpty else { return 0.0 }
        return Double(rated.reduce(0, +)) / Double(rated.count)
    }
}
