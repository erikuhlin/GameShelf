//
//  CollectionCard.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

struct CollectionCard: View {
    let collection: GameCollection
    @EnvironmentObject var store: LibraryStore

    private var gamesInCollection: [Game] {
        store.games(in: collection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Mini kollage av upp till 3 omslag
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 150, height: 95)

                if gamesInCollection.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Tom samling")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 150, height: 95)
                } else {
                    HStack(spacing: -24) {
                        ForEach(Array(gamesInCollection.prefix(3).enumerated()), id: \.element.id) { index, game in
                            CoverView(title: game.title, url: game.coverURL, corner: 6, height: 75)
                                .frame(width: 52, height: 75)
                                .shadow(color: .black.opacity(0.25), radius: 4, x: 2, y: 2)
                                .zIndex(Double(3 - index))
                        }
                    }
                    .padding(.leading, 12)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(gamesInCollection.count) spel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 150, alignment: .leading)
        }
        .padding(8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
