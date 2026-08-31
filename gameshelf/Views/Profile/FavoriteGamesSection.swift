//
//  FavoriteGamesSection.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-31.
//

import SwiftUI

struct FavoriteGamesSection: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var profile: ProfileStore

    @State private var showingAddSheet = false

    private var favoriteGames: [Game] {
        profile.favoriteGameIDs.compactMap { id in
            store.games.first(where: { $0.id.uuidString == id })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Sektionsrubrik
            HStack {
                HStack(spacing: 6) {
                    Text("⭐")
                        .font(.subheadline)
                    Text("Mina favoritspel")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                if !favoriteGames.isEmpty {
                    Text("(\(favoriteGames.count)/10)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Horisontell karusell
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(favoriteGames) { game in
                        NavigationLink(destination: GameDetailView(game: game)) {
                            ZStack(alignment: .topTrailing) {
                                ZStack(alignment: .bottomLeading) {
                                    CoverView(title: game.title, url: game.coverURL, corner: 12, height: 120)
                                        .frame(width: 86, height: 120)
                                        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.85)],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                    Text(game.title)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                        .padding(7)
                                        .shadow(color: .black, radius: 2)
                                }
                                .frame(width: 86, height: 120)

                                // Ta bort-knapp (subtil i hörnet)
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        profile.removeFavoriteGame(id: game.id.uuidString)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white, Color.black.opacity(0.7))
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    profile.removeFavoriteGame(id: game.id.uuidString)
                                }
                            } label: {
                                Label("Ta bort från favoriter", systemImage: "trash")
                            }
                        }
                    }

                    // "+"-kort för att lägga till
                    if profile.favoriteGameIDs.count < 10 {
                        Button {
                            showingAddSheet = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("Lägg till")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 86, height: 120)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                    .foregroundStyle(Color.white.opacity(0.18))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddFavoriteGameSheet()
                .environmentObject(store)
                .environmentObject(profile)
        }
    }
}
