//
//  SmartGameRouletteCard.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

struct SmartGameRouletteCard: View {
    @EnvironmentObject var store: LibraryStore
    @State private var currentGame: Game?
    @State private var reason: String = ""
    @State private var isRolling: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vad ska du spela ikväll?")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    rollNewGame()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dice.fill")
                            .font(.caption.bold())
                        Text("Slumpa")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.12))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if let game = currentGame {
                NavigationLink(destination: GameDetailView(game: game)) {
                    HStack(spacing: 14) {
                        CoverView(title: game.title, url: game.coverURL, corner: 10, height: 100)
                            .frame(width: 75, height: 100)
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 2, y: 3)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(game.title)
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 8) {
                                StatusBadge(game: game)

                                if let est = game.estimatedHours, est > 0 {
                                    HStack(spacing: 3) {
                                        Image(systemName: "clock")
                                            .font(.caption2)
                                        Text("~\(est) tim")
                                            .font(.caption.bold())
                                    }
                                    .foregroundStyle(.secondary)
                                }

                                if let r = game.rating, r > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                        Text("\(r)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }

                            if !reason.isEmpty {
                                Text(reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .padding(.top, 2)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .opacity(isRolling ? 0.3 : 1.0)
                .scaleEffect(isRolling ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isRolling)
            } else {
                VStack(spacing: 6) {
                    Text("Lägg till spel i ditt bibliotek för att få personliga förslag.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color(.tertiarySystemGroupedBackground).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        .onAppear {
            if currentGame == nil {
                pickSmartGame()
            }
        }
        .onChange(of: store.games.count) { _, _ in
            if currentGame == nil {
                pickSmartGame()
            }
        }
    }

    private func rollNewGame() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation {
            isRolling = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            pickSmartGame()
            withAnimation {
                isRolling = false
            }
        }
    }

    private func pickSmartGame() {
        let games = store.games.filter { $0.isOwned }
        guard !games.isEmpty else {
            currentGame = nil
            reason = ""
            return
        }

        // Prioritet 1: Pågående eller pausade spel
        let activeGames = games.filter { $0.status == .playing || $0.status == .paused }
        let backlogGames = games.filter { $0.isBacklog }
        let completedGames = games.filter { $0.status == .completed }

        var pool: [Game] = []
        var motivation = ""

        let randomChoice = Int.random(in: 1...10)

        if !activeGames.isEmpty && randomChoice <= 6 {
            pool = activeGames.filter { $0.id != currentGame?.id }
            motivation = "Fortsätt där du slutade"
        } else if !backlogGames.isEmpty && randomChoice <= 9 {
            pool = backlogGames.filter { $0.id != currentGame?.id }
            motivation = "Dags att ta tag i backloggen"
        } else if !completedGames.isEmpty {
            pool = completedGames.filter { $0.id != currentGame?.id }
            motivation = "Dags att återbesöka en favorit"
        } else {
            pool = games.filter { $0.id != currentGame?.id }
            motivation = "Ett rekommenderat spel från din spelsamling."
        }

        if let selected = (pool.isEmpty ? games : pool).randomElement() {
            currentGame = selected
            if let est = selected.estimatedHours, est > 0, est <= 8 {
                reason = "\(motivation) – perfekt val (~\(est) timmar) för ikväll."
            } else {
                reason = motivation
            }
        }
    }
}
