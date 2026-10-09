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

    enum MemoryEra: String, CaseIterable, Identifiable {
        case all = "Alla"
        case retro = "90-tal & Retro"
        case y2k = "2000-talet"
        case gen7 = "PS3/360-eran"
        case modern = "Moderna"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all: return "sparkles"
            case .retro: return "arcade.stick"
            case .y2k: return "opticaldisc"
            case .gen7: return "gamecontroller"
            case .modern: return "bolt.fill"
            }
        }

        func matches(year: Int) -> Bool {
            switch self {
            case .all:
                return true
            case .retro:
                return year > 0 && year <= 1999
            case .y2k:
                return year >= 2000 && year <= 2009
            case .gen7:
                return year >= 2010 && year <= 2018
            case .modern:
                return year >= 2019
            }
        }
    }

    enum MemorySort: String, CaseIterable, Identifiable {
        case releaseDesc = "Nyast år"
        case releaseAsc = "Äldst år"
        case ratingDesc = "Högst betyg"
        case titleAsc = "Titel (A–Ö)"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .releaseDesc: return "arrow.down"
            case .releaseAsc: return "arrow.up"
            case .ratingDesc: return "star.fill"
            case .titleAsc: return "textformat"
            }
        }
    }

    @State private var selectedMode: DiaryMode = .active
    @State private var selectedYear: Int? = Calendar.current.component(.year, from: Date())
    @State private var selectedGameForDetail: Game? = nil
    @State private var selectedMemoryEra: MemoryEra = .all
    @State private var selectedMemorySort: MemorySort = .releaseDesc
    @State private var spotlightGameID: UUID? = nil

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

    private var filteredAndSortedMemoryGames: [Game] {
        let filtered = memoryGames.filter { game in
            selectedMemoryEra.matches(year: game.releaseYear)
        }

        switch selectedMemorySort {
        case .releaseDesc:
            return filtered.sorted {
                if $0.releaseYear != $1.releaseYear {
                    return $0.releaseYear > $1.releaseYear
                }
                return $0.title.localizedCompare($1.title) == .orderedAscending
            }
        case .releaseAsc:
            return filtered.sorted {
                if $0.releaseYear != $1.releaseYear {
                    return $0.releaseYear < $1.releaseYear
                }
                return $0.title.localizedCompare($1.title) == .orderedAscending
            }
        case .ratingDesc:
            return filtered.sorted {
                let r0 = $0.rating ?? 0
                let r1 = $1.rating ?? 0
                if r0 != r1 { return r0 > r1 }
                return $0.title.localizedCompare($1.title) == .orderedAscending
            }
        case .titleAsc:
            return filtered.sorted {
                $0.title.localizedCompare($1.title) == .orderedAscending
            }
        }
    }

    private func memoryCount(for era: MemoryEra) -> Int {
        if era == .all { return memoryGames.count }
        return memoryGames.filter { era.matches(year: $0.releaseYear) }.count
    }

    private var spotlightGame: Game? {
        guard !memoryGames.isEmpty else { return nil }
        if let id = spotlightGameID, let found = memoryGames.first(where: { $0.id == id }) {
            return found
        }
        let topRated = memoryGames.filter { ($0.rating ?? 0) >= 8 }
        return topRated.first ?? memoryGames.first
    }

    private func rollNextSpotlight() {
        guard memoryGames.count > 1 else { return }
        let currentID = spotlightGame?.id
        let candidates = memoryGames.filter { $0.id != currentID }
        if let chosen = candidates.randomElement() {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                spotlightGameID = chosen.id
            }
        }
    }

    private var oldestMemoryYear: Int? {
        let validYears = memoryGames.map(\.releaseYear).filter { $0 > 1970 }
        return validYears.min()
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
        VStack(alignment: .leading, spacing: 18) {
            // 1. Info & Mini-Stats Header
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("⏳")
                            Text("Spelminnen & Nostalgi")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }

                        Text("Spel du klarat tidigare i livet. Här samlas din personliga spelhistoria utan att påverka årets aktiva dagbok.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                if !memoryGames.isEmpty {
                    Divider()
                        .padding(.vertical, 2)

                    HStack(spacing: 12) {
                        statBadge(
                            icon: "archivebox.fill",
                            color: .yellow,
                            value: "\(memoryGames.count)",
                            label: "Minnen"
                        )

                        let avg = calculatedAvgRating(memoryGames)
                        statBadge(
                            icon: "star.fill",
                            color: .yellow,
                            value: avg > 0 ? String(format: "%.1f", avg) : "—",
                            label: "Snittbetyg"
                        )

                        if let oldest = oldestMemoryYear {
                            statBadge(
                                icon: "clock.arrow.circlepath",
                                color: .orange,
                                value: String(oldest),
                                label: "Äldsta spel"
                            )
                        }
                    }
                }
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
                // Tom vy när inga minnen finns
                VStack(spacing: 14) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 44))
                        .foregroundStyle(.yellow.opacity(0.7))
                        .padding(.top, 20)

                    Text("Inga spelminnen tillagda än")
                        .font(.headline)

                    Text("När du söker efter spel och markerar dem som klara utan datum läggs de till här som nostalgiska spelminnen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    NavigationLink(destination: ForYouHubView(initialTab: .nostalgia)) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Hitta dina klassiker i Nostalgi-radarn")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.yellow, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                // 2. Throwback Spotlight (Dagens nostalgi-pärla)
                if let spotlight = spotlightGame {
                    throwbackSpotlightCard(spotlight)
                        .padding(.horizontal, 16)
                }

                // 3. Epok / Era-väljare
                VStack(alignment: .leading, spacing: 8) {
                    Text("FILTRERA EFTER EPOK")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MemoryEra.allCases) { era in
                                let count = memoryCount(for: era)
                                let isSelected = selectedMemoryEra == era
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedMemoryEra = era
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: era.icon)
                                            .font(.system(size: 10, weight: .bold))
                                        Text("\(era.rawValue) (\(count))")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        isSelected ? Color.yellow.opacity(0.18) : Color(.secondarySystemGroupedBackground),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(isSelected ? Color.yellow : .secondary)
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color.yellow.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // 4. Lista med sortering
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(filteredAndSortedMemoryGames.count) spel\(selectedMemoryEra == .all ? "" : " i " + selectedMemoryEra.rawValue)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Sorteringsmeny
                        Menu {
                            ForEach(MemorySort.allCases) { sort in
                                Button {
                                    withAnimation { selectedMemorySort = sort }
                                } label: {
                                    HStack {
                                        Text(sort.rawValue)
                                        if selectedMemorySort == sort {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: selectedMemorySort.icon)
                                    .font(.caption2)
                                Text(selectedMemorySort.rawValue)
                                    .font(.caption.bold())
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                            .foregroundStyle(.yellow)
                        }
                    }
                    .padding(.horizontal, 20)

                    if filteredAndSortedMemoryGames.isEmpty {
                        VStack(spacing: 8) {
                            Text("Inga spelminnen i denna epok")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Visa alla minnen") {
                                withAnimation { selectedMemoryEra = .all }
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredAndSortedMemoryGames) { game in
                                memoryGameRow(game)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // 5. Nostalgi-radar CTA Banner längst ner
                nostalgiaRadarBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
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

    // MARK: - Throwback Spotlight & Spelminnen Komponenter
    private func throwbackSpotlightCard(_ game: Game) -> some View {
        Button {
            selectedGameForDetail = game
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .black))
                        Text("THROWBACK SPOTLIGHT")
                            .font(.system(size: 10, weight: .black))
                            .tracking(0.8)
                    }
                    .foregroundStyle(.yellow)

                    Spacer()

                    Button {
                        rollNextSpotlight()
                    } label: {
                        HStack(spacing: 4) {
                            Text("🎲")
                                .font(.system(size: 11))
                            Text("Slumpa")
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.yellow.opacity(0.15), in: Capsule())
                        .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .top, spacing: 14) {
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
                        .frame(width: 72, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.yellow.opacity(0.15))
                            .frame(width: 72, height: 100)
                            .overlay(
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.yellow)
                            )
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(game.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 6) {
                            if game.releaseYear > 0 {
                                Text(String(game.releaseYear))
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.tertiarySystemFill), in: Capsule())
                                    .foregroundStyle(.primary)
                            }

                            if let plat = game.platforms.first {
                                HStack(spacing: 3) {
                                    Image(systemName: platformIcon(for: plat))
                                        .font(.system(size: 9))
                                    Text(plat)
                                        .font(.caption2.weight(.medium))
                                }
                                .foregroundStyle(.secondary)
                            }

                            if let rating = game.rating, rating > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                    Text("\(rating)")
                                        .font(.caption2.bold())
                                }
                                .foregroundStyle(.yellow)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.15), in: Capsule())
                            }
                        }

                        if !game.genres.isEmpty {
                            Text(game.genres.prefix(2).joined(separator: " • "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Text("Ett av dina sparade spelminnen genom tiderna.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }

                    Spacer()
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var nostalgiaRadarBanner: some View {
        NavigationLink(destination: ForYouHubView(initialTab: .nostalgia)) {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .padding(10)
                    .background(Color.yellow.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Saknar du fler barndomsfavoriter? ⏳")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("Öppna Nostalgi-radarn för att hitta hyllade klassiker från dina favoritgenrer du kanske glömt att logga.")
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
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func platformIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("pc") || lower.contains("windows") { return "desktopcomputer" }
        if lower.contains("mac") { return "laptopcomputer" }
        if lower.contains("steam deck") || lower.contains("handheld") { return "gamecontroller" }
        if lower.contains("switch") || lower.contains("3ds") || lower.contains("ds") || lower.contains("game boy") { return "arcade.stick.console" }
        if lower.contains("mobil") || lower.contains("ipad") || lower.contains("ios") { return "iphone.gen3" }
        if lower.contains("vr") || lower.contains("quest") { return "visionpro" }
        if lower.contains("playstation") || lower.contains("ps") || lower.contains("xbox") { return "gamecontroller.fill" }
        if lower.contains("retro") { return "arcade.stick" }
        return "gamecontroller"
    }

    private func memoryGameRow(_ game: Game) -> some View {
        Button {
            selectedGameForDetail = game
        } label: {
            HStack(spacing: 12) {
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
                    .frame(width: 52, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.black.opacity(0.25), radius: 3, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 52, height: 70)
                        .overlay(
                            Image(systemName: "gamecontroller.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(game.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if game.releaseYear > 0 {
                            Text(String(game.releaseYear))
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                                .foregroundStyle(.primary)
                        }

                        if let plat = game.platforms.first {
                            HStack(spacing: 3) {
                                Image(systemName: platformIcon(for: plat))
                                    .font(.system(size: 9))
                                Text(plat)
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    if !game.genres.isEmpty {
                        Text(game.genres.prefix(2).joined(separator: " • "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
