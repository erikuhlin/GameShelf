//
//  EditGameGoalsSheet.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-10-24.
//

import SwiftUI

struct EditGameGoalsSheet: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingSelectGameSheet = false
    @State private var gameToRemoveFromFocus: Game? = nil
    @State private var showingRemoveFocusConfirmation = false

    private var currentYear: Int {
        GamingGoalEngine.currentYear
    }

    private var completedThisYear: Int {
        GamingGoalEngine.completedCount(in: store.games, for: currentYear)
    }

    private var minimumGoal: Int {
        max(1, completedThisYear)
    }

    private var focusGames: [Game] {
        GamingGoalEngine.focusGames(from: store.games, targetIDs: profile.targetGameIDs)
    }

    var body: some View {
        NavigationStack {
            List {
                // Sektion 1: Årsmål
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Välj hur många spel du siktar på att klara under \(String(currentYear)).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            Button {
                                if profile.annualGamingGoal > minimumGoal {
                                    withAnimation {
                                        profile.annualGamingGoal -= 1
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.title3.bold())
                                    .frame(width: 44, height: 44)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(profile.annualGamingGoal <= minimumGoal)
                            .opacity(profile.annualGamingGoal <= minimumGoal ? 0.4 : 1.0)

                            Spacer()

                            VStack(spacing: 2) {
                                Text("\(profile.annualGamingGoal)")
                                    .font(.system(size: 38, weight: .black, design: .rounded))
                                    .foregroundStyle(.primary)

                                Text("spel under \(String(currentYear))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                withAnimation {
                                    profile.annualGamingGoal += 1
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title3.bold())
                                    .frame(width: 44, height: 44)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)

                        // Snabbval (visar endast alternativ >= minimumGoal)
                        let presets = [3, 5, 10, 12, 15, 20, 25, 50].filter { $0 >= minimumGoal }
                        if !presets.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(presets, id: \.self) { preset in
                                        let isSelected = profile.annualGamingGoal == preset
                                        Button {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                profile.annualGamingGoal = preset
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            }
                                        } label: {
                                            Text("\(preset)")
                                                .font(.subheadline.bold())
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 7)
                                                .background(isSelected ? Color.red : Color(.secondarySystemGroupedBackground))
                                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                                .clipShape(Capsule())
                                                .overlay(
                                                    Capsule()
                                                        .stroke(isSelected ? Color.clear : Color(.separator).opacity(0.6), lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        if completedThisYear > 0 {
                            Text("Minimum är \(completedThisYear) eftersom du redan klarat så många spel i år.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Årsmål \(String(currentYear))")
                }

                // Sektion 2: Fokusmål (upp till 3 spel)
                Section {
                    if focusGames.isEmpty {
                        VStack(spacing: 8) {
                            Text("Inga aktiva fokusspel")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("Välj upp till 3 spel du vill prioritera just nu.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    } else {
                        ForEach(focusGames) { game in
                            HStack(spacing: 12) {
                                CoverView(title: game.title, url: game.coverURL, corner: 6, height: 46)
                                    .frame(width: 34, height: 46)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(game.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(statusColor(game.status))
                                            .frame(width: 7, height: 7)

                                        Text(game.status.title(for: game.playTypes))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        let progress = GamingGoalEngine.calculateProgress(for: game)
                                        if progress.hasTasks {
                                            Text("·")
                                                .foregroundStyle(.secondary)
                                            Text("\(progress.completedTasks)/\(progress.totalTasks)")
                                                .font(.caption.bold())
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }

                                Spacer()

                                Button {
                                    gameToRemoveFromFocus = game
                                    showingRemoveFocusConfirmation = true
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color(.secondaryLabel))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Ta bort från fokusmål")
                            }
                            .padding(.vertical, 2)
                        }
                        .onMove { source, destination in
                            profile.reorderTargetGoals(from: source, to: destination)
                        }
                    }

                    if focusGames.count < 3 {
                        Button {
                            showingSelectGameSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.red)
                                Text("Lägg till fokusspel (\(3 - focusGames.count) kvar)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.red)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    HStack {
                        Text("Aktiva fokusmål (\(focusGames.count)/3)")
                        Spacer()
                        if focusGames.count > 1 {
                            Text("Dra för att ändra ordning")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("När ett fokusspel klaras räknas det mot årsmålet och platsen frigörs automatiskt.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Redigera spelmål")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") {
                        dismiss()
                    }
                    .font(.subheadline.bold())
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingSelectGameSheet) {
                SelectFocusGameSheet()
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .confirmationDialog(
                "Ta bort från fokusmål?",
                isPresented: $showingRemoveFocusConfirmation,
                titleVisibility: .visible,
                presenting: gameToRemoveFromFocus
            ) { game in
                Button("Ta bort från fokusmål", role: .destructive) {
                    profile.removeTargetGoal(gameID: game.id)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                Button("Avbryt", role: .cancel) {}
            } message: { game in
                Text("\"\(game.title)\" tas bort från dina aktiva fokusmål. Spelet och all din historik finns kvar i biblioteket.")
            }
        }
    }

    private func statusColor(_ status: PlayStatus) -> Color {
        switch status {
        case .playing: return .green
        case .paused: return .orange
        case .notStarted: return .secondary
        case .completed: return .teal
        case .abandoned: return .purple
        }
    }
}
