//
//  YearWrappedSheet.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-09-11.
//

import SwiftUI

struct YearWrappedSheet: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int
    @State private var showingShareStory = false
    @State private var shareImage: Image?
    @State private var isExporting = false

    init(initialYear: Int? = nil) {
        let currentYear = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: initialYear ?? currentYear)
    }

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        var years = Set<Int>([currentYear, currentYear - 1, currentYear - 2])
        for game in store.games {
            if let y = game.completedYear, y > 1990 {
                years.insert(y)
            } else if let d = game.completedDate {
                let y = Calendar.current.component(.year, from: d)
                years.insert(y)
            }
        }
        return Array(years).sorted(by: >)
    }

    /// Spel som klarades under det valda året
    private var yearCompletedGames: [Game] {
        store.games.filter { game in
            guard game.status == .completed else { return false }
            if let y = game.completedYear {
                return y == selectedYear
            }
            if let d = game.completedDate {
                return Calendar.current.component(.year, from: d) == selectedYear
            }
            return false
        }
    }

    /// Fallback-kandidater om inga datum finns loggade specifikt för året
    private var candidateGames: [Game] {
        if !yearCompletedGames.isEmpty {
            return yearCompletedGames
        }
        // Om användaren inte satt datum på spel, visa alla genomspelade titlar så de ändå kan kora GOTY
        return store.games.filter { $0.status == .completed }
    }

    /// Det krönta GOTY-spelet för det valda året
    private var crownedGotyGame: Game? {
        guard let gotyId = profile.getGoty(forYear: selectedYear) else { return nil }
        return store.games.first { $0.id == gotyId }
    }

    /// Total beräknad och loggad speltid för året
    private var totalYearHours: Int {
        yearCompletedGames.reduce(0) { total, game in
            let hours = max(Int(game.effectiveHoursPlayed), game.estimatedHours ?? 0)
            return total + hours
        }
    }

    /// Snittbetyg för årets genomspelade spel
    private var averageYearRating: Double? {
        let rated = yearCompletedGames.compactMap { $0.rating }.filter { $0 > 0 }
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0, +)) / Double(rated.count)
    }

    /// Toppgenre för året
    private var topGenreForYear: String? {
        var counts: [String: Int] = [:]
        for g in yearCompletedGames {
            for genre in g.genres where !genre.isEmpty {
                counts[genre, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Mest spelade plattform för året
    private var topPlatformForYear: String? {
        var counts: [String: Int] = [:]
        for g in yearCompletedGames {
            for p in g.platforms where !p.isEmpty {
                counts[p, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Årsväljare & Rubrik
                    yearSelectorHeader

                    // 2. GOTY Sektion (Krönt vinnare eller väljare)
                    gotySection

                    // 3. Spelåret i siffror (Wrapped Stats)
                    wrappedStatsSection

                    // 4. Topprankade titlar detta år
                    if !yearCompletedGames.isEmpty {
                        topRatedYearGamesSection
                    }

                    // 5. Dela-kort knapp
                    shareStoryButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Spelåret \(selectedYear)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Klar") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingShareStory) {
                YearWrappedShareView(
                    year: selectedYear,
                    goty: crownedGotyGame,
                    completedCount: yearCompletedGames.count,
                    totalHours: totalYearHours,
                    avgRating: averageYearRating,
                    topGenre: topGenreForYear,
                    topPlatform: topPlatformForYear,
                    username: profile.username.isEmpty ? "Spelare" : profile.username,
                    avatarType: profile.avatarType
                )
            }
        }
    }

    // MARK: - 1. Årsväljare
    private var yearSelectorHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SPELÅRET WRAPPED")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.amber)
                    .tracking(1.5)

                Text("Sammanfattning & GOTY")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Picker("År", selection: $selectedYear) {
                ForEach(availableYears, id: \.self) { y in
                    Text("\(y)").tag(y)
                }
            }
            .pickerStyle(.menu)
            .tint(.amber)
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            .overlay(Capsule().stroke(Color.amber.opacity(0.3), lineWidth: 1))
        }
        .padding(.top, 4)
    }

    // MARK: - 2. GOTY Sektion
    private var gotySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("👑")
                    .font(.title3)
                Text("Game of the Year \(selectedYear)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()

                if crownedGotyGame != nil {
                    Button("Byt vinnare") {
                        withAnimation {
                            profile.setGoty(gameId: nil, forYear: selectedYear)
                        }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.amber)
                }
            }

            if let goty = crownedGotyGame {
                // Det valda vinnarspelet
                crownedGotyCard(goty: goty)
            } else {
                // Ingen vald än: Väljare
                unselectedGotyPicker
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.amber.opacity(0.12), Color(.secondarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(crownedGotyGame != nil ? Color.amber.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1.5)
        )
    }

    /// Krönt GOTY Kort
    private func crownedGotyCard(goty: Game) -> some View {
        HStack(spacing: 16) {
            // Omslag med guldkrona
            ZStack(alignment: .topLeading) {
                if let url = goty.coverURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Color.zinc800
                        }
                    }
                    .frame(width: 80, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.zinc800)
                        .frame(width: 80, height: 110)
                        .overlay(Image(systemName: "gamecontroller.fill").foregroundStyle(.white.opacity(0.3)))
                }

                // Guld-tag
                Text("1:A PLATS 👑")
                    .font(.system(size: 8.5, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Color.amber, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("DITT ÅRETS SPEL \(selectedYear)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.amber)
                    .tracking(1)

                Text(goty.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let r = goty.rating, r > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.amber)
                            .font(.system(size: 11))
                        Text("\(r) / 10")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.amber)
                    }
                }

                if !goty.genres.isEmpty {
                    Text(goty.genres.prefix(2).joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Om inget GOTY är valt – visa kandidater att klicka på
    private var unselectedGotyPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Klicka på ett spel nedan för att kora din personliga vinnare för \(selectedYear):")
                .font(.caption)
                .foregroundStyle(.secondary)

            if candidateGames.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.amber)
                    Text("Inga avklarade spel loggade för \(selectedYear) än. Markera spel som 'Klar' i biblioteket för att nominera!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(candidateGames) { game in
                            Button {
                                selectGoty(game: game)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    ZStack(alignment: .topTrailing) {
                                        if let url = game.coverURL {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image.resizable().aspectRatio(contentMode: .fill)
                                                default:
                                                    Color.zinc800
                                                }
                                            }
                                            .frame(width: 90, height: 125)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        } else {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.zinc800)
                                                .frame(width: 90, height: 125)
                                                .overlay(Image(systemName: "gamecontroller").foregroundStyle(.white.opacity(0.3)))
                                        }

                                        if let r = game.rating, r > 0 {
                                            Text("★ \(r)")
                                                .font(.system(size: 9.5, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.black.opacity(0.7), in: Capsule())
                                                .padding(4)
                                        }
                                    }

                                    Text(game.title)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .frame(width: 90, alignment: .leading)

                                    Text("Välj som GOTY 👑")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.amber)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func selectGoty(game: Game) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            profile.setGoty(gameId: game.id, forYear: selectedYear)
        }
    }

    // MARK: - 3. Spelåret i siffror (Wrapped Stats)
    private var wrappedStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spelåret i siffror")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                statCard(
                    icon: "checkmark.seal.fill",
                    color: .green,
                    title: "Genomspelade",
                    value: "\(yearCompletedGames.count) spel",
                    subtitle: "under \(selectedYear)"
                )

                statCard(
                    icon: "clock.fill",
                    color: .orange,
                    title: "Speltid",
                    value: totalYearHours > 0 ? "\(totalYearHours) tim" : "—",
                    subtitle: "Main Story & loggat"
                )

                statCard(
                    icon: "star.fill",
                    color: .amber,
                    title: "Snittbetyg",
                    value: averageYearRating.map { String(format: "%.1f", $0) } ?? "—",
                    subtitle: "Betygsatta spel"
                )

                statCard(
                    icon: "gamecontroller.fill",
                    color: .blue,
                    title: "Toppgenre",
                    value: topGenreForYear ?? "—",
                    subtitle: topPlatformForYear ?? "Olika plattformar"
                )
            }

            // Årsmålskort för det valda året
            if profile.annualGamingGoal > 0 {
                let goal = profile.annualGamingGoal
                let count = yearCompletedGames.count
                let pct = min(1.0, Double(count) / Double(max(1, goal)))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("🎯 Årsmål \(selectedYear)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(count) av \(goal) spel (\(Int(pct * 100))%)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(count >= goal ? Color.green : Color.primary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.zinc800)
                            Capsule()
                                .fill(count >= goal ? Color.green : Color.red)
                                .frame(width: geo.size.width * CGFloat(pct))
                        }
                    }
                    .frame(height: 8)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statCard(icon: String, color: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption.weight(.bold))
                Spacer()
            }

            Text(value)
                .font(.title3.weight(.heavy))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 4. Topprankade titlar detta år
    private var topRatedYearGamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dina högst rankade spel \(selectedYear)")
                .font(.headline)
                .foregroundStyle(.primary)

            let topGames = yearCompletedGames
                .filter { ($0.rating ?? 0) > 0 }
                .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
                .prefix(5)

            if topGames.isEmpty {
                Text("Du har inte satt betyg på årets avklarade spel än. Sätt betyg för att se dina favoriter!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(topGames.enumerated()), id: \.element.id) { index, game in
                        HStack(spacing: 12) {
                            Text("#\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(index == 0 ? Color.amber : Color.secondary)
                                .frame(width: 24, alignment: .leading)

                            if let url = game.coverURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        Color.zinc800
                                    }
                                }
                                .frame(width: 34, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(game.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if !game.platforms.isEmpty {
                                    Text(game.platforms.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if let r = game.rating {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.amber)
                                    Text("\(r)")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.amber)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.amber.opacity(0.12), in: Capsule())
                            }
                        }
                        .padding(.vertical, 4)

                        if index < topGames.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - 5. Dela-knapp
    private var shareStoryButton: some View {
        Button {
            showingShareStory = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up.fill")
                Text("Dela ditt Spelår \(selectedYear)")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [Color.red, Color.amber], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.red.opacity(0.3), radius: 10, y: 4)
        }
        .padding(.top, 8)
    }
}

