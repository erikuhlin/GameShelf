//
//  SelectFocusGameSheet.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-10-24.
//

import SwiftUI

struct SelectFocusGameSheet: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""

    private var availableGames: [Game] {
        let currentTargetIDs = Set(profile.targetGameIDs.map { $0.lowercased() })
        return store.games.filter { game in
            // Endast spel i ägo som inte redan är fokusmål och inte redan är klara
            game.isOwned &&
            game.status != .completed &&
            !currentTargetIDs.contains(game.id.uuidString.lowercased())
        }
    }

    private var filteredGames: [Game] {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return availableGames.sorted { (g1, g2) -> Bool in
                // Prioritera "Spelar nu", sedan "Pausat", sedan "Inte påbörjat"
                let order1 = priorityOrder(g1.status)
                let order2 = priorityOrder(g2.status)
                if order1 != order2 { return order1 < order2 }
                return g1.title.localizedCaseInsensitiveCompare(g2.title) == .orderedAscending
            }
        }
        return availableGames
            .filter { $0.title.localizedCaseInsensitiveContains(search) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func priorityOrder(_ status: PlayStatus) -> Int {
        switch status {
        case .playing: return 0
        case .paused: return 1
        case .notStarted: return 2
        case .abandoned: return 3
        case .completed: return 4
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availableGames.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Inga fler tillgängliga spel")
                            .font(.headline)
                        Text("Alla spel i ditt bibliotek är redan fokusmål eller genomspelade.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredGames) { game in
                            Button {
                                profile.addTargetGoal(gameID: game.id)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    CoverView(title: game.title, url: game.coverURL, corner: 6, height: 50)
                                        .frame(width: 38, height: 50)

                                    VStack(alignment: .leading, spacing: 4) {
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

                                            if let est = game.estimatedHours, est > 0 {
                                                Text("·")
                                                    .foregroundStyle(.secondary)
                                                Text("~ \(est) tim")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.red)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $search, prompt: "Sök spel att fokusera på...")
            .navigationTitle("Välj fokusspel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
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
