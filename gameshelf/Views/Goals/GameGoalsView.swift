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
    @State private var gameForFinishSheet: Game? = nil
    @State private var showingShareSheet = false
    @State private var dismissedSuggestionID: UUID? = nil

    private var currentYear: Int {
        GamingGoalEngine.currentYear
    }

    private var completedThisYear: Int {
        GamingGoalEngine.completedCount(in: store.games, for: currentYear)
    }

    private var abandonedThisYear: Int {
        GamingGoalEngine.abandonedCount(in: store.games, for: currentYear)
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

        // 1. Först från Spelar nu som inte är fokusspel
        if let playing = store.games.first(where: {
            $0.isOwned && $0.status == .playing && !$0.isMultiplayerOrOngoing &&
            !currentFocusIDs.contains($0.id.uuidString.lowercased()) &&
            $0.id != dismissedSuggestionID
        }) {
            return playing
        }

        // 2. Sedan från Pausade
        if let paused = store.games.first(where: {
            $0.isOwned && $0.status == .paused && !$0.isMultiplayerOrOngoing &&
            !currentFocusIDs.contains($0.id.uuidString.lowercased()) &&
            $0.id != dismissedSuggestionID
        }) {
            return paused
        }

        // 3. Sedan från Backlog / Inte påbörjat
        if let backlog = store.games.first(where: {
            $0.isOwned && ($0.isBacklog || $0.status == .notStarted) && !$0.isMultiplayerOrOngoing &&
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
                VStack(spacing: 18) {
                    // 1. Årsmålskort
                    annualGoalCard

                    // 2. Närmast i mål (om något fokusspel uppfyller villkoret: >= 50% eller <= 5 uppdrag kvar)
                    if let closest = closestGame {
                        closestToFinishCard(game: closest.game, info: closest.info)
                    }

                    // 3. Fokusmål (X/3)
                    focusSection

                    // 4. Märken & Milstolpar
                    badgesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Spelmål \(String(currentYear))")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.red)
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
                            .foregroundStyle(.red)
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
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
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
            .sheet(item: $gameForFinishSheet) { game in
                GameFinishChoiceSheet(game: game)
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareGoalsSheet(completed: completedThisYear, abandoned: abandonedThisYear, goal: annualGoal, year: currentYear)
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
            // En trofé per målspel, ifyllda för klarade spel (avslutade spel fyller inte troféplatserna)
            let slotCount = max(1, annualGoal)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: min(slotCount, 6))

            if slotCount <= 6 {
                HStack(spacing: 12) {
                    ForEach(0..<slotCount, id: \.self) { idx in
                        trophySlotView(isCompleted: idx < completedThisYear)
                    }
                }
                .padding(.top, 4)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(0..<slotCount, id: \.self) { idx in
                        trophySlotView(isCompleted: idx < completedThisYear)
                    }
                }
                .padding(.top, 4)
            }

            // Sifferrubrik & utfall
            VStack(spacing: 6) {
                Text("\(completedThisYear) av \(annualGoal) klarade")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if abandonedThisYear > 0 {
                    Text("\(completedThisYear) klarade, \(abandonedThisYear) avslutat")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(tempoInfo.displayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            // Neutral ton om målet blir orimligt, med länken "Justera målet"
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
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func trophySlotView(isCompleted: Bool) -> some View {
        ZStack {
            if isCompleted {
                Circle()
                    .fill(Color.yellow.opacity(0.18))
                    .frame(width: 48, height: 48)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.yellow)
            } else {
                Circle()
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                    )
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .frame(width: 48, height: 48)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.yellow.opacity(0.22))
            }
        }
    }

    // MARK: - 2. Närmast i mål (Matchar Mockup)
    private func closestToFinishCard(game: Game, info: GameGoalProgressInfo) -> some View {
        Button {
            handlePrimaryAction(for: game)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text("Närmast i mål")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.yellow)

                HStack(spacing: 4) {
                    let remainingStr: String = {
                        if info.hasTasks && info.remainingTasks > 0 {
                            return "\(game.title): \(info.remainingTasks) uppdrag kvar."
                        } else {
                            return "\(game.title): \(info.percentage) % klart."
                        }
                    }()

                    Text(remainingStr)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    let actionLabel: String = {
                        switch game.status {
                        case .playing: return "Fortsätt ›"
                        case .paused: return "Återuppta ›"
                        default: return "Starta ›"
                        }
                    }()

                    Text(actionLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.red)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.yellow.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. Fokusmål (Matchar Mockup)
    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FOKUSMÅL · \(focusGames.count)/3")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                Spacer()
            }

            VStack(spacing: 14) {
                ForEach(focusGames) { game in
                    ActiveGameProgressCard(
                        game: game,
                        mode: .focusGoal,
                        onOpenDetail: {
                            selectedGameForDetail = game
                        },
                        onContinueOrResume: {
                            handlePrimaryAction(for: game)
                        },
                        onPause: {
                            pauseGame(game)
                        },
                        onFinish: {
                            gameForFinishSheet = game
                        },
                        onRemoveFocus: {
                            profile.removeTargetGoal(gameID: game.id)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    )
                }

                // Förslag på nästa fokusspel om plats finns
                if let suggestion = suggestedNextGame, focusGames.count < 3 {
                    suggestedGameCard(suggestion)
                }

                // Tom plats (+ Lägg till fokusspel) eller Max 3-text
                if focusGames.count < 3 {
                    Button {
                        showingSelectGameSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)

                            Text("Lägg till fokusspel")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                                .foregroundStyle(Color.secondary.opacity(0.35))
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Max 3 fokusspel. Klara ett för att göra plats.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func handlePrimaryAction(for game: Game) {
        if game.status == .playing {
            selectedGameForDetail = game
        } else {
            var copy = game
            copy.status = .playing
            copy.isBacklog = false
            copy.lastPlayedDate = Date()
            if copy.startedPlayingDate == nil {
                copy.startedPlayingDate = Date()
            }
            store.update(copy)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selectedGameForDetail = copy
        }
    }

    private func pauseGame(_ game: Game) {
        var copy = game
        copy.status = .paused
        copy.pausedDate = Date()
        store.update(copy)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - 4. Märken & Milstolpar
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MÄRKEN & MILSTOLPAR")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)

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
                Text("Förslag på nästa fokusspel")
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
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Delad Kortkomponent för Fokusmål (Spelmål) & Spelar nu (Bibliotek)
struct ActiveGameProgressCard: View {
    enum CardMode {
        case focusGoal
        case libraryPlaying
    }

    let game: Game
    let mode: CardMode
    let onOpenDetail: () -> Void
    let onContinueOrResume: () -> Void
    let onPause: () -> Void
    let onFinish: () -> Void
    var onRemoveFocus: (() -> Void)? = nil

    private var progress: GameGoalProgressInfo {
        GamingGoalEngine.calculateProgress(for: game)
    }

    private var isOngoingMultiplayer: Bool {
        game.isMultiplayerOrOngoing
    }

    var body: some View {
        if isOngoingMultiplayer {
            compactOngoingBody
        } else {
            standardProgressBody
        }
    }

    // Kompakt kort för löpande spel: Omslag, titel, "Sedan 25 okt" och "…"-meny
    private var compactOngoingBody: some View {
        let sinceStr = GamingGoalEngine.formatShortDayMonth(game.effectiveStartedPlayingDate)
        let note = game.progressNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subtitle: String = {
            if mode == .focusGoal && game.status != .playing {
                return statusLineText
            }
            if !note.isEmpty {
                return "Sedan \(sinceStr) · \(note)"
            }
            return "Sedan \(sinceStr)"
        }()

        return HStack(spacing: 10) {
            Button {
                onOpenDetail()
            } label: {
                HStack(spacing: 12) {
                    CoverView(title: game.title, url: game.coverURL, corner: 8, height: 50)
                        .frame(width: 38, height: 50)
                        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(game.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ActiveCardPressStyle())

            Menu {
                if mode == .libraryPlaying || game.status == .playing {
                    Button {
                        onPause()
                    } label: {
                        Label("Pausa", systemImage: "pause.fill")
                    }

                    Button {
                        onFinish()
                    } label: {
                        Label("Avsluta…", systemImage: "flag.checkered")
                    }
                } else if game.status == .paused {
                    Button {
                        onContinueOrResume()
                    } label: {
                        Label("Återuppta", systemImage: "play.fill")
                    }

                    Button {
                        onFinish()
                    } label: {
                        Label("Avsluta…", systemImage: "flag.checkered")
                    }
                } else {
                    Button {
                        onContinueOrResume()
                    } label: {
                        Label("Starta", systemImage: "play.fill")
                    }
                }

                if let onRemoveFocus {
                    Divider()
                    Button(role: .destructive) {
                        onRemoveFocus()
                    } label: {
                        Label("Ta bort från fokus", systemImage: "xmark.circle")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemFill), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // Standardkort för spel med progress
    private var standardProgressBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Övre del: Hela ytan öppnar spelets detaljvy
            Button {
                onOpenDetail()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    CoverView(title: game.title, url: game.coverURL, corner: 10, height: 78)
                        .frame(width: 58, height: 78)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                    VStack(alignment: .leading, spacing: 5) {
                        // Titel (upp till 2 rader) & Procent + diskret chevron
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(game.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 4)

                            HStack(spacing: 6) {
                                if progress.percentage > 0 {
                                    Text("\(progress.percentage) %")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // Progressbar (visas endast när progress > 0 %)
                        if progress.percentage > 0 {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(.tertiarySystemFill))
                                        .frame(height: 6)

                                    Capsule()
                                        .fill(Color.red)
                                        .frame(
                                            width: max(
                                                6,
                                                min(geo.size.width, geo.size.width * (Double(progress.percentage) / 100.0))
                                            ),
                                            height: 6
                                        )
                                }
                            }
                            .frame(height: 6)
                            .padding(.vertical, 1)
                        }

                        // Metadata-rader beroende på mode (Fokusmål vs Bibliotek Spelar nu)
                        if mode == .libraryPlaying {
                            libraryMetadataSection
                        } else {
                            focusGoalMetadataSection
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ActiveCardPressStyle())

            // Kompakta sekundära knappar längst ner
            actionButtonsRow
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // Metadata för Bibliotek -> Spelar nu
    @ViewBuilder
    private var libraryMetadataSection: some View {
        let sinceStr = GamingGoalEngine.formatShortDayMonth(game.effectiveStartedPlayingDate)

        // Rad 1: "5 av 17 uppdrag · Sedan 3 okt" (eller vid 0 % utan uppdrag: "Inte kommit igång än · Sedan 3 okt")
        if progress.hasTasks {
            Text("\(progress.completedTasks) av \(progress.totalTasks) uppdrag · Sedan \(sinceStr)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else if progress.percentage == 0 {
            Text("Inte kommit igång än · Sedan \(sinceStr)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Text("Sedan \(sinceStr)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }

        // Rad 2: "Nästa: ..." får gå över upp till 2 rader
        if let next = progress.nextTaskTitle, !next.isEmpty {
            if progress.remainingTasks == 1 {
                Text("Nästa: \(next) · Bara 1 kvar")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Nästa: \(next)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        } else if !progress.hasTasks {
            Text("Lägg till kapitel & uppdrag ›")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
        }
    }

    // Metadata för Spelmål 2026 -> Fokusmål
    @ViewBuilder
    private var focusGoalMetadataSection: some View {
        // Rad 1: Statusprick + Status + Datum
        HStack(spacing: 6) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 8, height: 8)

            Text(statusLineText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }

        // Rad 2: "7 av 24 uppdrag · Nästa: Kap. 3 Zalissya" (upp till 2 rader)
        if progress.hasTasks {
            if let next = progress.nextTaskTitle, !next.isEmpty {
                Text("\(progress.completedTasks) av \(progress.totalTasks) uppdrag · Nästa: \(next)")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            } else {
                Text("\(progress.completedTasks) av \(progress.totalTasks) uppdrag")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        } else if let est = game.estimatedHours, est > 0 {
            Text("Uppskattad tid: ~\(est) tim")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var statusDotColor: Color {
        switch game.status {
        case .playing: return .green
        case .paused: return .yellow
        case .notStarted: return .secondary
        case .completed: return .teal
        case .abandoned: return .purple
        }
    }

    private var statusLineText: String {
        switch game.status {
        case .playing:
            let since = GamingGoalEngine.formatShortDayMonth(game.effectiveStartedPlayingDate)
            return "Spelar nu · Sedan \(since)"
        case .paused:
            let since = GamingGoalEngine.formatShortDayMonth(game.effectivePausedDate)
            return "Pausat sedan \(since)"
        case .notStarted:
            return "Backlog"
        case .completed:
            return "Klarat"
        case .abandoned:
            return "Avslutat"
        }
    }

    // Lägre knappar; Pausa har tydligare sekundär fyllning medan Avsluta är mer diskret för att undvika feltryck
    @ViewBuilder
    private var actionButtonsRow: some View {
        if mode == .libraryPlaying || game.status == .playing {
            HStack(spacing: 8) {
                Button {
                    onPause()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Pausa")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    onFinish()
                } label: {
                    Text("Avsluta…")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.clear, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        } else if game.status == .paused {
            HStack(spacing: 8) {
                Button {
                    onContinueOrResume()
                } label: {
                    Text("Återuppta")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.red, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    onFinish()
                } label: {
                    Text("Avsluta…")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.clear, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack(spacing: 8) {
                Button {
                    onContinueOrResume()
                } label: {
                    Text("Starta")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.red, in: Capsule())
                }
                .buttonStyle(.plain)

                if let onRemoveFocus {
                    Button {
                        onRemoveFocus()
                    } label: {
                        Text("Ta bort")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onFinish()
                    } label: {
                        Text("Avsluta…")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(Color.clear, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ActiveCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Avsluta-val: Klarat (räknas mot årsmålet) eller Avslutat ("Nöjd, klar för mig")
struct GameFinishChoiceSheet: View {
    enum FinishChoice: String, CaseIterable, Identifiable {
        case completed = "completed"
        case satisfied = "satisfied"

        var id: String { rawValue }
    }

    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    let game: Game

    @State private var selectedChoice: FinishChoice = .completed
    @State private var rating: Int
    @State private var reviewNotes: String
    @State private var finishDate: Date = Date()

    init(game: Game) {
        self.game = game
        _rating = State(initialValue: game.rating ?? 0)
        _reviewNotes = State(initialValue: game.notes)
        let progress = GamingGoalEngine.calculateProgress(for: game)
        // Löpande multiplayer-spel kan aldrig bli "Klarat", utan erbjuds endast "Avslutat"
        if game.isMultiplayerOrOngoing || (progress.hasTasks && progress.percentage < 100) {
            _selectedChoice = State(initialValue: .satisfied)
        } else {
            _selectedChoice = State(initialValue: .completed)
        }
    }

    private var progress: GameGoalProgressInfo {
        GamingGoalEngine.calculateProgress(for: game)
    }

    private var currentYear: Int {
        GamingGoalEngine.currentYear
    }

    private var completedThisYear: Int {
        GamingGoalEngine.completedCount(in: store.games, for: currentYear)
    }

    private var annualGoal: Int {
        max(1, profile.annualGamingGoal)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Spel-header med "Sparas på XX %" (eller Löpande multiplayer-spel)
                    HStack(spacing: 14) {
                        CoverView(title: game.title, url: game.coverURL, corner: 10, height: 74)
                            .frame(width: 54, height: 74)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(game.title)
                                .font(.headline.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            HStack(spacing: 6) {
                                if game.isMultiplayerOrOngoing {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.purple)
                                    Text("Löpande multiplayer-spel")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.red)

                                    if progress.hasTasks {
                                        Text("Sparas på \(progress.percentage) % (\(progress.completedTasks) av \(progress.totalTasks) uppdrag)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Sparas på \(progress.percentage) %")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Välj hur spelet avslutas (för löpande multiplayer-spel erbjuds endast Avslutat)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(game.isMultiplayerOrOngoing ? "AVSLUTA LÖPANDE MULTIPLAYER-SPEL" : "HUR VILL DU AVSLUTA SPELET?")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        if !game.isMultiplayerOrOngoing {
                            // Val 1: Klarat (endast för singleplayer / story-spel)
                            choiceOptionCard(
                                choice: .completed,
                                icon: "trophy.fill",
                                iconColor: .yellow,
                                title: "Klarat",
                                subtitle: "Jag har spelat klart spelet.",
                                consequence: "Räknas mot ditt årsmål (\(min(annualGoal, completedThisYear + 1)) av \(annualGoal)) och fyller en troféplats."
                            )
                        }

                        // Val 2: Avslutat ("Nöjd, klar för mig")
                        choiceOptionCard(
                            choice: .satisfied,
                            icon: "flag.checkered",
                            iconColor: .purple,
                            title: "Avslutat — Nöjd, klar för mig",
                            subtitle: game.isMultiplayerOrOngoing
                                ? "Jag är nöjd med min tid i spelet och lägger det på hyllan för nu."
                                : "Jag är nöjd med min tid i spelet utan att ha spelat 100 % klart.",
                            consequence: game.isMultiplayerOrOngoing
                                ? "Löpande multiplayer-spel räknas inte mot årsmålet."
                                : "Räknas inte mot troféplatserna i årsmålet. Progressen sparas på \(progress.percentage) %."
                        )
                    }

                    // Valfri bedömning & anteckning
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Valfritt betyg", systemImage: "star.fill")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)

                                Spacer()

                                if rating > 0 {
                                    Button("Rensa") {
                                        rating = 0
                                    }
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                }
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(1...10, id: \.self) { score in
                                        let isSelected = rating == score
                                        Button {
                                            rating = score
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        } label: {
                                            Text("\(score)")
                                                .font(.subheadline.bold())
                                                .frame(width: 34, height: 34)
                                                .background(
                                                    isSelected ? Color.yellow : Color(.tertiarySystemFill),
                                                    in: Circle()
                                                )
                                                .foregroundStyle(isSelected ? Color.black : Color.primary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Valfri anteckning", systemImage: "quote.opening")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)

                            TextField("T.ex. tankar om spelet eller varför du kände dig nöjd här...", text: $reviewNotes, axis: .vertical)
                                .lineLimit(3...6)
                                .font(.subheadline)
                                .padding(12)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Spara-knapp
                    Button {
                        saveFinishChoice()
                    } label: {
                        Text(selectedChoice == .completed ? "Markera som Klarat" : "Markera som Avslutat")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(selectedChoice == .completed ? Color.red : Color.purple, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Avsluta spel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func choiceOptionCard(
        choice: FinishChoice,
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        consequence: String
    ) -> some View {
        let isSelected = selectedChoice == choice
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedChoice = choice
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 38, height: 38)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? iconColor : Color.secondary.opacity(0.4))
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(consequence)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isSelected ? iconColor : .secondary)
                        .padding(.top, 2)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? iconColor : Color.white.opacity(0.08), lineWidth: isSelected ? 1.8 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func saveFinishChoice() {
        var updated = game
        let cal = Calendar.current
        updated.isBacklog = false
        updated.completedDate = finishDate
        updated.completedYear = cal.component(.year, from: finishDate)

        if selectedChoice == .completed {
            updated.status = .completed
            updated.storyProgress = .completed
        } else {
            updated.status = .abandoned
            // Behåll befintlig progress (todos och storyProgress lämnas orörda så att t.ex. 60 % sparas)
        }

        if rating > 0 {
            updated.rating = rating
        }
        if !reviewNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.notes = reviewNotes
            updated.noteUpdatedAt = Date()
        }

        store.update(updated)
        // Spelet lämnar fokusmål direkt så att platsen frigörs
        profile.removeTargetGoal(gameID: game.id)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}

// MARK: - Hjälpvy för Delning
private struct ShareGoalsSheet: View {
    let completed: Int
    let abandoned: Int
    let goal: Int
    let year: Int
    @Environment(\.dismiss) private var dismiss

    var shareText: String {
        if abandoned > 0 {
            return "🎮 Mitt spelmål för \(year): \(completed) av \(goal) spel klarade (\(abandoned) avslutat) på GameShelf!"
        }
        return "🎮 Mitt spelmål för \(year): \(completed) av \(goal) spel klarade på GameShelf!"
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

                    if abandoned > 0 {
                        Text("\(completed) klarade, \(abandoned) avslutat")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
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
