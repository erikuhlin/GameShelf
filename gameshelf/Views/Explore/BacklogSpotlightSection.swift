//
//  BacklogSpotlightSection.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

struct BacklogSpotlightSection: View {
    @EnvironmentObject var store: LibraryStore

    private var backlogGames: [Game] {
        store.games.filter { $0.isBacklog && $0.isOwned }
    }

    var body: some View {
        if !backlogGames.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Från din backlog")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Text("Ospelade spel i din samling som väntar på att upptäckas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(backlogGames.prefix(6)) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    CoverView(title: game.title, url: game.coverURL, corner: 12, height: 140)
                                        .frame(width: 105, height: 140)
                                        .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(game.title)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        if let est = game.estimatedHours, est > 0 {
                                            Text("⏱️ ~\(est) timmar")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        } else if let genre = game.genres.first {
                                            Text(genre)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
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
