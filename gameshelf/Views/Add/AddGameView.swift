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

    // MARK: - Fields
    @State private var title = ""
    @State private var platform = ""
    @State private var releaseYear = Calendar.current.component(.year, from: .now)
    @State private var genresText = ""
    @State private var developer = ""
    @State private var status: PlayStatus = .wishlist
    @State private var rating: Int = 0
    @State private var coverURLString = ""
    @State private var showDuplicateAlert = false
    @State private var pendingGame: Game? = nil

    // Focus handling for nicer keyboard navigation
    @FocusState private var focusedField: Field?
    private enum Field { case title, platform, developer, genres, cover }

    // MARK: - Init with optional prefill (manual only)
    init(prefillTitle: String? = nil) {
        _title = State(initialValue: prefillTitle ?? "")
    }

    // MARK: - Validation
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPlatform: String { platform.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var normalizedCoverURL: URL? {
        let s = coverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, let url = URL(string: s) else { return nil }
        return url
    }

    var isValid: Bool {
        !trimmedTitle.isEmpty && !trimmedPlatform.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Basics
                Section {
                    Label("Basics", systemImage: "square.grid.2x2")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .title)
                        .onSubmit { focusedField = .platform }

                    TextField("Platform (e.g. Nintendo Switch)", text: $platform)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .platform)

                    Stepper(value: $releaseYear, in: 1970...2100) {
                        HStack {
                            Text("Release Year")
                            Spacer()
                            Text("\(releaseYear)")
                                .foregroundColor(.ds.textSecondary)
                        }
                    }

                    TextField("Developer (optional)", text: $developer)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .developer)
                }

                // MARK: Genres & Status
                Section {
                    Label("Genres & Status", systemImage: "tag")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("Genres (comma separated, e.g. Action, RPG)", text: $genresText)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .genres)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Status")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Picker("Status", selection: $status) {
                            ForEach(PlayStatus.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Rating")
                            Spacer()
                            Text(rating == 0 ? "–" : "\(rating)/10")
                                .foregroundColor(.ds.textSecondary)
                        }
                        Slider(value: Binding(get: { Double(rating) }, set: { rating = Int($0) }), in: 0...10, step: 1)
                    }
                }

                // MARK: Cover
                Section {
                    Label("Cover", systemImage: "photo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("Cover URL (optional)", text: $coverURLString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($focusedField, equals: .cover)

                    // Live preview of the cover if a URL is provided
                    if let url = normalizedCoverURL {
                        HStack(alignment: .top, spacing: 12) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 70, height: 94)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 70, height: 94)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                case .failure:
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.quaternary)
                                        .overlay(Image(systemName: "photo").imageScale(.large))
                                        .frame(width: 70, height: 94)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Preview")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(url.absoluteString)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }

                    Text("Paste a direct image URL if you already have one. You can change it later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    #if canImport(UIKit)
                    Button {
                        if let s = UIPasteboard.general.string { coverURLString = s }
                    } label: {
                        Label("Paste URL from clipboard", systemImage: "doc.on.clipboard")
                    }
                    .font(.callout.weight(.semibold))
                    .buttonStyle(.borderless)
                    #endif
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
            .scrollContentBackground(.hidden)
            .background(Color.ds.background)
            .tint(Color.ds.brandRed)
            .toolbarBackground(Color.ds.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .formStyle(.grouped)
            .listSectionSpacing(.compact)
            .onAppear {
                // If we came here with a prefilled title, move focus to platform for faster input
                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && platform.isEmpty {
                    focusedField = .platform
                }
            }
            .toolbar { // keyboard toolbar
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Previous") { moveFocus(previous: true) }
                    Button("Next") { moveFocus(previous: false) }
                    Button("Done") { focusedField = nil }
                }
            }
            .alert("Duplicate game", isPresented: $showDuplicateAlert) {
                Button("Cancel", role: .cancel) {
                    pendingGame = nil
                }
                Button("Add anyway", role: .destructive) {
                    if let g = pendingGame {
                        store.add(g)
                        pendingGame = nil
                        dismiss()
                    }
                }
            } message: {
                Text("A game with the same title and platform already exists in your library.")
            }
        }
    }

    private func moveFocus(previous: Bool) {
        let order: [Field] = [.title, .platform, .developer, .genres, .cover]
        guard let current = focusedField, let idx = order.firstIndex(of: current) else {
            focusedField = previous ? .cover : .title
            return
        }
        let nextIndex = previous ? max(0, idx - 1) : min(order.count - 1, idx + 1)
        focusedField = order[nextIndex]
    }

    private func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "™", with: "")
            .replacingOccurrences(of: "®", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func duplicateExists(title: String, platform: String) -> Bool {
        let t = normalize(title)
        let p = normalize(platform)
        let games = store.games
        return games.contains(where: { normalize($0.title) == t && $0.platforms.contains(where: { normalize($0) == p }) })
    }

    // MARK: - Save to store
    private func addGame() {
        let genres = genresText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let newGame = Game(
            title: trimmedTitle,
            platforms: trimmedPlatform.isEmpty ? [] : [trimmedPlatform],
            releaseYear: releaseYear,
            genres: genres,
            developers: developer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [developer.trimmingCharacters(in: .whitespacesAndNewlines)],
            status: status,
            rating: rating == 0 ? nil : rating,
            rawgRating: nil,
            coverURL: normalizedCoverURL
        )

        if duplicateExists(title: newGame.title, platform: trimmedPlatform) {
            pendingGame = newGame
            showDuplicateAlert = true
            return
        }

        store.add(newGame)
        dismiss()
    }
}
