//
//  GameDetailView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//


import SwiftUI

struct GameDetailView: View {
    @EnvironmentObject var store: LibraryStore
    @State var game: Game

    private func persist() {
        if let idx = store.games.firstIndex(where: { $0.id == game.id }) {
            store.games[idx] = game
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CoverView(title: game.title,
                          url: game.coverURL,
                          corner: 0,
                          height: 260)
                .overlay(
                    LinearGradient(colors: [Color.black.opacity(0.35), .clear],
                                   startPoint: .top, endPoint: .center)
                )
                .padding(.bottom, Spacing.m)

                Divider().padding(.horizontal, Spacing.m)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your rating").font(Typography.h3).foregroundColor(.ds.textPrimary)
                    RatingRow(rating: $game.rating)
                }
                .padding(.horizontal, Spacing.m)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Status").font(Typography.h3).foregroundColor(.ds.textPrimary)
                    Picker("Status", selection: $game.status) {
                        ForEach(PlayStatus.allCases) { st in
                            Text(st.rawValue).tag(st)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(.ds.brandRed)
                }
                .padding(.horizontal, Spacing.m)

                // Genrer – enkel horisontell “chip”-scroll
                if !game.genres.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Genres").font(Typography.h3).foregroundColor(.ds.textPrimary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(game.genres, id: \.self) { g in
                                    GSTag(g)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.horizontal, Spacing.m)
                }

                Spacer(minLength: 24)
            }
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.ds.background.ignoresSafeArea())
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Mark as Playing")   { game.status = .playing }
                    Button("Mark as Completed") { game.status = .completed }
                    Button("Mark as Abandoned") { game.status = .abandoned }
                    Button("Add to Wishlist")   { game.status = .wishlist }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .tint(.ds.brandRed)
        .toolbarBackground(Color.ds.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onChange(of: game.status) { _ in persist() }
        .onChange(of: game.rating) { _ in persist() }
        .onDisappear { persist() }
    }
}



