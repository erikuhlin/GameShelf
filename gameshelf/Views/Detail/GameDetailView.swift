//
//  GameDetailView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI
import Combine

struct GameDetailView: View {
    @EnvironmentObject var store: LibraryStore

    enum Mode: Equatable {
        case local(Game)
        case rawg(id: Int)
    }

    // Back-compat: existing code may construct with `GameDetailView(game:)`
    // Keep this init so current call sites continue to work.
    init(game: Game) { self._mode = State(initialValue: .local(game)) }
    // New initializer for opening from Explore/RAWG
    init(rawgID: Int) { self._mode = State(initialValue: .rawg(id: rawgID)) }

    @State private var mode: Mode

    // Local editable state
    @State private var game: Game? = nil

    // Online detail state
    @State private var remote: DetailRawgDetail? = nil
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var suggestions: [SuggestedRawgGame] = []
    @State private var suggestionsLoading = false
    @State private var triedAutoLookup = false

    // Notes (persisted via UserDefaults using stable key)
    @State private var notes: String = ""

    private let nilString: String = ""

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Group {
                if let g = game { // Local game detail
                    localDetail(g)
                } else if let r = remote { // Online RAWG detail
                    onlineDetail(r)
                } else if isLoading {
                    ProgressView("Loading…")
                } else if let e = error {
                    ContentUnavailableView("Couldn’t load game", systemImage: "exclamationmark.triangle", description: Text(e))
                } else {
                    EmptyView()
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarContent }
            .tint(.ds.brandRed)
        }
        .onAppear { configureInitialState() }
        .onChange(of: mode) { _ in configureInitialState() }
        .onChange(of: notes) { _ in saveNotes() }
    }

    // MARK: - Subviews
    private func headerImage(_ title: String, url: URL?) -> some View {
        CoverView(title: title, url: url, corner: 0, height: 320, fitMode: .fill, fullWidth: true)
            .overlay(
                LinearGradient(colors: [Color.black.opacity(0.35), .clear], startPoint: .top, endPoint: .center)
            )
            .ignoresSafeArea(edges: .top)
            .padding(.bottom, Spacing.m)
    }

    @ViewBuilder
    private func onlineExtras(_ r: DetailRawgDetail) -> some View {
        // Scores chips
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let rating = r.rating {
                    Label("RAWG \(String(format: "%.1f", rating))", systemImage: "star.fill")
                        .font(.subheadline)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.black.opacity(0.06))
                        .clipShape(Capsule())
                }
                if let mc = r.metacritic {
                    Label("Metacritic \(mc)", systemImage: "m.circle")
                        .font(.subheadline)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.black.opacity(0.06))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, Spacing.m)

        // Links
        HStack(spacing: 12) {
            if let site = r.website, let url = URL(string: site) {
                Link(destination: url) { Label("Website", systemImage: "safari") }
            }
            if let url = URL(string: "https://rawg.io/games/\(r.slug)") {
                Link(destination: url) { Label("Open on RAWG", systemImage: "link") }
            }
            if let mcu = r.metacritic_url, let url = URL(string: mcu) {
                Link(destination: url) { Label("Metacritic", systemImage: "m.circle") }
            }
        }
        .padding(.horizontal, Spacing.m)

        // Similar games
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Similar games").font(Typography.h3).foregroundColor(.ds.textPrimary); Spacer() }
            if suggestionsLoading {
                ProgressView().padding(.vertical, 8)
            } else if suggestions.isEmpty {
                Text("No suggestions available").font(.footnote).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(suggestions) { s in
                            Button {
                                withAnimation { self.mode = .rawg(id: s.id) }
                                Task { await loadRemote(id: s.id) }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    CoverView(title: s.name, url: URL(string: s.background_image ?? nilString), corner: 12, height: 140)
                                    Text(s.name)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                    if let r = s.rating {
                                        HStack(spacing: 2) {
                                            ForEach(0..<5) { i in
                                                Image(systemName: r >= Double(i+1) ? "star.fill" : (r > Double(i) ? "star.leadinghalf.filled" : "star"))
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 180)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.m)
    }

    @ViewBuilder
    private func localDetail(_ g: Game) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerImage(g.title, url: g.coverURL)

                Divider().padding(.horizontal, Spacing.m)

                // Your rating
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your rating").font(Typography.h3).foregroundColor(.ds.textPrimary)
                    RatingRow(rating: Binding(get: { g.rating }, set: { new in
                        var copy = g
                        copy.rating = new
                        updateLocal(copy)
                    }))
                }
                .padding(.horizontal, Spacing.m)

                // Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Status").font(Typography.h3).foregroundColor(.ds.textPrimary)
                    Picker("Status", selection: Binding(get: { g.status }, set: { new in
                        var copy = g
                        copy.status = new
                        updateLocal(copy)
                    })) {
                        ForEach(PlayStatus.allCases) { st in
                            Text(st.rawValue).tag(st)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(.ds.brandRed)
                }
                .padding(.horizontal, Spacing.m)

                // Genres
                if !g.genres.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Genres").font(Typography.h3).foregroundColor(.ds.textPrimary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack { ForEach(g.genres, id: \.self) { GSTag($0) } }
                                .padding(.vertical, 2)
                        }
                    }
                    .padding(.horizontal, Spacing.m)
                }

                // Notes
                notesBlock()

                // Online enrichment for saved games (if we could resolve it on RAWG)
                if let r = remote {
                    Divider().padding(.horizontal, Spacing.m)
                    Text("Online info").font(Typography.h3).foregroundColor(.ds.textPrimary)
                        .padding(.horizontal, Spacing.m)
                    onlineExtras(r)
                }

                Spacer(minLength: 24)
            }
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.ds.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func onlineDetail(_ r: DetailRawgDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Robust header-URL med normalize:
                let headerURL: URL? = {
                    if let u = RawgImage.normalize(from: r.background_image, width: 1200) {
                        return u
                    }
                    if let s = r.background_image, let u = URL(string: s) {
                        return u
                    }
                    return nil
                }()
                headerImage(r.name, url: headerURL)

                // Meta
                VStack(alignment: .leading, spacing: 8) {
                    if let released = r.released, !released.isEmpty {
                        Text("Released: \(released)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let plats = r.platforms?.compactMap({ $0.platform?.name }).joined(separator: ", "), !plats.isEmpty {
                        Text(plats).font(.callout).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Spacing.m)

                if let raw = r.description_raw, !raw.isEmpty {
                    Text(raw).font(.body).padding(.horizontal, Spacing.m)
                }

                // Notes (allow jotting before adding)
                notesBlock()

                // Add to library
                HStack {
                    Button {
                        addRemoteToLibrary(r)
                    } label: {
                        Label("Add to Library", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.ds.brandRed)
                }
                .padding(.horizontal, Spacing.m)

                onlineExtras(r)

                Spacer(minLength: 24)
            }
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.ds.background.ignoresSafeArea())
    }
    private func ensureRemoteForLocal(_ g: Game) async {
        // Only try once per appearance to avoid loops
        if triedAutoLookup { return }
        triedAutoLookup = true
        guard remote == nil else { return }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "RAWG_API_KEY") as? String, !key.isEmpty else { return }

        var comps = URLComponents(string: "https://api.rawg.io/api/games")!
        var q: [URLQueryItem] = [
            .init(name: "key", value: key),
            .init(name: "search", value: g.title),
            .init(name: "search_precise", value: "true"),
            .init(name: "page_size", value: "1")
        ]
        if g.releaseYear > 0 {
            q.append(.init(name: "dates", value: "\(g.releaseYear)-01-01,\(g.releaseYear)-12-31"))
        }
        comps.queryItems = q
        do {
            let (data, _) = try await URLSession.shared.data(from: comps.url!)
            let res = try JSONDecoder().decode(DetailSearchResponse.self, from: data)
            if let first = res.results.first {
                await loadRemote(id: first.id)
            }
        } catch {
            // Silent fail: leave remote nil if we can't resolve
        }
    }

    @ViewBuilder
    private func notesBlock() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(Typography.h3).foregroundColor(.ds.textPrimary)
            ZStack(alignment: .topLeading) {
                if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Write a note…")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: $notes)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(Color.ds.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, Spacing.m)
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                switch mode {
                case .local(let g):
                    Button("Mark as Playing")   { updateStatus(.playing, for: g) }
                    Button("Mark as Completed") { updateStatus(.completed, for: g) }
                    Button("Mark as Abandoned") { updateStatus(.abandoned, for: g) }
                    Button("Add to Wishlist")   { updateStatus(.wishlist, for: g) }
                case .rawg:
                    Button("Add to Library") { if let r = remote { addRemoteToLibrary(r) } }
                }
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }

    // MARK: - Lifecycle/helpers
    private func configureInitialState() {
        switch mode {
        case .local(let g):
            self.game = g
            self.remote = nil
            self.isLoading = false
            self.error = nil
            self.suggestions = []
            self.suggestionsLoading = false
            self.notes = loadNotes()
            Task { await ensureRemoteForLocal(g) }
        case .rawg(let id):
            self.game = nil
            self.remote = nil
            self.error = nil
            self.suggestions = []
            self.suggestionsLoading = false
            self.notes = loadNotes() // Allow notes even before adding
            Task { await loadRemote(id: id) }
        }
    }

    private func updateLocal(_ updated: Game) {
        self.game = updated
        if let idx = store.games.firstIndex(where: { $0.id == updated.id }) {
            store.games[idx] = updated
        }
        // keep notes persisted separately
    }

    private func updateStatus(_ status: PlayStatus, for g: Game) {
        var copy = g
        copy.status = status
        updateLocal(copy)
    }

    private func loadRemote(id: Int) async {
        isLoading = true; defer { isLoading = false }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "RAWG_API_KEY") as? String, !key.isEmpty else {
            error = "Missing RAWG_API_KEY"; return
        }
        var comps = URLComponents(string: "https://api.rawg.io/api/games/\(id)")!
        comps.queryItems = [.init(name: "key", value: key)]
        do {
            let (data, _) = try await URLSession.shared.data(from: comps.url!)
            let d = try JSONDecoder().decode(DetailRawgDetail.self, from: data)
            self.remote = d

            // Fetch suggested games
            self.suggestionsLoading = true
            var sg = URLComponents(string: "https://api.rawg.io/api/games/\(id)/suggested")!
            sg.queryItems = [ .init(name: "key", value: key), .init(name: "page_size", value: "12") ]
            do {
                let (sdata, _) = try await URLSession.shared.data(from: sg.url!)
                let s = try JSONDecoder().decode(SuggestedRawgResponse.self, from: sdata)
                self.suggestions = s.results
            } catch {
                self.suggestions = []
            }
            self.suggestionsLoading = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func addRemoteToLibrary(_ d: DetailRawgDetail) {
        // Skapa en lokal Game från RAWG-detail
        let cover: URL? = {
            if let normalized = RawgImage.normalize(from: d.background_image, width: 600) {
                return normalized
            }
            if let s = d.background_image, let u = URL(string: s) {
                return u
            }
            return nil
        }()
        let genres = d.genres?.compactMap { $0.name } ?? []
        let platforms = d.platforms?.compactMap { $0.platform?.name } ?? []
        let devs = d.developers?.map { $0.name } ?? []
        let release = (d.released.flatMap { Int($0.prefix(4)) }) ?? 0

        let new = Game(
            title: d.name,
            platforms: platforms,
            releaseYear: release,
            genres: genres,
            developers: devs,
            status: .wishlist,
            rating: 0,
            rawgRating: d.rating,
            coverURL: cover
        )
        store.add(new)
        // Switch to local mode so status/rating UI becomes active
        self.mode = .local(new)
        self.game = new
    }

    // MARK: - Notes persistence
    private func notesKey() -> String {
        switch mode {
        case .local(let g): return "notes.\(g.id.uuidString)"
        case .rawg(let id): return "notes.rawg.\(id)"
        }
    }
    private func loadNotes() -> String {
        UserDefaults.standard.string(forKey: notesKey()) ?? ""
    }
    private func saveNotes() {
        UserDefaults.standard.set(notes, forKey: notesKey())
    }
}

// MARK: - RAWG detail models (scoped)
private struct DetailRawgDetail: Decodable {
    let id: Int
    let slug: String
    let name: String
    let background_image: String?
    let description_raw: String?
    let released: String?
    let rating: Double?
    let metacritic: Int?
    let metacritic_url: String?
    let platforms: [DetailRawgGamePlatform]?
    let website: String?
    let genres: [DetailRawgNamed]?
    let developers: [DetailRawgNamed]?
}
private struct DetailRawgGamePlatform: Decodable { let platform: DetailRawgPlatform? }
private struct DetailRawgPlatform: Decodable { let id: Int; let name: String }
private struct DetailRawgNamed: Decodable { let name: String }

private struct SuggestedRawgResponse: Decodable {
    let results: [SuggestedRawgGame]
}
private struct SuggestedRawgGame: Decodable, Identifiable {
    let id: Int
    let name: String
    let background_image: String?
    let rating: Double?
}

// Helper for RAWG search response
private struct DetailSearchResponse: Decodable {
    let results: [DetailSearchResult]
}
private struct DetailSearchResult: Decodable {
    let id: Int
}
