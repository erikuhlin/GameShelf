//
//  OnlineSearchView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-26.
//


import SwiftUI

struct OnlineSearchView: View {
    // Optional selection callback. If provided, this view will call it instead of adding directly to the store.
    var onSelect: ((RawgGame) -> Void)? = nil

    init(onSelect: ((RawgGame) -> Void)? = nil) {
        self.onSelect = onSelect
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: LibraryStore

    @State private var query = ""
    @State private var results: [RawgGame] = []
    @State private var isLoading = false
    @State private var errorText: String?

    private let client = RawgClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField

                if isLoading {
                    ProgressView("Searching…").padding()
                    Spacer()
                } else if let errorText {
                    Text(errorText)
                        .foregroundStyle(.secondary)
                        .padding()
                    Spacer()
                } else if results.isEmpty {
                    VStack(spacing: 8) {
                        Text("Search for games on RAWG")
                            .font(.headline)
                        Text("Try typing a title, e.g. “Hades” or “Chrono Trigger”.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(results) { r in
                            HStack(alignment: .top, spacing: 12) {
                                let thumbURL = RawgImage.cropped3x4(from: r.background_image.flatMap(URL.init(string:)), width: 120, height: 160)
                                AsyncImage(url: thumbURL) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill().clipped()
                                    case .failure:
                                        placeholder
                                    case .empty:
                                        ProgressView()
                                    @unknown default:
                                        placeholder
                                    }
                                }
                                .frame(width: 56, height: 74)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(r.name).font(.headline).lineLimit(2)
                                    HStack(spacing: 8) {
                                        if let released = r.released {
                                            Text(String(released.prefix(4)))
                                        }
                                        if let p = r.platforms?.first?.platform.name {
                                            Text(p)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                    if let genres = r.genres, !genres.isEmpty {
                                        Text(genres.map { $0.name }.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if let onSelect {
                                    Button {
                                        onSelect(r)
                                        dismiss()
                                    } label: {
                                        Label("Use", systemImage: "arrow.down.left.circle.fill")
                                    }
                                } else {
                                    Button {
                                        let game = r.toGame()
                                        store.add(game)
                                    } label: {
                                        Label("Add", systemImage: "plus.circle.fill")
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Find Games")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var searchField: some View {
        HStack {
            TextField("Search titles…", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await runSearch() } }

            Button {
                Task { await runSearch() }
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isLoading = true
        errorText = nil
        do {
            let items = try await client.searchGames(query: q)
            results = items
        } catch RawgClient.RawgError.missingKey {
            errorText = "Missing RAWG_API_KEY in Info.plist"
            results = []
        } catch {
            errorText = "Search failed. Try again."
            results = []
        }
        isLoading = false
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(.thinMaterial)
            Image(systemName: "gamecontroller.fill").foregroundStyle(.secondary)
        }
    }
}
