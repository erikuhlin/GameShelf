//
//  GameHeroHeader.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-27.
//


import SwiftUI

struct GameHeroHeader: View {
    let game: Game
    var height: CGFloat = 300 // tidigare 260 – höj gärna för tydligare hero-känsla

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CoverView(title: game.title,
                      url: game.coverURL,
                      corner: 0,
                      height: height,
                      fitMode: .fill) // tvinga täckande i hero-headern

            // Soft top-to-center fade for readability if you later put controls on top
            LinearGradient(colors: [Color.black.opacity(0.35), .clear],
                           startPoint: .top, endPoint: .center)
                .allowsHitTesting(false)

            // Optional title/meta overlay (kept for backward-compatibility in places where it's used)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(game.title)
                    .font(Typography.h2)
                    .foregroundColor(.white)
                    .shadow(radius: 2)

                HStack(spacing: Spacing.s) {
                    StatusBadge(status: game.status)
                    Text(game.platforms.joined(separator: ", "))
                    Text("·")
                    Text("\(game.releaseYear)")
                }
                .font(Typography.caption)
                .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.m)
        }

        // Om du vill ha rundade hörn i stället för full-bleed:
        // .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        // .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).stroke(.separator.opacity(0.4), lineWidth: 1))
        // .padding(.horizontal)
    }
}

struct CompactGameHeroHeader: View {
    let game: Game
    var body: some View {
        HStack(spacing: Spacing.m) {
            CoverView(title: game.title,
                      url: game.coverURL,
                      corner: Radius.m,
                      height: 128,
                      fitMode: .fill) // även här, så miniatyren fyller sin yta
            .frame(width: 96)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(game.title)
                    .font(Typography.title)
                    .foregroundColor(.ds.textPrimary)

                HStack(spacing: Spacing.s) {
                    StatusBadge(status: game.status)
                    Text(game.platforms.first ?? "")
                    Text("·")
                    Text("\(game.releaseYear)")
                }
                .font(Typography.caption)
                .foregroundColor(.ds.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.m)
    }
}
