//
//  GameCard.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI

struct GameCard: View {
    let game: Game

    var body: some View {
        GSCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                CoverSection(game: game)
                TitleSection(game: game)
                MetaSection(game: game)
                RatingSection(rating: game.rating)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.title), \(game.platform), \(game.releaseYear)")
    }
}

// MARK: - Subviews (split into small views to avoid compiler expression blow-up)

private struct CoverSection: View {
    let game: Game

    // Precompute URL to avoid complex expression inside the body
    private var coverURL: URL? {
        game.coverURL
    }

    var body: some View {
        CoverView(
            title: game.title,
            url: coverURL,
            corner: Radius.m,
            height: 180
        )
        .overlay(
            LinearGradient(colors: [.clear, .black.opacity(0.28)],
                           startPoint: .center, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        )
        .overlay(alignment: .bottomLeading) {
            StatusBadge(status: game.status)
                .padding(6)
                .shadow(radius: 1)
        }
    }
}

private struct TitleSection: View {
    let game: Game
    var body: some View {
        Text(game.title)
            .font(Typography.title)
            .foregroundColor(.ds.textPrimary)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .frame(height: 36, alignment: .top)
    }
}

private struct MetaSection: View {
    let game: Game
    var body: some View {
        HStack(spacing: 6) {
            Text(game.platform)
                .lineLimit(1)
                .truncationMode(.tail)
            Text("·")
            Text("\(game.releaseYear)")
            Spacer(minLength: 0)
        }
        .font(Typography.caption)
        .foregroundColor(.ds.textSecondary)
        .frame(height: 14)
    }
}

private struct RatingSection: View {
    let rating: Int?
    var body: some View {
        let raw = rating ?? 0
        let stars = max(0, min(5, raw / 2)) // floor to 0...5
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < stars ? "star.fill" : "star")
            }
            Spacer(minLength: 0)
        }
        .font(Typography.caption)
        .foregroundColor(.ds.warning)
        .opacity(raw > 0 ? 1 : 0)
        .frame(height: 12)
    }
}
