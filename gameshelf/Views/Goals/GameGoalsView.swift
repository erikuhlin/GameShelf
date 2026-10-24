//
//  GameGoalsView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-10-24.
//

import SwiftUI

struct GameGoalsView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditSheet = false
    @State private var showingSelectGameSheet = false
    @State private var selectedGameForDetail: Game? = nil
    @State private var showingShareSheet = false
    @State private var dismissedSuggestionID: UUID? = nil

    private var currentYear: Int {
        GamingGoalEngine.currentYear
    }

    private var completedThisYear: Int {
        GamingGoalEngine.completedCount(in: store.games, for: currentYear)
    }

    private var completedGamesList: [Game] {
        GamingGoalEngine.completedGames(in: store.games, for: currentYear)
    }

    private var annualGoal: Int {
        max(1, profile.annualGamingGoal)
    }

    private var focusGames: [Game] {
        GamingGoalEngine.focusGames(from: store.games, targetIDs: profile.targetGameIDs)
    }

    private var tempoInfo: GameGoalTempoInfo {
        GamingGoalEngine.calculateTempo(goal: annualGoal, completed: completedThisYear, targetYear: currentYear)
    }

    private var closestGame: (game: Game, info: GameGoalProgressInfo)? {
        GamingGoalEngine.closestToFinish(from: focusGames)
    }

    private var badges: [GameGoalBadge] {
        GamingGoalEngine.badges(goal: annualGoal, completed: completedThisYear, targetYear: currentYear)
    }

    // Föreslå nästa fokusspel om det finns en ledig plats
    private var suggestedNextGame: Game? {
        guard focusGames.count < 3 else { return nil }
        let currentFocusIDs = Set(profile.targetGameIDs.map { $0.lowercased() })

        // 1. Först från Pausade
        if let paused = store.games.first(where: {
            $0.isOwned && $0.status == .paused &&
            !currentFocusIDs.contains($0.id.uuidString.lowercased()) &&
            $0.id != dismissedSuggestionID
        }) {
            return paused
        }

        // 2. Sedan från Spelar nu som inte är fokusspel
        if let playing = store.games.first(where: {
            $0.isOwned && $0.status == .playing &&
            !currentFocusIDs.contains($0.id.uuidString.lowercased()) &&
            $0.id != dismissedSuggestionID
        }) {
            return playing
        }

        // 3. Sedan från Backlog / Inte påbörjat
        if let backlog = store.games.first(where: {
            $0.isOwned && ($0.isBacklog || $0.status == .notStarted) &&
            !currentFocusIDs.contains($0.id.uuidString.lowercased()) &&
            $0.id != dismissedSuggestionID
        }) {
            return backlog
        }

        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Förslag på nästa fokusspel (om en plats nyss frigjordes)
                    if let suggestion = suggestedNextGame {
                        suggestedGameCard(suggestion)
                    }

                    // 1. Årsmålskort
                    annualGoalCard

                    // 2. Klarade spel för året (Visar vilka spel som ingår i målet!)
                    completedGamesSection

                    // 3. Närmast i mål (om något fokusspel uppfyller villkoret)
                    if let closest = closestGame {
                        closestToFinishCard(game: closest.game, info: closest.info)
                    }

                    // 4. Fokusmål (X/3)
                    focusSection

                    // 5. Märken & Milstolpar
                    badgesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Spelmål \(String(currentYear))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingEditSheet = true
                    } label: {
                        Text("Redigera")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditGameGoalsSheet()
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingSelectGameSheet) {
                SelectFocusGameSheet()
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareGoalsSheet(completed: completedThisYear, goal: annualGoal, year: currentYear)
            }
            .navigationDestination(item: $selectedGameForDetail) { game in
                GameDetailView(game: game)
                    .environmentObject(store)
                    .environmentObject(profile)
            }
        }
    }

    // MARK: - 1. Årsmålskort (Matchar Mockup)
    private var annualGoalCard: some View {
        VStack(spacing: 16) {
            // Trofé-rad
            let displayCount = max(5, annualGoal)
            HStack(spacing: 12) {
                ForEach(0..<min(displayCount, 8), id: \.self) { idx in
                    let isCompleted = idx < completedThisYear
                    let isTargetSlot = idx < annualGoal

                    ZStack {
                        if isCompleted {
                            Circle()
                                .fill(Color.yellow.opacity(0.18))
                                .frame(width: 46, height: 46)

                            Image(systemName: "trophy.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.yellow)
                        } else if isTargetSlot {
                            Circle()
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                                )
                                .foregroundStyle(Color.secondary.opacity(0.35))
                                .frame(width: 46, height: 46)

                            Image(systemName: "trophy")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.secondary.opacity(0.25))
                        }
                    }
                }
            }
            .padding(.top, 4)

            // Sifferrubrik
            VStack(spacing: 6) {
                Text("\(completedThisYear) av \(annualGoal) klarade")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(tempoInfo.displayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            // Om tempot är orimligt (< 7 dagar per spel), visa hjälpsam justera-knapp
            if tempoInfo.isUnrealistic && !tempoInfo.isGoalReached {
                Button {
                    showingEditSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Justera målet")
                            .font(.subheadline.bold())
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - 2. Klarade spel för året
    @ViewBuilder
    private var completedGamesSection: some View {
        if !completedGamesList.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("KLARADE \(String(currentYear)) · \(completedGamesList.count) SPEL")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    Spacer()
                }

                VStack(spacing: 8) {
                    ForEach(completedGamesList) { game in
                        Button {
                            selectedGameForDetail = game
                        } label: {
                            HStack(spacing: 12) {
                                CoverView(title: game.title, url: game.coverURL, corner: 8, height: 52)
                                    .frame(width: 38, height: 52)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(game.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    HStack(spacing: 6) {
                                        if let date = game.completedDate {
                                            Text(formatCompletionDate(date))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        } else if let year = game.completedYear {
                                            Text("Klarat \(String(year))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Klarat \(String(currentYear))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        if let r = game.rating, r > 0 {
                                            Text("·")
                                                .foregroundStyle(.tertiary)
                                            HStack(spacing: 2) {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(.yellow)
                                                Text("\(r)")
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.primary)
                                            }
                                        }

                                        if let p = game.platforms.first {
                                            Text("·")
                                                .foregroundStyle(.tertiary)
                                            Text(compactPlatformName(p))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }
                            .padding(10)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func formatCompletionDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "d MMMM yyyy"
        return "Klarat \(df.string(from: date))"
    }

    private func compactPlatformName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("playstation 5") || lower == "ps5" { return "PS5" }
        if lower.contains("playstation 4") || lower == "ps4" { return "PS4" }
        if lower.contains("switch") { return "Switch" }
        if lower.contains("xbox series") || lower.contains("series x") || lower.contains("series s") { return "Xbox" }
        if lower.contains("pc") || lower.contains("windows") { return "PC" }
        return name
    }

    // MARK: - 3. Närmast i mål (Matchar Mockup)
    private func closestToFinishCard(game: Game, info: GameGoalProgressInfo) -> some View {
        Button {
            selectedGameForDetail = game
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Närmast i mål")
                    .font(.caption.bold())
                    .foregroundStyle(Color.yellow)

                HStack(spacing: 4) {
                    Text("\(game.title):")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if info.hasTasks && info.remainingTasks > 0 {
                        Text("\(info.remainingTasks) uppdrag kvar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(info.percentage) % klart.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    actionText(for: game.status)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4. Fokusmål (Matchar Mockup)
    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FOKUSMÅL · \(focusGames.count)/3")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()
            }

            VStack(spacing: 12) {
                ForEach(focusGames) { game in
                    focusGameCard(game)
                }

                // Tom plats (+ Lägg till fokusspel)
                if focusGames.count < 3 {
                    Button {
                        showingSelectGameSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.red)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Välj nästa fokusspel (\(3 - focusGames.count) platser kvar)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Spel du sätter till \"Spelar nu\" blir automatiskt fokusmål")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                                .foregroundStyle(Color.red.opacity(0.35))
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Dina pågående singleplayer-spel i Spelar nu är dina fokusmål. Klara ett för att göra plats!")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func focusGameCard(_ game: Game) -> some View {
        let progress = GamingGoalEngine.calculateProgress(for: game)

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Mini-omslag
                CoverView(title: game.title, url: game.coverURL, corner: 8, height: 68)
                    .frame(width: 48, height: 68)
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 6) {
                    // Titel & Procent
                    HStack {
                        Text(game.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(progress.percentage) %")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    // Progressbar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 6)

                            Capsule()
                                .fill(Color.red)
                                .frame(width: max(0, min(geo.size.width, geo.size.width * (Double(progress.percentage) / 100.0))), height: 6)
                        }
                    }
                    .frame(height: 6)
                    .padding(.vertical, 2)

                    // Subtext: Spelar nu · 7 av 24 · Nästa: Kap. 3
                    Text(progress.displaySubtext)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    // Handling: Fortsätt › / Återuppta › / Starta ›
                    Button {
                        handleGameAction(game)
                    } label: {
                        actionText(for: game.status)
                            .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture {
                selectedGameForDetail = game
            }
        }
    }

    private func actionText(for status: PlayStatus) -> some View {
        HStack(spacing: 3) {
            let title: String = {
                switch status {
                case .playing: return "Fortsätt"
                case .paused: return "Återuppta"
                case .notStarted, .abandoned, .completed: return "Starta"
                }
            }()

            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.red)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.red)
        }
    }

    private func handleGameAction(_ game: Game) {
        if game.status == .playing {
            selectedGameForDetail = game
        } else {
            // Sätt status till .playing och öppna
            var copy = game
            copy.status = .playing
            copy.isBacklog = false
            copy.lastPlayedDate = Date()
            store.update(copy)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selectedGameForDetail = copy
        }
    }

    // MARK: - 4. Märken & Milstolpar
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MÄRKEN & MILSTOLPAR")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            VStack(spacing: 10) {
                ForEach(badges) { badge in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(badge.isUnlocked ? Color.yellow.opacity(0.18) : Color(.tertiarySystemFill))
                                .frame(width: 40, height: 40)

                            Image(systemName: badge.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(badge.isUnlocked ? Color.yellow : Color.secondary.opacity(0.4))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(badge.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(badge.isUnlocked ? .primary : .secondary)

                                Spacer()

                                if badge.isUnlocked {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.green)
                                } else {
                                    Text("\(Int(round(badge.progressRatio * 100))) %")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(badge.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    // MARK: - Förslagskort vid ledig fokusplats
    private func suggestedGameCard(_ game: Game) -> some View {
        HStack(spacing: 12) {
            CoverView(title: game.title, url: game.coverURL, corner: 6, height: 44)
                .frame(width: 32, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("Föreslaget fokusspel")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                Text(game.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                profile.addTargetGoal(gameID: game.id)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Text("Välj")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation {
                    dismissedSuggestionID = game.id
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Hjälpvy för Delning
private struct ShareGoalsSheet: View {
    let completed: Int
    let goal: Int
    let year: Int
    @Environment(\.dismiss) private var dismiss

    var shareText: String {
        "🎮 Mitt spelmål för \(year): \(completed) av \(goal) spel avklarade på GameShelf!"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.yellow)

                    Text("Spelmål \(String(year))")
                        .font(.title2.bold())

                    Text("\(completed) av \(goal) klarade")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.top, 24)

                ShareLink(item: shareText) {
                    Label("Dela spelmål", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Dela spelmål")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Klar") { dismiss() }
                }
            }
        }
    }
}
