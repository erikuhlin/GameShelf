//
//  UpcomingReleasesView.swift
//  gameshelf
//
//  Created by Antigravity on 2026-08-30.
//

import SwiftUI

// MARK: - Månadsval för Releasekalendern
struct MonthOption: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date?
    let endDate: Date?
    let isMostHyped: Bool
}

// MARK: - Plattformsalternativ
struct UpcomingPlatformOption: Identifiable, Hashable {
    let id: String
    let name: String
    let igdbIDs: [Int]
    let icon: String
}

struct UpcomingReleasesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var profile: ProfileStore

    // State för data
    @State private var games: [IGDBGame] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    // Filter-state
    @State private var selectedMonthID: String = "most_hyped"
    @State private var selectedPlatformID: String = "all"
    @State private var showAllInMonth: Bool = true

    // Plattformsalternativ
    private let platforms: [UpcomingPlatformOption] = [
        UpcomingPlatformOption(id: "all", name: "Alla", igdbIDs: [], icon: "sparkles"),
        UpcomingPlatformOption(id: "ps5", name: "PS5", igdbIDs: [167], icon: "playstation.logo"),
        UpcomingPlatformOption(id: "pc", name: "PC", igdbIDs: [6], icon: "desktopcomputer"),
        UpcomingPlatformOption(id: "switch", name: "Switch", igdbIDs: [130], icon: "gamecontroller"),
        UpcomingPlatformOption(id: "xbox", name: "Xbox Series", igdbIDs: [169], icon: "xbox.logo")
    ]

    // Generera dynamiska månader för de kommande 6 månaderna med Mest Hypade först
    private var monthOptions: [MonthOption] {
        var options: [MonthOption] = []
        let cal = Calendar.current
        let now = Date()

        // 1. Startsida: Mest hypade & största kommande spelen
        options.append(MonthOption(
            id: "most_hyped",
            title: "🔥 Mest hypade",
            startDate: now,
            endDate: nil,
            isMostHyped: true
        ))

        // 2. De kommande 6 enskilda månaderna
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "MMM yyyy"

        for offset in 0..<6 {
            if let monthDate = cal.date(byAdding: .month, value: offset, to: now) {
                let comps = cal.dateComponents([.year, .month], from: monthDate)
                guard let startOfMonth = cal.date(from: comps),
                      let endOfMonth = cal.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59, second: 59), to: startOfMonth) else {
                    continue
                }
                let title = formatter.string(from: startOfMonth).capitalized
                let id = "month_\(comps.year ?? 0)_\(comps.month ?? 0)"
                options.append(MonthOption(
                    id: id,
                    title: title,
                    startDate: offset == 0 ? now : startOfMonth,
                    endDate: endOfMonth,
                    isMostHyped: false
                ))
            }
        }

        return options
    }

    private var currentOption: MonthOption? {
        monthOptions.first(where: { $0.id == selectedMonthID }) ?? monthOptions.first
    }

    private var isViewingMostHyped: Bool {
        currentOption?.isMostHyped ?? true
    }

    // Filtrerade spel: I månadsvyn visar vi alla spelsläpp så att alla datum syns i kalendern
    private var displayedGames: [IGDBGame] {
        if isViewingMostHyped || showAllInMonth || games.count <= 15 {
            return games
        }
        // Om användaren klickat på "Endast större": filtrera på hypes eller betyg
        let withHypes = games.filter { ($0.hypes ?? 0) > 0 || ($0.totalRatingCount ?? 0) > 0 }
        if !withHypes.isEmpty {
            return withHypes
        }
        return Array(games.prefix(15))
    }

    // Gruppera spelen per datum (ÅÅÅÅ-MM-DD) för tidslinjen när en specifik månad är vald
    private var groupedReleases: [(dateString: String, displayDate: String, countdown: String, games: [IGDBGame])] {
        let cal = Calendar.current
        let now = Date()

        let titleFormatter = DateFormatter()
        titleFormatter.locale = Locale(identifier: "sv_SE")
        titleFormatter.dateFormat = "EEEE d MMMM"

        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"

        var groups: [String: [IGDBGame]] = [:]
        var dateOrder: [String: Date] = [:]

        for game in displayedGames {
            guard let timestamp = game.firstReleaseDate else { continue }
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            if date > Date() && date.isYearPlaceholderDate {
                let key = game.releaseYear.map { "Kommande \($0)" } ?? "Kommande"
                groups[key, default: []].append(game)
                if dateOrder[key] == nil {
                    dateOrder[key] = date
                }
                continue
            }
            let key = keyFormatter.string(from: date)
            groups[key, default: []].append(game)
            if dateOrder[key] == nil {
                dateOrder[key] = date
            }
        }

        let sortedKeys = groups.keys.sorted { (key1, key2) in
            (dateOrder[key1] ?? now) < (dateOrder[key2] ?? now)
        }

        return sortedKeys.map { key in
            let date = dateOrder[key] ?? now
            let isPlaceholder = date.isYearPlaceholderDate
            let displayDate = isPlaceholder ? key : titleFormatter.string(from: date).capitalized

            // Beräkna nedräkning
            let countdown: String
            if isPlaceholder {
                countdown = ""
            } else {
                let daysUntil = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
                if daysUntil == 0 {
                    countdown = "Idag"
                } else if daysUntil == 1 {
                    countdown = "Imorgon"
                } else if daysUntil > 1 && daysUntil <= 30 {
                    countdown = "Om \(daysUntil) dagar"
                } else {
                    let months = max(1, daysUntil / 30)
                    countdown = "Om ca \(months) mån"
                }
            }

            return (
                dateString: key,
                displayDate: displayDate,
                countdown: countdown,
                games: groups[key] ?? []
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            customHeader

            // Horisontell Månadsväljare (med "🔥 Mest hypade" först)
            monthSelectorBar

            // Horisontell Plattformsväljare
            platformSelectorBar

            // Status-/Filterindikator (Mest hypade vs Månadens största vs Alla)
            if !games.isEmpty {
                filterModeBar
            }

            // Innehåll (Mest hypade lista / Tidslinje / Spinner / Tom-vy)
            ZStack {
                if isLoading && games.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.red)
                            .scaleEffect(1.2)
                        Text(isViewingMostHyped ? "Hämtar de mest hypade spelen..." : "Laddar kommande spelsläpp...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage, games.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.orange)
                        Text("Kunde inte hämta spelsläpp")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("Försök igen") {
                            Task { await loadReleases() }
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                        .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if displayedGames.isEmpty {
                    emptyStateView
                } else {
                    contentScrollView
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if games.isEmpty {
                Task { await loadReleases() }
            }
        }
    }

    // MARK: - 1. Custom Header
    private var customHeader: some View {
        HStack(alignment: .center) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                    Text("Tillbaka")
                        .font(.body)
                }
                .foregroundStyle(.red)
            }

            Spacer()

            VStack(spacing: 1) {
                Text("Releasekalender")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                Text(isViewingMostHyped ? "Mest efterlängtade spelen" : (currentOption?.title ?? "Kommande släpp"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Refresh knapp
            Button {
                Task { await loadReleases() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - 2. Månadssnabbväljare
    private var monthSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(monthOptions) { option in
                    let isSelected = selectedMonthID == option.id
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedMonthID = option.id
                        }
                        Task { await loadReleases() }
                    } label: {
                        Text(option.title)
                            .font(.subheadline.weight(isSelected ? .bold : .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.red : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 0.8))
                            .shadow(color: .black.opacity(isSelected ? 0.2 : 0.03), radius: 3, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 3. Plattformsväljare
    private var platformSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(platforms) { platform in
                    let isSelected = selectedPlatformID == platform.id
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedPlatformID = platform.id
                        }
                        Task { await loadReleases() }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: platform.icon)
                                .font(.caption.weight(.semibold))
                            Text(platform.name)
                                .font(.caption.weight(isSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.primary : Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(isSelected ? Color(.systemBackground) : Color.secondary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - 3.5 Filterläge (Mest hypade vs Månadens största vs Alla)
    private var filterModeBar: some View {
        HStack {
            HStack(spacing: 5) {
                if isViewingMostHyped {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.orange)
                    Text("De mest efterlängtade kommande spelen")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: showAllInMonth ? "calendar" : "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(showAllInMonth ? Color.red : Color.orange)
                    Text(showAllInMonth ? "Alla spelsläpp i kalendern (\(games.count))" : "Månadens mest efterlängtade (\(displayedGames.count) av \(games.count))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !isViewingMostHyped && games.count > 15 {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAllInMonth.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllInMonth ? "Endast större titlar" : "Visa alla (\(games.count))")
                            .font(.caption.bold())
                        Image(systemName: showAllInMonth ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - 4. Huvud-ScrollView
    private var contentScrollView: some View {
        ScrollView {
            if isViewingMostHyped {
                // Läge 1: Startsida - Mest hypade spel i rankingordning
                LazyVStack(spacing: 12) {
                    ForEach(Array(displayedGames.enumerated()), id: \.element.id) { index, game in
                        NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                            hypedGameCard(game: game, rank: index + 1)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            } else {
                // Läge 2: Månadsvy - Tidslinje dag-för-dag med "Visa alla"-knapp
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedReleases, id: \.dateString) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            // Dag-rubrik med nedräkning
                            HStack(alignment: .center, spacing: 8) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)

                                Text(group.displayDate)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(group.countdown)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red.opacity(0.12))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 4)

                            // Spelkort för denna dag
                            VStack(spacing: 10) {
                                ForEach(group.games) { game in
                                    NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                                        upcomingGameCard(game: game)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Knapp i botten för att se alla spelsläpp om användaren filtrerat
                    if !isViewingMostHyped && games.count > displayedGames.count {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showAllInMonth = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.headline)
                                Text("Visa alla \(games.count) spelsläpp i \(currentOption?.title ?? "månaden")")
                                    .font(.subheadline.bold())
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.red.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .refreshable {
            await loadReleases()
        }
    }

    // MARK: - 5. Mest Hypade Spelkort (med rank & releasedatum)
    private func hypedGameCard(game: IGDBGame, rank: Int) -> some View {
        let isWishlisted = store.games.contains(where: {
            ($0.igdbID != nil && $0.igdbID == game.id) ||
            $0.title.lowercased() == game.name.lowercased()
        })

        // Formaterat releasedatum och nedräkning
        let releaseInfo: (date: String, countdown: String) = {
            guard let ts = game.firstReleaseDate else {
                if let year = game.releaseYear, year > Calendar.current.component(.year, from: Date()) {
                    return ("Kommande \(year)", "")
                }
                return (game.releaseYear.map { "\($0)" } ?? "Kommande", "")
            }
            let date = Date(timeIntervalSince1970: TimeInterval(ts))
            if date > Date() && date.isYearPlaceholderDate {
                if let year = game.releaseYear {
                    return ("Kommande \(year)", "")
                }
                return ("Kommande", "")
            }
            let f = DateFormatter()
            f.locale = Locale(identifier: "sv_SE")
            f.dateFormat = "d MMM yyyy"
            let dateStr = f.string(from: date)

            let cal = Calendar.current
            let daysUntil = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
            let countdown: String
            if daysUntil == 0 { countdown = "Idag" }
            else if daysUntil == 1 { countdown = "Imorgon" }
            else if daysUntil > 1 && daysUntil <= 60 { countdown = "Om \(daysUntil)d" }
            else {
                let months = max(1, daysUntil / 30)
                countdown = "Om ca \(months) mån"
            }
            return (dateStr, countdown)
        }()

        return HStack(spacing: 12) {
            // Omslag med rank-bricka
            ZStack(alignment: .topLeading) {
                CoverView(title: game.name, url: game.coverURL, corner: 10, height: 105)
                    .frame(width: 76, height: 105)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                Text("#\(rank)")
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(rank <= 3 ? Color.red : Color.black.opacity(0.75))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(4)
            }

            // Spelinfo
            VStack(alignment: .leading, spacing: 5) {
                // Releasedatum & nedräkning
                HStack(spacing: 6) {
                    Text(releaseInfo.date)
                        .font(.caption.bold())
                        .foregroundStyle(.red)

                    if !releaseInfo.countdown.isEmpty {
                        Text("· \(releaseInfo.countdown)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(game.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Plattformstaggar
                if let platforms = game.platforms, !platforms.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(platforms.prefix(3), id: \.id) { plat in
                            Text(shortPlatformName(plat.name))
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                Spacer(minLength: 0)

                // Bottenrad med Hype och Önskelista
                HStack(alignment: .center) {
                    if let hypes = game.hypes, hypes > 0 {
                        HStack(spacing: 3) {
                            Text("🔥")
                                .font(.caption2)
                            Text("\(hypes) förväntan")
                                .font(.caption2.bold())
                                .foregroundStyle(.orange)
                        }
                    } else if let dev = game.developerName {
                        Text(dev)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        quickAddWishlist(game: game)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isWishlisted ? "bookmark.fill" : "plus")
                                .font(.caption.bold())
                            Text(isWishlisted ? "I önskelista" : "Önskelista")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isWishlisted ? Color.red : Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(isWishlisted ? Color.white : Color.primary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isWishlisted ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - 6. Spelkort för Månadstidslinje
    private func upcomingGameCard(game: IGDBGame) -> some View {
        let isWishlisted = store.games.contains(where: {
            ($0.igdbID != nil && $0.igdbID == game.id) ||
            $0.title.lowercased() == game.name.lowercased()
        })

        return HStack(spacing: 12) {
            // Omslag
            CoverView(title: game.name, url: game.coverURL, corner: 10, height: 95)
                .frame(width: 70, height: 95)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            // Spelinfo
            VStack(alignment: .leading, spacing: 5) {
                // Plattformstaggar
                if let platforms = game.platforms, !platforms.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(platforms.prefix(3), id: \.id) { plat in
                            Text(shortPlatformName(plat.name))
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                Text(game.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let dev = game.developerName {
                    Text(dev)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Bottenrad med Hype och Önskelista
                HStack(alignment: .center) {
                    if let hypes = game.hypes, hypes > 0 {
                        HStack(spacing: 3) {
                            Text("🔥")
                                .font(.caption2)
                            Text("\(hypes) förväntan")
                                .font(.caption2.bold())
                                .foregroundStyle(.orange)
                        }
                    } else if let genre = game.genres?.first?.name {
                        Text(genre)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        quickAddWishlist(game: game)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isWishlisted ? "bookmark.fill" : "plus")
                                .font(.caption.bold())
                            Text(isWishlisted ? "I önskelista" : "Önskelista")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isWishlisted ? Color.red : Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(isWishlisted ? Color.white : Color.primary)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isWishlisted ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - 7. Tom-tillstånd
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .padding(.top, 40)

            Text("Inga spelsläpp hittades")
                .font(.headline)

            Text("Det finns inga registrerade spelsläpp för den valda tidsperioden och plattformen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Visa alla plattformar") {
                selectedPlatformID = "all"
                Task { await loadReleases() }
            }
            .font(.subheadline.bold())
            .foregroundStyle(.red)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Snabb-lägg till i önskelistan
    private func quickAddWishlist(game: IGDBGame) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if let existing = store.games.first(where: {
            ($0.igdbID != nil && $0.igdbID == game.id) ||
            $0.title.lowercased() == game.name.lowercased()
        }) {
            var updated = existing
            updated.isOwned = false
            store.update(updated)
            return
        }

        let available = game.platforms?.map(\.name) ?? []
        let platforms = PlatformMatcher.resolvePlatforms(availableIGDBPlatforms: available)
        let genres = game.genres?.map(\.name) ?? []
        let normalizedRating = (game.totalRating ?? 0.0) / 20.0

        let newGame = Game(
            title: game.name,
            platforms: platforms,
            releaseYear: game.releaseYear ?? 0,
            genres: genres,
            developers: game.developerName.map { [$0] } ?? [],
            status: .notStarted,
            rating: 0,
            igdbRating: normalizedRating,
            coverURL: game.coverURL,
            igdbID: game.id,
            firstReleaseDate: game.firstReleaseDate,
            estimatedHours: nil,
            isOwned: false
        )

        store.add(newGame)
    }

    // MARK: - Nätverksanrop
    private func loadReleases() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        let isHyped = currentOption?.isMostHyped ?? true
        let startDate = currentOption?.startDate ?? Date()
        let endDate = currentOption?.endDate

        let selectedPlatform = platforms.first(where: { $0.id == selectedPlatformID })
        let platformIDs = selectedPlatform?.igdbIDs ?? []

        do {
            let fetched = try await IGDBService.shared.fetchUpcomingReleases(
                platformIDs: platformIDs,
                fromDate: isHyped ? Date() : startDate,
                toDate: isHyped ? nil : endDate,
                sortByHype: isHyped,
                minHype: isHyped ? 2 : nil,
                limit: isHyped ? 40 : 500
            )

            await MainActor.run {
                self.games = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func shortPlatformName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("playstation 5") || lower == "ps5" { return "PS5" }
        if lower.contains("playstation 4") || lower == "ps4" { return "PS4" }
        if lower.contains("series") { return "XSX" }
        if lower.contains("xbox") { return "Xbox" }
        if lower.contains("switch") { return "Switch" }
        if lower.contains("windows") || lower.contains("pc") { return "PC" }
        if lower.contains("mac") { return "Mac" }
        return name
    }
}
