//
//  AddGameView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-26.
//


import SwiftUI

struct AddGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: LibraryStore

    @State private var title = ""
    @State private var platform = ""
    @State private var releaseYear = Calendar.current.component(.year, from: .now)
    @State private var genresText = ""
    @State private var developer = ""
    @State private var status: PlayStatus = .wishlist
    @State private var rating: Int = 0
    @State private var coverURLString = ""
    @State private var showOnlineSearch = false
    @State private var availablePlatforms: [String] = []

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !platform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Search") {
                    Button {
                        showOnlineSearch = true
                    } label: {
                        Label("Search online…", systemImage: "globe")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Text("Use RAWG search to prefill fields.")
                        .font(Typography.footnote)
                        .foregroundColor(.ds.textSecondary)
                }
                Section("Basics") {
                    TextField("Title", text: $title)
                    if !availablePlatforms.isEmpty {
                        Picker("Platform", selection: $platform) {
                            ForEach(availablePlatforms, id: \.self) { p in
                                Text(p).tag(p)
                            }
                        }
                    } else {
                        TextField("Platform (e.g. Nintendo Switch)", text: $platform)
                    }
                    Stepper(value: $releaseYear, in: 1970...2100) {
                        HStack {
                            Text("Release Year")
                            Spacer()
                            Text("\(releaseYear)")
                                .foregroundColor(.ds.textSecondary)
                        }
                    }
                    TextField("Developer (optional)", text: $developer)
                }

                Section("Genres & Status") {
                    TextField("Genres (comma separated, e.g. Action, RPG)", text: $genresText)
                    Picker("Status", selection: $status) {
                        ForEach(PlayStatus.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    Stepper(value: $rating, in: 0...10) {
                        HStack {
                            Text("Rating")
                            Spacer()
                            Text(rating == 0 ? "–" : "\(rating)/10")
                                .foregroundColor(.ds.textSecondary)
                        }
                    }
                }

                Section("Cover") {
                    TextField("Cover URL (optional)", text: $coverURLString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Add Game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addGame() }
                        .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showOnlineSearch) {
                OnlineSearchView(onSelect: { rawg in
                    apply(rawg: rawg)
                })
                .environmentObject(store)
            }
            .scrollContentBackground(.hidden)
            .background(Color.ds.background)
            .tint(Color.ds.brandRed)
            .toolbarBackground(Color.ds.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func apply(rawg: RawgGame) {
        title = rawg.name
        availablePlatforms = rawg.platforms?.map { $0.platform.name } ?? []
        if let firstPlatform = availablePlatforms.first {
            platform = firstPlatform
        }
        if let released = rawg.released, let year = Int(released.prefix(4)) {
            releaseYear = year
        }
        let g = rawg.genres?.map { $0.name }.joined(separator: ", ") ?? ""
        if !g.isEmpty { genresText = g }
        if let dev = rawg.developers?.first?.name { developer = dev }
        if let img = rawg.background_image { coverURLString = img }
        // Map RAWG 0..5 to 0..10 suggestion (keep as-is if you prefer manual)
        if let r = rawg.rating { rating = Int((r * 2.0).rounded()) }
    }

    private func addGame() {
        let genres = genresText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let url = URL(string: coverURLString.trimmingCharacters(in: .whitespacesAndNewlines))

        let newGame = Game(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            platform: platform.trimmingCharacters(in: .whitespacesAndNewlines),
            releaseYear: releaseYear,
            genres: genres,
            developer: developer.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            rating: rating == 0 ? nil : rating,
            coverURL: url
        )

        store.add(newGame)
        dismiss()
    }
}
