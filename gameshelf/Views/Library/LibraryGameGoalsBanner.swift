//
//  LibraryGameGoalsBanner.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-10-24.
//

import SwiftUI

struct LibraryGameGoalsBanner: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var profile: ProfileStore

    @State private var showingGoalsSheet = false

    private var currentYear: Int {
        GamingGoalEngine.currentYear
    }

    private var completedThisYear: Int {
        GamingGoalEngine.completedCount(in: store.games, for: currentYear)
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

    var body: some View {
        Button {
            showingGoalsSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Topprad: Trofé + Rubrik + Chevron
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.18))
                            .frame(width: 26, height: 26)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.yellow)
                    }

                    Text("Spelmål \(String(currentYear))")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text("\(completedThisYear) av \(annualGoal) klara")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                // Subtext / Tempo
                Text(tempoInfo.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Mini-kort för fokusspelen (om det finns fokusspel)
                if !focusGames.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(focusGames) { game in
                            let progress = GamingGoalEngine.calculateProgress(for: game)
                            HStack(spacing: 6) {
                                CoverView(title: game.title, url: game.coverURL, corner: 4, height: 32)
                                    .frame(width: 22, height: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Text("\(progress.percentage) %")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.red)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingGoalsSheet) {
            GameGoalsView()
                .environmentObject(store)
                .environmentObject(profile)
        }
    }
}
