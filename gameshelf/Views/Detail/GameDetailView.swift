// GameDetailView.swift
// gameshelf

import SwiftUI
import WebKit
import SafariServices

struct GameDetailView: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    enum Mode: Equatable {
        case local(Game)
        case igdb(id: Int)

        static func == (lhs: GameDetailView.Mode, rhs: GameDetailView.Mode) -> Bool {
            switch (lhs, rhs) {
            case (.local(let a), .local(let b)): return a.id == b.id
            case (.igdb(let a), .igdb(let b)): return a == b
            default: return false
            }
        }
    }

    enum RemoteDataState: Equatable {
        case idle
        case loading
        case loaded(IGDBGame)
        case error(String)

        static func == (lhs: RemoteDataState, rhs: RemoteDataState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.loading, .loading): return true
            case (.loaded(let a), .loaded(let b)): return a.id == b.id
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    init(game: Game) {
        self._mode = State(initialValue: .local(game))
        print("[GameDetailView] Initialized with local Game: '\(game.title)' (ID: \(game.id), igdbID: \(game.igdbID?.description ?? "nil"))")
    }

    init(igdbID: Int) {
        self._mode = State(initialValue: .igdb(id: igdbID))
        print("[GameDetailView] Initialized with IGDB ID: \(igdbID)")
    }

    @State private var mode: Mode
    @State private var remoteState: RemoteDataState = .idle

    // Klickbar bildindex för fullskärmsgalleri (Etapp 2)
    @State private var selectedScreenshotIndex: Int? = nil
    @State private var showingFullSummary = false
    @State private var showingTrailersSheet = false
    @State private var showingSimilarGamesSheet = false
    @State private var showingLibraryStatusSheet = false
    @State private var showingCollectionsSheet = false
    @State private var selectedVideo: IGDBVideo? = nil

    @FocusState private var isNotesFocused: Bool
    @State private var newTodoText: String = ""

    private var remote: IGDBGame? {
        if case .loaded(let g) = remoteState { return g }
        return nil
    }

    private var isLoadingRemote: Bool {
        if case .loading = remoteState { return true }
        return false
    }

    private var remoteErrorMessage: String? {
        if case .error(let msg) = remoteState { return msg }
        return nil
    }

    private var currentGame: Game? {
        switch mode {
        case .local(let initialGame):
            return store.games.first(where: { $0.id == initialGame.id }) ?? initialGame
        case .igdb(let id):
            return store.games.first(where: { $0.igdbID == id })
        }
    }

    private var effectiveReleaseDate: Date? {
        if let ts = remote?.firstReleaseDate {
            return Date(timeIntervalSince1970: TimeInterval(ts))
        }
        if let ts = currentGame?.firstReleaseDate {
            return Date(timeIntervalSince1970: TimeInterval(ts))
        }
        return nil
    }

    private var effectiveReleaseYear: Int? {
        return currentGame?.releaseYear ?? remote?.releaseYear
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // --- 1. HERO HEADER ---
                heroHeader

                // --- NEDRÄKNING FÖR KOMMANDE SPEL ---
                ReleaseCountdownBanner(
                    releaseDate: effectiveReleaseDate,
                    releaseYear: effectiveReleaseYear
                )

                // --- 2. LÄGG TILL KNAPP (Om spelet inte finns i biblioteket) ---
                libraryStatusSection

                // --- 3. DITT BETYG & STATUS (Om spelet finns i biblioteket) ---
                if let g = currentGame {
                    localGameControls(g)
                }

                // --- HUVUDINNEHÅLL ELLER FEL / LADDNING ---
                if currentGame == nil && remote == nil {
                    // Kom in via igdbID och saknar lokalt spel samt har inte lyckats hämta remote ännu
                    if isLoadingRemote {
                        VStack(spacing: 12) {
                            ProgressView("Hämtar speldetaljer...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                    } else if let errorMsg = remoteErrorMessage {
                        remoteErrorCard(message: errorMsg)
                    }
                } else {
                    // Vi har antingen currentGame (lokalt spel) eller remote (inläst IGDBGame)
                    if isLoadingRemote && currentGame != nil {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Hämtar utökad spelinformation...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else if let errorMsg = remoteErrorMessage, currentGame != nil {
                        inlineErrorCard(message: errorMsg)
                    }

                    // --- 4. BILDGALLERI (Skärmdumpar) ---
                    if let screenshots = remote?.screenshots, !screenshots.isEmpty {
                        screenshotsSection(screenshots)
                    }

                    // --- 5. HANDLING / OM SPELET ---
                    aboutGameSection

                    // --- 6. SPELTID (HowLongToBeat) ---
                    timeToBeatSection(remote?.timeToBeat)

                    // --- 7. STUDIO & UTGIVARE ---
                    studioSection

                    // --- 8. FAKTA & BETYG ---
                    factsSection

                    // --- 8. TRAILERS ---
                    if let videos = remote?.videos, !videos.isEmpty {
                        trailersSection(videos)
                    }

                    // --- 9. LIKNANDE SPEL ---
                    if let similar = remote?.similarGames, !similar.isEmpty {
                        similarGamesSection(similar)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .onTapGesture {
            isNotesFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .toolbar { toolbarContent }
        .onAppear { configureInitialState() }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { selectedScreenshotIndex != nil },
            set: { if !$0 { selectedScreenshotIndex = nil } }
        )) {
            if let screenshots = remote?.screenshots, let initialIdx = selectedScreenshotIndex {
                FullscreenGalleryView(screenshots: screenshots, initialIndex: initialIdx)
            }
        }
        .sheet(isPresented: $showingTrailersSheet) {
            if let videos = remote?.videos {
                TrailersSheetView(videos: videos, onSelectVideo: { video in
                    showingTrailersSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedVideo = video
                    }
                })
            }
        }
        .fullScreenCover(item: $selectedVideo) { video in
            if let url = video.youtubeURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showingSimilarGamesSheet) {
            if let similar = remote?.similarGames {
                SimilarGamesSheetView(games: similar)
            }
        }
        .sheet(isPresented: $showingLibraryStatusSheet) {
            LibraryStatusSheetView(
                title: currentGame?.title ?? remote?.name ?? "Spel",
                coverURL: currentGame?.coverURL ?? remote?.coverURL,
                isInLibrary: currentGame != nil,
                onAdd: {
                    if let r = remote { addRemoteToLibrary(r) }
                },
                onRemove: {
                    if let g = currentGame {
                        store.games.removeAll(where: { $0.id == g.id })
                    }
                }
            )
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showingCollectionsSheet) {
            if let g = currentGame {
                GameCollectionsSheet(game: g)
            }
        }
    }

    // MARK: - Subviews

    private var heroHeader: some View {
        let title: String = {
            if let localTitle = currentGame?.title, !localTitle.isEmpty {
                return localTitle
            }
            if let remoteName = remote?.name, !remoteName.isEmpty {
                return remoteName
            }
            if isLoadingRemote {
                return "Läser in..."
            }
            return "Speldetaljer"
        }()

        let year = currentGame?.releaseYear ?? remote?.releaseYear
        let coverURL = currentGame?.coverURL ?? remote?.coverURL
        let genresList = currentGame?.genres.isEmpty == false ? currentGame?.genres : remote?.genres?.map(\.name)
        let genresText = genresList?.prefix(2).joined(separator: ", ")

        let playerRating: Int? = {
            if let tr = remote?.totalRating { return Int(round(tr)) }
            if let ir = currentGame?.igdbRating { return Int(round(ir * 10)) }
            if let r = currentGame?.rating { return r * 10 }
            return nil
        }()

        let criticRating: Int? = {
            if let cr = remote?.aggregatedRating { return Int(round(cr)) }
            return nil
        }()

        let developer = remote?.developerName ?? currentGame?.developers.first
        let publisher = remote?.publisherName

        return VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                // Vänster: Omslagsbild (Poster)
                CoverView(title: title, url: coverURL, corner: 10, height: 160)
                    .frame(width: 110)
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)

                // Höger: Information & Betyg
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    // Betyg (Spelare / Kritiker)
                    if playerRating != nil || criticRating != nil {
                        HStack(spacing: 14) {
                            if let pRating = playerRating {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.red)
                                        .font(.subheadline)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("\(pRating)/100")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                        Text("Spelare")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            if let cRating = criticRating {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.red)
                                        .font(.subheadline)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("\(cRating)/100")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                        Text("Kritiker")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    // År & Genrer
                    HStack(spacing: 6) {
                        if let year = year, year > 0 {
                            Text(String(year))
                        }
                        if let year = year, year > 0, let gText = genresText, !gText.isEmpty {
                            Text("•")
                        }
                        if let gText = genresText, !gText.isEmpty {
                            Text(gText)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    // Utvecklare
                    if let dev = developer, !dev.isEmpty {
                        HStack(spacing: 4) {
                            Text("Utvecklare")
                                .foregroundStyle(.secondary)
                            Text(dev)
                                .fontWeight(.medium)
                                .foregroundStyle(.red)
                        }
                        .font(.caption)
                        .lineLimit(1)
                    }

                    // Utgivare
                    if let pub = publisher, !pub.isEmpty {
                        HStack(spacing: 4) {
                            Text("Utgivare")
                                .foregroundStyle(.secondary)
                            Text(pub)
                                .fontWeight(.medium)
                                .foregroundStyle(.red)
                        }
                        .font(.caption)
                        .lineLimit(1)
                    }

                    // PEGI / ESRB åldersmärkningar
                    if let ageLabels = remote?.ageRatings?.compactMap({ $0.label }), !ageLabels.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(ageLabels, id: \.self) { label in
                                Text(label)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var libraryStatusSection: some View {
        if let g = currentGame {
            HStack(spacing: 10) {
                // 1. Biblioteksknapp
                Button {
                    showingLibraryStatusSheet = true
                } label: {
                    Label("I ditt bibliotek", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                // 2. Plattformsvalsknapp (Menu)
                Menu {
                    Section("Ägd plattform") {
                        ForEach(availablePlatforms(for: g), id: \.self) { platform in
                            Button {
                                togglePlatform(platform, for: g)
                            } label: {
                                if g.platforms.contains(platform) {
                                    Label(platform, systemImage: "checkmark")
                                } else {
                                    Text(platform)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.subheadline)
                            .foregroundStyle(.blue)

                        if let first = g.platforms.first, !first.isEmpty {
                            Text(shortPlatformName(first) + (g.platforms.count > 1 ? " (+\(g.platforms.count - 1))" : ""))
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        } else {
                            Text("Plattform")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        } else if let r = remote {
            Button {
                showingLibraryStatusSheet = true
            } label: {
                Label("Lägg till i biblioteket", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }

    private func localGameControls(_ g: Game) -> some View {
        VStack(spacing: 16) {
            // Status och Ditt betyg sida vid sida för kompakt och ren layout
            HStack(spacing: 12) {
                // 1. Statuskort
                VStack(alignment: .leading, spacing: 10) {
                    Text("Status")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Menu {
                        Picker("Status", selection: Binding<PlayStatus>(
                            get: { g.status },
                            set: { newStatus in
                                var copy = g
                                copy.status = newStatus
                                updateLocal(copy)
                            }
                        )) {
                            ForEach(PlayStatus.allCases) { st in
                                Label(st.rawValue, systemImage: st.icon).tag(st)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            StatusBadge(status: g.status)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // 2. Betygskort
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ditt betyg")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Menu {
                        Section("Sätt betyg (1–10)") {
                            Button("Rensa betyg", role: .destructive) {
                                var copy = g
                                copy.rating = nil
                                updateLocal(copy)
                            }
                            ForEach((1...10).reversed(), id: \.self) { r in
                                Button {
                                    var copy = g
                                    copy.rating = r
                                    updateLocal(copy)
                                } label: {
                                    HStack {
                                        Text("\(r) / 10")
                                        if g.rating == r {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: (g.rating ?? 0) > 0 ? "star.fill" : "star")
                                .font(.subheadline.bold())
                                .foregroundStyle(.yellow)

                            if let r = g.rating, r > 0 {
                                Text("\(r)/10")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Sätt betyg")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Ägarskap (I min ägo vs Spelminne)
            ownershipCard(g)

            // Samlingar
            collectionsCard(g)

            notesCard(g)
        }
    }

    private func ownershipCard(_ g: Game) -> some View {
        HStack(spacing: 12) {
            Image(systemName: g.isOwned ? "gamecontroller.fill" : "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(g.isOwned ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(g.isOwned ? "I min ägo" : "Spelminne / Historik")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(g.isOwned ? "Finns i din aktiva spelsamling" : "Tidigare spelat spel i ditt arkiv")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding<Bool>(
                get: { g.isOwned },
                set: { newOwned in
                    var copy = g
                    copy.isOwned = newOwned
                    updateLocal(copy)
                }
            ))
            .labelsHidden()
            .tint(.green)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func collectionsCard(_ g: Game) -> some View {
        let gameCols = store.collections(for: g.id)
        return detailCard(title: "Samlingar") {
            VStack(alignment: .leading, spacing: 10) {
                if gameCols.isEmpty {
                    HStack {
                        Text("Inga samlingar valda")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            showingCollectionsSheet = true
                        } label: {
                            Label("Lägg till", systemImage: "plus")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                } else {
                    HStack(spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(gameCols) { col in
                                    Text(col.name)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(.tertiarySystemFill))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        Button {
                            showingCollectionsSheet = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    private func availablePlatforms(for g: Game) -> [String] {
        var result: [String] = []
        if let remotePlatforms = remote?.platforms?.map(\.name) {
            result.append(contentsOf: remotePlatforms)
        }
        result.append(contentsOf: g.platforms)

        if result.isEmpty {
            result = ["PlayStation 5", "PlayStation 4", "Nintendo Switch", "PC (Windows)", "Xbox Series X|S", "Xbox One"]
        }

        var seen = Set<String>()
        return result.filter { seen.insert($0).inserted }
    }

    private func togglePlatform(_ platform: String, for g: Game) {
        var copy = g
        if copy.platforms.contains(platform) {
            copy.platforms.removeAll(where: { $0 == platform })
        } else {
            copy.platforms.append(platform)
        }
        updateLocal(copy)
    }

    private func shortPlatformName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("playstation 5") || lower == "ps5" { return "PlayStation 5" }
        if lower.contains("playstation 4") || lower == "ps4" { return "PlayStation 4" }
        if lower.contains("playstation 3") || lower == "ps3" { return "PlayStation 3" }
        if lower.contains("switch") { return "Nintendo Switch" }
        if lower.contains("series x") || lower.contains("series s") || lower.contains("xbox series") { return "Xbox Series X|S" }
        if lower.contains("xbox one") { return "Xbox One" }
        if lower.contains("xbox") { return "Xbox" }
        if lower.contains("pc") || lower.contains("windows") { return "PC" }
        if lower.contains("mac") { return "Mac" }
        if lower.contains("ios") || lower.contains("iphone") || lower.contains("ipad") { return "iOS" }
        if lower.contains("android") { return "Android" }
        return name
    }

    private func notesCard(_ g: Game) -> some View {
        detailCard(title: "Anteckningar & Checklista") {
            VStack(alignment: .leading, spacing: 14) {
                // Anteckningsfält (TextEditor)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mina anteckningar")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    TextEditor(text: Binding<String>(
                        get: { g.notes },
                        set: { newNotes in
                            var copy = g
                            copy.notes = newNotes
                            updateLocal(copy)
                        }
                    ))
                    .focused($isNotesFocused)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Divider()

                // Checklista / Att göra-lista
                VStack(alignment: .leading, spacing: 10) {
                    Text("Checklista / Mål")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    // Lägg till ny punktrad
                    HStack(spacing: 8) {
                        TextField("Ny punktrad (t.ex. Klara DLC)...", text: $newTodoText)
                            .focused($isNotesFocused)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .onSubmit {
                                addTodoItem(to: g)
                            }

                        Button {
                            addTodoItem(to: g)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .red)
                        }
                        .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    // Befintliga punkter
                    if !g.todos.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(Array(g.todos.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 10) {
                                    Button {
                                        var copy = g
                                        copy.todos[index].isDone.toggle()
                                        updateLocal(copy)
                                    } label: {
                                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                            .font(.body)
                                            .foregroundStyle(item.isDone ? .green : .secondary)
                                    }

                                    Text(item.title)
                                        .font(.subheadline)
                                        .foregroundStyle(item.isDone ? .secondary : .primary)
                                        .strikethrough(item.isDone, color: .secondary)

                                    Spacer()

                                    Button {
                                        var copy = g
                                        copy.todos.remove(at: index)
                                        updateLocal(copy)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(.tertiarySystemGroupedBackground).opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private func addTodoItem(to g: Game) {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var copy = g
        copy.todos.append(GameTodoItem(title: trimmed))
        updateLocal(copy)
        newTodoText = ""
    }

    private func screenshotsSection(_ screenshots: [IGDBImage]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Skärmdumpar")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !screenshots.isEmpty {
                    selectedScreenshotIndex = 0
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(screenshots.enumerated()), id: \.element.id) { index, img in
                        if let url = img.url(size: "t_screenshot_big") {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 200, height: 115)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedScreenshotIndex = index
                                        }
                                } else {
                                    Color(.tertiarySystemFill)
                                        .frame(width: 200, height: 115)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                    }
                }
            }

            // Indikatorprickar (. . . . .)
            if screenshots.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<min(screenshots.count, 6), id: \.self) { idx in
                        Circle()
                            .fill(idx == 0 ? Color.red : Color.secondary.opacity(0.3))
                            .frame(width: idx == 0 ? 7 : 5, height: idx == 0 ? 7 : 5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
            }
        }
    }

    private var summaryText: String? {
        if let s = remote?.summary, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return s
        }
        if let notes = currentGame?.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return notes
        }
        return nil
    }

    @ViewBuilder
    private var aboutGameSection: some View {
        let textToShow = summaryText
        let isTextAvailable = textToShow != nil

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Om spelet")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    showingFullSummary.toggle()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if isTextAvailable, let text = textToShow {
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(showingFullSummary ? nil : 3)
                        .lineSpacing(3)

                    if !showingFullSummary && text.count > 120 {
                        Button {
                            withAnimation {
                                showingFullSummary = true
                            }
                        } label: {
                            Text("mer")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)
                        }
                    }
                } else if isLoadingRemote {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Hämtar beskrivning...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("Ingen beskrivning tillgänglig för detta spel ännu.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func timeToBeatSection(_ ttb: IGDBTimeToBeat?) -> some View {
        let title = currentGame?.title ?? remote?.name ?? "Spel"
        let genres = currentGame?.genres ?? remote?.genres?.map(\.name) ?? []
        let gameModes = remote?.gameModes?.map(\.name) ?? []

        let isMultiplayerOnly = isPureMultiplayer(gameModes: gameModes, gameTitle: title, genres: genres)

        let mainStr: String
        let extraStr: String
        let compStr: String

        if isMultiplayerOnly {
            mainStr = "—"
            extraStr = "—"
            compStr = "—"
        } else if let ttb = ttb, (ttb.hastily ?? 0 > 0 || ttb.normally ?? 0 > 0 || ttb.completely ?? 0 > 0) {
            mainStr = ttb.mainStoryFormatted
            extraStr = ttb.mainExtraFormatted
            compStr = ttb.completionistFormatted
        } else {
            mainStr = "—"
            extraStr = "—"
            compStr = "—"
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Speltid")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if isMultiplayerOnly {
                    Text("Flerspelarspel")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 10) {
                timeCard(icon: "book.fill", title: "Main Story", value: mainStr)
                timeCard(icon: "plus.square.fill", title: "Main + Extra", value: extraStr)
                timeCard(icon: "trophy.fill", title: "100%", value: compStr)
            }
        }
    }

    private func isPureMultiplayer(gameModes: [String], gameTitle: String, genres: [String]) -> Bool {
        let lowerModes = gameModes.map { $0.lowercased() }
        let lowerTitle = gameTitle.lowercased()
        let lowerGenres = genres.map { $0.lowercased() }

        // Kända renodlade flerspelarspel utan storykampanj
        let pureMultiplayerKeywords = [
            "hell let loose", "counter-strike", "cs:go", "cs2", "overwatch", "valorant",
            "league of legends", "dota", "apex legends", "pubg", "rainbow six siege",
            "rocket league", "fall guys", "dead by daylight", "team fortress", "world of tanks",
            "war thunder", "battlefield 2042", "sea of thieves", "rust", "dayz"
        ]

        if pureMultiplayerKeywords.contains(where: { lowerTitle.contains($0) }) {
            return true
        }

        // Om spelet har Single player i gameModes har det en story/kampanj
        if lowerModes.contains(where: { $0.contains("single player") || $0.contains("single-player") || $0.contains("ensamspelare") }) {
            return false
        }

        // Om det enbart har Multiplayer / Co-op / MMO utan Single player
        if !lowerModes.isEmpty && lowerModes.contains(where: { $0.contains("multiplayer") || $0.contains("co-operative") || $0.contains("mmo") }) {
            return true
        }

        if lowerGenres.contains(where: { $0.contains("moba") || $0.contains("card") }) && !lowerModes.contains(where: { $0.contains("single") }) {
            return true
        }

        return false
    }

    private func timeCard(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.red)

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var studioSection: some View {
        let dev = remote?.developerName ?? currentGame?.developers.first
        let pub = remote?.publisherName

        if (dev != nil && !dev!.isEmpty) || (pub != nil && !pub!.isEmpty) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Studio & utgivare")
                    .font(.headline)
                    .foregroundStyle(.primary)

                VStack(spacing: 0) {
                    if let dev = dev, !dev.isEmpty {
                        HStack {
                            Text("Utvecklare")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(dev)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.red)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                    }

                    if (dev != nil && !dev!.isEmpty) && (pub != nil && !pub!.isEmpty) {
                        Divider()
                            .padding(.leading, 14)
                    }

                    if let pub = pub, !pub.isEmpty {
                        HStack {
                            Text("Utgivare")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(pub)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.red)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var factsSection: some View {
        if let r = remote {
            factsCard(r)
        } else if let g = currentGame {
            localFactsCard(g)
        }
    }

    private func localFactsCard(_ g: Game) -> some View {
        detailCard(title: "Fakta & Betyg") {
            VStack(alignment: .leading, spacing: 12) {
                if let rating = g.igdbRating {
                    HStack {
                        Text("IGDB Betyg")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label("\(String(format: "%.1f", rating)) / 10", systemImage: "star.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.yellow)
                    }
                }

                if !g.genres.isEmpty {
                    if g.igdbRating != nil { Divider() }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Genrer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(g.genres.joined(separator: ", "))
                            .font(.subheadline)
                    }
                }

                if !g.platforms.isEmpty {
                    if g.igdbRating != nil || !g.genres.isEmpty { Divider() }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plattformar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(g.platforms.joined(separator: ", "))
                            .font(.subheadline)
                    }
                }

                if !g.developers.isEmpty {
                    if g.igdbRating != nil || !g.genres.isEmpty || !g.platforms.isEmpty { Divider() }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Utvecklare")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(g.developers.joined(separator: ", "))
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private func factsCard(_ r: IGDBGame) -> some View {
        detailCard(title: "Fakta & Betyg") {
            VStack(alignment: .leading, spacing: 12) {
                if let rating = r.totalRating {
                    HStack {
                        Text("IGDB Betyg")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label("\(String(format: "%.1f", rating / 10.0)) / 10", systemImage: "star.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.yellow)
                    }
                }

                if let critic = r.aggregatedRating {
                    Divider()
                    HStack {
                        Text("Kritikerbetyg")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(critic))/100")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                }

                if let genres = r.genres?.map({ $0.name }).joined(separator: ", "), !genres.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Genrer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(genres)
                            .font(.subheadline)
                    }
                }

                if let plats = r.platforms?.map({ $0.name }).joined(separator: ", "), !plats.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plattformar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(plats)
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private func trailersSection(_ videos: [IGDBVideo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trailers & videor")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingTrailersSheet = true
            }

            VStack(spacing: 16) {
                ForEach(videos.prefix(2)) { video in
                    Button {
                        selectedVideo = video
                    } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .bottomTrailing) {
                                    AsyncImage(url: video.thumbnailURL) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(height: 180)
                                                .clipped()
                                        } else {
                                            Rectangle()
                                                .fill(Color(.tertiarySystemFill))
                                                .frame(height: 180)
                                        }
                                    }

                                    // Centrerad spela-knapp
                                    Image(systemName: "play.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .padding(16)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                                    // Tidsstämpel i nedre högra hörnet
                                    Text("3:02")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.75))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .padding(8)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Text(video.name ?? "Official Trailer")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func similarGamesSection(_ games: [IGDBRelatedGame]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Liknande spel")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingSimilarGamesSheet = true
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(games) { game in
                        NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                            VStack(alignment: .leading, spacing: 6) {
                                CoverView(title: game.name ?? "Spel", url: game.coverURL, corner: 10, height: 130)
                                    .frame(width: 95)
                                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                                Text(game.name ?? "Spel")
                                    .font(.caption.bold())
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)
                                    .frame(width: 95, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func remoteErrorCard(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Kunde inte ladda speldetaljer")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                retryFetch()
            } label: {
                Label("Försök igen", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func inlineErrorCard(message: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Utökad information kunde inte hämtas")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                retryFetch()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func retryFetch() {
        print("[GameDetailView] Retry requested for mode: \(mode)")
        configureInitialState()
    }

    private func detailCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if let g = currentGame {
                    Button("Markera som Spelar nu") { updateStatus(.playing, for: g) }
                    Button("Markera som Klar")      { updateStatus(.completed, for: g) }
                    Button("Markera som Avbrutet")  { updateStatus(.abandoned, for: g) }
                    Button("Lägg till i Önskelista") { updateStatus(.wishlist, for: g) }

                    Divider()

                    Button(role: .destructive) {
                        store.games.removeAll(where: { $0.id == g.id })
                        dismiss()
                    } label: {
                        Label("Ta bort från bibliotek", systemImage: "trash")
                    }
                } else if let r = remote {
                    Button("Lägg till i biblioteket") { addRemoteToLibrary(r) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Helper logic

    private func configureInitialState() {
        print("[GameDetailView] configureInitialState triggered for mode: \(mode)")
        switch mode {
        case .local(let g):
            print("[GameDetailView] Local game: '\(g.title)' (ID: \(g.id), igdbID: \(g.igdbID?.description ?? "nil"))")
            if let igdbID = g.igdbID {
                Task { await loadRemote(id: igdbID) }
            } else {
                Task { await ensureRemoteForLocal(g) }
            }
        case .igdb(let id):
            print("[GameDetailView] Remote IGDB ID: \(id)")
            Task { await loadRemote(id: id) }
        }
    }

    private func ensureRemoteForLocal(_ g: Game) async {
        print("[GameDetailView] ensureRemoteForLocal searching IGDB for query: '\(g.title)'")
        await MainActor.run { remoteState = .loading }
        do {
            let searchResults = try await IGDBService.shared.searchGames(query: g.title)
            print("[GameDetailView] searchGames returned \(searchResults.count) results for '\(g.title)'")
            if let best = bestMatch(for: g, in: searchResults) {
                var updated = g
                updated.igdbID = best.id
                updateLocal(updated)
                print("[GameDetailView] Found IGDB ID \(best.id) ('\(best.name)') for '\(g.title)', fetching full details...")
                await loadRemote(id: best.id)
            } else {
                print("[GameDetailView] No IGDB match found for '\(g.title)'")
                await MainActor.run {
                    remoteState = .error("Ingen IGDB-information hittades för \"\(g.title)\".")
                }
            }
        } catch {
            print("[GameDetailView] searchGames failed for '\(g.title)': \(error.localizedDescription)")
            await MainActor.run {
                remoteState = .error("Kunde inte söka information från IGDB (\(error.localizedDescription)).")
            }
        }
    }

    private func bestMatch(for g: Game, in results: [IGDBGame]) -> IGDBGame? {
        let lowerTitle = g.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let currentYear = Calendar.current.component(.year, from: Date())

        // 1. Exakt titel och samma år
        if g.releaseYear > 0 {
            if let match = results.first(where: { $0.name.lowercased() == lowerTitle && $0.releaseYear == g.releaseYear }) {
                return match
            }
        }

        // 2. Om spelet är tänkt som framtida/kommande (>= currentYear), prioritera resultat som också är i framtiden
        if g.releaseYear >= currentYear {
            if let futureMatch = results.first(where: { $0.name.lowercased() == lowerTitle && ($0.releaseYear ?? 0) >= currentYear }) {
                return futureMatch
            }
        }

        // 3. Exakt titel
        if let match = results.first(where: { $0.name.lowercased() == lowerTitle }) {
            // Om vårt spel är tänkt som framtida, men match är ett gammalt spel och det finns alternativ
            if g.releaseYear >= currentYear, let rYear = match.releaseYear, rYear < currentYear {
                if let altFuture = results.first(where: { $0.name.lowercased().hasPrefix(lowerTitle) && ($0.releaseYear ?? 0) >= currentYear }) {
                    return altFuture
                }
            }
            return match
        }

        // 4. Spel med mest betyg och flest omdömen som börjar på samma namn (huvudspelet)
        let startingMatches = results.filter { $0.name.lowercased().hasPrefix(lowerTitle) }
        if let bestPopular = startingMatches.max(by: { ($0.totalRatingCount ?? 0) < ($1.totalRatingCount ?? 0) }) {
            return bestPopular
        }

        // 5. Mest populära sökresultat totalt
        return results.max(by: { ($0.totalRatingCount ?? 0) < ($1.totalRatingCount ?? 0) }) ?? results.first
    }

    private func loadRemote(id: Int) async {
        print("[GameDetailView] Starting loadRemote for IGDB ID: \(id)")
        await MainActor.run { remoteState = .loading }
        do {
            let game = try await IGDBService.shared.fetchGameDetails(id: id)
            print("[GameDetailView] Successfully loaded remote IGDBGame: '\(game.name)' (ID: \(game.id))")

            // Validera att namnet stämmer skapligt med spelet i biblioteket samt årtal
            if let g = currentGame {
                let localLower = g.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let remoteLower = game.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let currentYear = Calendar.current.component(.year, from: Date())

                // Om det sparade IGDB-ID:t råkade peka på fel spel (t.ex. ett soundtrack, artbook eller gammalt spin-off)
                if !remoteLower.contains(localLower) && !localLower.contains(remoteLower) {
                    print("[GameDetailView] Mismatched IGDB ID \(id) ('\(game.name)' vs '\(g.title)'), re-searching best match...")
                    var updated = g
                    updated.igdbID = nil
                    updateLocal(updated)
                    await ensureRemoteForLocal(updated)
                    return
                }

                // Om vårt spel är ett kommande spel men ID:t pekar på ett gammalt spel med samma namn (t.ex. Fable 2004)
                if g.releaseYear >= currentYear, let rYear = game.releaseYear, rYear < currentYear {
                    print("[GameDetailView] Mismatched year for upcoming game \(id) ('\(game.name)' year \(rYear) vs expected \(g.releaseYear)), re-searching best match...")
                    var updated = g
                    updated.igdbID = nil
                    updateLocal(updated)
                    await ensureRemoteForLocal(updated)
                    return
                }
            }

            if var g = currentGame {
                var changed = false
                let est = game.timeToBeat?.mainStoryHours ?? game.timeToBeat?.mainExtraHours
                if let est = est, g.estimatedHours != est {
                    g.estimatedHours = est
                    changed = true
                }
                if let date = game.firstReleaseDate, g.firstReleaseDate != date {
                    g.firstReleaseDate = date
                    changed = true
                }
                if let year = game.releaseYear, g.releaseYear != year {
                    g.releaseYear = year
                    changed = true
                }
                if changed {
                    updateLocal(g)
                }
            }

            await MainActor.run {
                remoteState = .loaded(game)
            }
        } catch {
            print("[GameDetailView] Failed loadRemote for IGDB ID \(id): \(error.localizedDescription)")
            await MainActor.run {
                remoteState = .error("Kunde inte hämta detaljer från IGDB (\(error.localizedDescription)).")
            }
        }
    }

    private func updateLocal(_ updated: Game) {
        if let idx = store.games.firstIndex(where: { $0.id == updated.id }) {
            store.games[idx] = updated
        }
    }

    private func updateStatus(_ status: PlayStatus, for g: Game) {
        var copy = g
        copy.status = status
        updateLocal(copy)
    }

    private func addRemoteToLibrary(_ d: IGDBGame) {
        let genres = d.genres?.map { $0.name } ?? []
        let platforms = d.platforms?.map { $0.name } ?? []
        let normalizedRating = (d.totalRating ?? 0.0) / 20.0
        let est = d.timeToBeat?.mainStoryHours ?? d.timeToBeat?.mainExtraHours

        let new = Game(
            title: d.name,
            platforms: platforms,
            releaseYear: d.releaseYear ?? 0,
            genres: genres,
            developers: d.developerName.map { [$0] } ?? [],
            status: .wishlist,
            rating: 0,
            igdbRating: normalizedRating,
            coverURL: d.coverURL,
            igdbID: d.id,
            firstReleaseDate: d.firstReleaseDate,
            estimatedHours: est
        )
        store.add(new)
    }
}

// MARK: - Hjälpvy för Fullskärmsgalleri (Etapp 2)

private struct FullscreenGalleryView: View {
    let screenshots: [IGDBImage]
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(screenshots: [IGDBImage], initialIndex: Int) {
        self.screenshots = screenshots
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("\(currentIndex + 1) av \(screenshots.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Color.clear
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 50)
                .padding(.bottom, 10)

                // Main Swipeable Image TabView
                TabView(selection: $currentIndex) {
                    ForEach(Array(screenshots.enumerated()), id: \.element.id) { index, img in
                        ZStack {
                            if let url = img.url(size: "t_1080p") {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    } else if phase.error != nil {
                                        VStack(spacing: 8) {
                                            Image(systemName: "exclamationmark.triangle")
                                                .font(.largeTitle)
                                                .foregroundStyle(.gray)
                                            Text("Kunde inte ladda bilden")
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    } else {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                }
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom Thumbnail Strip
                if screenshots.count > 1 {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(screenshots.enumerated()), id: \.element.id) { index, img in
                                    if let thumbURL = img.url(size: "t_screenshot_big") {
                                        AsyncImage(url: thumbURL) { phase in
                                            if let image = phase.image {
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 56, height: 40)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                            .stroke(index == currentIndex ? Color.red : Color.clear, lineWidth: 2)
                                                    )
                                                    .opacity(index == currentIndex ? 1.0 : 0.5)
                                                    .onTapGesture {
                                                        withAnimation {
                                                            currentIndex = index
                                                        }
                                                    }
                                            } else {
                                                Color.gray.opacity(0.3)
                                                    .frame(width: 56, height: 40)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                            }
                                        }
                                        .id(index)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .onChange(of: currentIndex) { newIndex in
                            withAnimation {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }

                // Info text bottom caption
                VStack(spacing: 4) {
                    Text("Fullskärmsvisning")
                        .font(.caption.bold())
                        .foregroundStyle(.white)

                    Text("Tryck på en bild för att öppna den i fullskärm. Svep för att bläddra mellan bilder.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Hjälpvy för Trailers & Videor Undersida (Etapp 4)

private struct TrailersSheetView: View {
    let videos: [IGDBVideo]
    var onSelectVideo: (IGDBVideo) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(videos) { video in
                            Button {
                                onSelectVideo(video)
                            } label: {
                                    HStack(spacing: 12) {
                                        ZStack(alignment: .bottomTrailing) {
                                            AsyncImage(url: video.thumbnailURL) { phase in
                                                if let image = phase.image {
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 110, height: 68)
                                                        .clipped()
                                                } else {
                                                    Rectangle()
                                                        .fill(Color(.tertiarySystemFill))
                                                        .frame(width: 110, height: 68)
                                                }
                                            }

                                            Image(systemName: "play.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                                .padding(6)
                                                .background(Color.black.opacity(0.6))
                                                .clipShape(Circle())
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                                            Text("3:05")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.black.opacity(0.8))
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                                .padding(4)
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(video.name ?? "Trailer")
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.primary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)

                                            Text("3:05")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }

                // Info caption bottom text
                VStack(spacing: 4) {
                    Text("Trailers & videor")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)

                    Text("Alla tillgängliga trailers och videos från IGDB öppnas direkt i YouTube.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Trailers & videor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") { dismiss() }
                        .font(.subheadline.bold())
                }
            }
        }
    }
}

// MARK: - Hjälpvy för Liknande Spel Undersida (Etapp 5)

private struct SimilarGamesSheetView: View {
    let games: [IGDBRelatedGame]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(games) { game in
                            NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                                HStack(spacing: 14) {
                                    CoverView(title: game.name ?? "Spel", url: game.coverURL, corner: 8, height: 100)
                                        .frame(width: 70)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(game.name ?? "Spel")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)

                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(.red)
                                                .font(.caption)
                                            Text("89/100")
                                                .font(.caption.bold())
                                                .foregroundStyle(.primary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.red)
                                }
                                .padding(10)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }

                // Info caption bottom text
                VStack(spacing: 4) {
                    Text("Liknande spel")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)

                    Text("Hitta och utforska spel som liknar det du tittar på. Tryck för att öppna deras detaljvy.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Liknande spel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") { dismiss() }
                        .font(.subheadline.bold())
                }
            }
        }
    }
}

// MARK: - Hjälpvy för Biblioteksstatus Sheet (Etapp 5)

private struct LibraryStatusSheetView: View {
    let title: String
    let coverURL: URL?
    let isInLibrary: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Header row with mini cover and title
            HStack(spacing: 12) {
                CoverView(title: title, url: coverURL, corner: 6, height: 48)
                    .frame(width: 36)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
            }

            VStack(spacing: 10) {
                if isInLibrary {
                    Button {
                        onRemove()
                        dismiss()
                    } label: {
                        Label("Ta bort från biblioteket", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button {
                        onAdd()
                        dismiss()
                    } label: {
                        Label("Lägg till i biblioteket", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Avbryt")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            // Caption bottom text
            VStack(spacing: 4) {
                Text("Biblioteksstatus")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)

                Text("Lägg till eller ta bort spel från ditt bibliotek med ett tydligt och snabbt flöde.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - In-App Trailer Player Components (Etapp D)

private struct YouTubeWebPlayerView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = .black
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let embedURL = URL(string: "https://www.youtube-nocookie.com/embed/\(videoID)?autoplay=1&playsinline=1") else { return }
        let request = URLRequest(url: embedURL)
        uiView.load(request)
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = .systemRed
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct InAppVideoSheet: View {
    let video: IGDBVideo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let vID = video.videoID {
                    YouTubeWebPlayerView(videoID: vID)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                } else if let url = video.youtubeURL {
                    SafariView(url: url)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(video.name ?? "Officiell Trailer")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Text("Officiell trailer spelas inuti Gameshelf.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

                Spacer()
            }
            .padding(16)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Trailer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") { dismiss() }
                        .font(.subheadline.bold())
                }
            }
        }
    }
}
