//
//  CreateOrEditCollectionSheet.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import SwiftUI

struct CreateOrEditCollectionSheet: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    var existingCollection: GameCollection?

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedGameIDs: Set<UUID> = []
    @State private var showingAddGamesSheet = false

    private let suggestedEmojis = ["🎮", "🏆", "🎃", "🕹️", "🎖️", "⭐️", "⚔️", "👾", "🏎️", "👨‍👩‍👧‍👦", "💀", "🔥"]

    private var selectedGames: [Game] {
        selectedGameIDs.compactMap { id in store.games.first(where: { $0.id == id }) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Namn på samlingen") {
                    TextField("T.ex. Mina favoriter, 🎃 Halloween...", text: $name)

                    // Emoji-snabbval
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestedEmojis, id: \.self) { emoji in
                                Button {
                                    if !name.contains(emoji) {
                                        name = "\(emoji) \(name)".trimmingCharacters(in: .whitespaces)
                                    }
                                } label: {
                                    Text(emoji)
                                        .font(.title3)
                                        .padding(6)
                                        .background(Color(.tertiarySystemFill))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Beskrivning (valfritt)") {
                    TextField("Kort beskrivning av samlingen...", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Sektion under beskrivning med "+ Lägg till spel"-knapp
                Section {
                    if selectedGames.isEmpty {
                        Text("Inga spel valda än. Tryck på Lägg till spel ovan för att välja spel.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(selectedGames) { game in
                            HStack(spacing: 12) {
                                CoverView(title: game.title, url: game.coverURL, corner: 6, height: 44)
                                    .frame(width: 32, height: 44)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.title)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)

                                    HStack(spacing: 6) {
                                        StatusBadge(status: game.status)

                                        if game.releaseYear > 0 {
                                            Text(String(game.releaseYear))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                Button {
                                    selectedGameIDs.remove(game.id)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    HStack {
                        Text("\(selectedGameIDs.count) spel i samlingen")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            showingAddGamesSheet = true
                        } label: {
                            Label("Lägg till spel", systemImage: "plus")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(existingCollection == nil ? "Ny samling" : "Redigera samling")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        save()
                    }
                    .font(.headline)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingAddGamesSheet) {
                AddGamesToCollectionSheet(selectedGameIDs: $selectedGameIDs)
            }
            .onAppear {
                if let existing = existingCollection {
                    name = existing.name
                    description = existing.description
                    selectedGameIDs = Set(existing.gameIDs)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if var existing = existingCollection {
            existing.name = trimmed
            existing.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.gameIDs = Array(selectedGameIDs)
            store.updateCollection(existing)
        } else {
            store.createCollection(
                name: trimmed,
                description: description,
                initialGameIDs: Array(selectedGameIDs)
            )
        }
        dismiss()
    }
}
