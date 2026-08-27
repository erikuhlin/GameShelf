//
//  ContinuePlayingSection.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

struct ContinuePlayingSection: View {
    @EnvironmentObject var store: LibraryStore

    private var activeGames: [Game] {
        store.games.filter { $0.status == .playing && $0.isOwned }
    }

    var body: some View {
        if !activeGames.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Fortsätt spela")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(activeGames.count) aktiva")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(activeGames) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack(alignment: .bottomTrailing) {
                                        CoverView(title: game.title, url: game.coverURL, corner: 12, height: 140)
                                            .frame(width: 105, height: 140)
                                            .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)

                                        if let est = game.estimatedHours, est > 0 {
                                            Text("\(est)h")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(.ultraThinMaterial, in: Capsule())
                                                .padding(6)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(game.title)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        StatusBadge(status: game.status)
                                    }
                                    .frame(width: 105, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
