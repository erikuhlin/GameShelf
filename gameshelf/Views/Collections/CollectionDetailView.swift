//
//  CollectionDetailView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

struct CollectionDetailView: View {
    let collection: GameCollection
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditSheet = false
    @State private var showingAddGamesSheet = false
    @State private var showingDeleteAlert = false
    @State private var viewStyle: ViewStyle = .list

    private var currentCollection: GameCollection {
        store.collections.first(where: { $0.id == collection.id }) ?? collection
    }

    private var games: [Game] {
        store.games(in: currentCollection)
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header med beskrivning & info
                VStack(alignment: .leading, spacing: 8) {
                    if !currentCollection.description.isEmpty {
                        Text(currentCollection.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("\(games.count) spel i samlingen")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            showingAddGamesSheet = true
                        } label: {
                            Label("Lägg till spel", systemImage: "plus")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Divider()
                    .padding(.horizontal, 16)

                // Spellista / Rutnät
                if games.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)

                        Text("Inga spel i samlingen än")
                            .font(.headline)

                        Text("Tryck på knappen nedan för att välja spel från ditt bibliotek.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            showingAddGamesSheet = true
                        } label: {
                            Label("Välj spel", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .padding(.horizontal, 24)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewStyle == .list {
                            LazyVStack(spacing: 12) {
                                ForEach(games) { game in
                                    NavigationLink(destination: GameDetailView(game: game)) {
                                        LibraryGameCardRow(game: game)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.removeGame(game.id, from: currentCollection.id)
                                        } label: {
                                            Label("Ta bort från samlingen", systemImage: "minus.circle")
                                        }
                                    }
                                }
                            }
                        } else {
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(games) { game in
                                    NavigationLink(destination: GameDetailView(game: game)) {
                                        LibraryGameGridCard(game: game)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.removeGame(game.id, from: currentCollection.id)
                                        } label: {
                                            Label("Ta bort från samlingen", systemImage: "minus.circle")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .navigationTitle(currentCollection.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 10) {
                    // Växla list / grid
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewStyle = (viewStyle == .list) ? .grid : .list
                        }
                    } label: {
                        Image(systemName: viewStyle == .list ? "square.grid.2x2" : "list.bullet")
                    }

                    // Mer-meny för samlingen
                    Menu {
                        Button {
                            showingAddGamesSheet = true
                        } label: {
                            Label("Hantera spel", systemImage: "plus.circle")
                        }

                        Button {
                            showingEditSheet = true
                        } label: {
                            Label("Redigera samling", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Ta bort samling", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddGamesSheet) {
            AddGamesToCollectionSheet(collection: currentCollection)
        }
        .sheet(isPresented: $showingEditSheet) {
            CreateOrEditCollectionSheet(existingCollection: currentCollection)
        }
        .alert("Vill du ta bort samlingen?", isPresented: $showingDeleteAlert) {
            Button("Avbryt", role: .cancel) { }
            Button("Ta bort", role: .destructive) {
                store.deleteCollection(currentCollection)
                dismiss()
            }
        } message: {
            Text("Samlingen tas bort men dina spel finns kvar i biblioteket.")
        }
    }
}
