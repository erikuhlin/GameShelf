//
//  GameCollectionsSheet.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

struct GameCollectionsSheet: View {
    let game: Game
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingCreateCollectionSheet = false

    var body: some View {
        NavigationStack {
            List {
                if store.collections.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Inga samlingar skapade än")
                                .font(.subheadline.bold())
                            Text("Skapa din första samling (t.ex. 🎃 Halloween, 🏆 Favoriter) för att organisera dina spel.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section("Välj samlingar") {
                        ForEach(store.collections) { collection in
                            let isInCollection = collection.gameIDs.contains(game.id)
                            Button {
                                store.toggleGame(game.id, in: collection.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isInCollection ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(isInCollection ? Color.blue : Color.secondary.opacity(0.5))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(collection.name)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)

                                        Text("\(collection.gameIDs.count) spel")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Button {
                        showingCreateCollectionSheet = true
                    } label: {
                        Label("Skapa ny samling", systemImage: "plus")
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Samlingar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showingCreateCollectionSheet) {
                CreateOrEditCollectionSheet()
            }
        }
    }
}