// MARK: - Story Card För Delning (9:16)
struct YearWrappedShareView: View {
    let year: Int
    let goty: Game?
    let completedCount: Int
    let totalHours: Int
    let avgRating: Double?
    let topGenre: String?
    let topPlatform: String?
    let username: String
    let avatarType: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Själva story-kortet
                storyCardContent
                    .frame(maxWidth: 340, maxHeight: 580)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: Color.black.opacity(0.5), radius: 25, y: 10)

                Spacer()

                Button("Stäng") {
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Dela Story")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var storyCardContent: some View {
        ZStack {
            // Bakgrundsgradient
            LinearGradient(
                colors: [Color(hex: "1a1306"), Color(hex: "0d0e12"), Color(hex: "17090b")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtil textur / cirkelglöd
            Circle()
                .fill(Color.amber.opacity(0.15))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(y: -120)

            VStack(spacing: 16) {
                // Header med användare och Gameshelf
                HStack {
                    HStack(spacing: 8) {
                        Text(avatarType.contains("preset:") ? "🎮" : "🕹️")
                            .font(.system(size: 16))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.1), in: Circle())
                        Text(username)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.red)
                        Text("GAMESHELF")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white.opacity(0.8))
                            .tracking(1.2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // Titel
                VStack(spacing: 4) {
                    Text("SPELÅRET \(year)")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, Color.amber], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("WRAPPED")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color.amber)
                        .tracking(4)
                }

                // GOTY Framhävning
                if let goty = goty {
                    VStack(spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            if let url = goty.coverURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        Color.zinc800
                                    }
                                }
                                .frame(width: 110, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.amber, lineWidth: 2)
                                )
                                .shadow(color: Color.amber.opacity(0.4), radius: 12, y: 4)
                            }

                            Text("👑 GOTY")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.amber, in: Capsule())
                                .offset(x: 8, y: -8)
                        }

                        Text(goty.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: 240)

                        if let r = goty.rating {
                            Text("★ \(r) / 10 Personligt Betyg")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.amber)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Spacer()

                // Statistik-ruta i botten
                VStack(spacing: 10) {
                    HStack {
                        miniStat(value: "\(completedCount)", label: "Genomspelade")
                        Divider().background(Color.white.opacity(0.1)).frame(height: 30)
                        miniStat(value: totalHours > 0 ? "\(totalHours)h" : "—", label: "Speltid")
                        Divider().background(Color.white.opacity(0.1)).frame(height: 30)
                        miniStat(value: avgRating.map { String(format: "%.1f", $0) } ?? "—", label: "Snittbetyg")
                    }

                    if let genre = topGenre {
                        Text("Favoritgenre: \(genre)")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// Helper Color extension for amber if not present
private extension Color {
    static let zinc800 = Color(red: 0.15, green: 0.15, blue: 0.18)
    static let amber = Color(red: 0.96, green: 0.62, blue: 0.04)
}
