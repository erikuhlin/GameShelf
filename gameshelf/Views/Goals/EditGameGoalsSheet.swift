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
    @State private var recentlyRemovedFocusGame: Game? = nil
    @State private var previousTargetIDs: [String] = []

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
                                Text("\(max(minimumGoal, profile.annualGamingGoal))")
                                    .font(.system(size: 38, weight: .black, design: .rounded))
                                    .foregroundStyle(.primary)

                                Text("spel under \(String(currentYear))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                withAnimation {
                                    if profile.annualGamingGoal < minimumGoal {
                                        profile.annualGamingGoal = minimumGoal + 1
                                    } else {
                                        profile.annualGamingGoal += 1
                                    }
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
                            Text("Minimum för årsmålet är \(completedThisYear) (antalet redan klarade spel).")
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
                        VStack(alignment: .leading, spacing: 6) {
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
                                    removeFromFocusWithUndo(game)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(Color(.secondaryLabel))
                                        .frame(width: 28, height: 28)
                                        .background(Color(.tertiarySystemFill), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Ta bort från fokus")
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
                                Image(systemName: "plus")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.red)
                                Text("Lägg till fokusspel")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.red)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    HStack {
                        Text("Fokusmål (\(focusGames.count)/3)")
                        Spacer()
                        if focusGames.count > 1 {
                            Text("Dra för att ändra ordning")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("✕ tar bort spelet från dina fokusmål utan att ta bort det ur biblioteket.")
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .bottom) {
                if let removed = recentlyRemovedFocusGame {
                    HStack(spacing: 12) {
                        Text("\"\(removed.title)\" borttaget från fokus")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer()

                        Button {
                            withAnimation {
                                profile.targetGameIDs = previousTargetIDs
                                recentlyRemovedFocusGame = nil
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Text("Ångra")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.yellow)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.darkGray).opacity(0.95), in: Capsule())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
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
            .onAppear {
                if profile.annualGamingGoal < minimumGoal {
                    profile.annualGamingGoal = minimumGoal
                }
            }
        }
    }

    private func removeFromFocusWithUndo(_ game: Game) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            previousTargetIDs = profile.targetGameIDs
            profile.removeTargetGoal(gameID: game.id)
            recentlyRemovedFocusGame = game
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func statusColor(_ status: PlayStatus) -> Color {
        switch status {
        case .playing: return .green
        case .paused: return .yellow
        case .notStarted: return .secondary
        case .completed: return .teal
        case .abandoned: return .purple
        }
    }
}
