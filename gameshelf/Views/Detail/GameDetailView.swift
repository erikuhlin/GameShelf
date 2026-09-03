// GameDetailView.swift
// gameshelf

import SwiftUI
import WebKit
import SafariServices

struct GameDetailView: View {
    @EnvironmentObject var store: LibraryStore
    @EnvironmentObject var profile: ProfileStore
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
    @State private var showingMoveToLibraryDialog = false
    @State private var showingRemoveWishlistAlert = false
    @State private var selectedVideo: IGDBVideo? = nil

    // Spelframsteg state
    @State private var isEditingHours = false
    @State private var manualHoursInput = ""
    @State private var isEditingProgressNote = false
    @State private var progressNoteDraft = ""

    @FocusState private var isNotesFocused: Bool
    @State private var newTodoText: String = ""

    enum LibraryDetailTab: String, CaseIterable, Identifiable {
        case myPlay = "Mitt Spelande"
        case gameFacts = "Spelfakta & Info"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .myPlay: return "gamecontroller.fill"
            case .gameFacts: return "info.circle.fill"
            }
        }
    }

    struct GuideWebItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let url: URL
    }

    @State private var selectedLibraryTab: LibraryDetailTab = .myPlay
    @State private var showingShareSheet = false
    @State private var showingPlatformSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedGuide: GuideWebItem? = nil

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

    private var isUpcomingGame: Bool {
        if let targetDate = effectiveReleaseDate {
            return targetDate > Date()
        }
        if let year = effectiveReleaseYear, year > Calendar.current.component(.year, from: Date()) {
            return true
        }
        return false
    }

    private var formattedReleaseDate: String? {
        if let date = effectiveReleaseDate {
            if date > Date() && date.isYearPlaceholderDate {
                if let year = effectiveReleaseYear ?? Calendar.current.component(.year, from: date) as Int?, year > 0 {
                    return "Kommande \(year)"
                }
                return "Kommande"
            }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "sv_SE")
            formatter.dateStyle = .long
            return formatter.string(from: date)
        }
        if let year = effectiveReleaseYear, year > 0 {
            if year > Calendar.current.component(.year, from: Date()) {
                return "Kommande \(year)"
            }
            return String(year)
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // --- 1. HERO HEADER ---
                heroHeader

                // --- NEDRÄKNING FÖR KOMMANDE SPEL ---
                ReleaseCountdownBanner(
                    releaseDate: effectiveReleaseDate,
                    releaseYear: effectiveReleaseYear
                )

                // --- 2. HUVUDÅTGÄRDER / STATUS & FLIKAR (De 3 tillstånden) ---
                if let g = currentGame, g.isOwned {
                    // TILLSTÅND 1: I BIBLIOTEKET
                    libraryGameHeaderBar(g)
                    focusGoalAndCompletedBadgeBar(g)
                    libraryTabsBar

                    if isLoadingRemote {
                        remoteLoadingIndicator
                    } else if let errorMsg = remoteErrorMessage {
                        inlineErrorCard(message: errorMsg)
                    }

                    // Innehåll för vald flik
                    switch selectedLibraryTab {
                    case .myPlay:
                        myPlayTabContent(g)
                    case .gameFacts:
                        gameFactsContent
                    }
                } else if let g = currentGame, !g.isOwned {
                    // TILLSTÅND 2: ÖNSKELISTA
                    wishlistHeaderStrip(g)
                    wishlistActionsBar(g)

                    if isLoadingRemote {
                        remoteLoadingIndicator
                    } else if let errorMsg = remoteErrorMessage {
                        inlineErrorCard(message: errorMsg)
                    }

                    gameFactsContent
                } else if let r = remote {
                    // TILLSTÅND 3: EJ TILLAGD (Data från IGDB)
                    unaddedActionsBar(r)

                    gameFactsContent
                } else {
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
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
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
        .sheet(isPresented: $showingPlatformSheet) {
            if let g = currentGame {
                platformFormatSheet(g)
            }
        }
        .confirmationDialog(
            "Flytta till Biblioteket",
            isPresented: $showingMoveToLibraryDialog,
            titleVisibility: .visible
        ) {
            if let g = currentGame {
                Button("🎮 Börja spela nu") {
                    var copy = g
                    copy.isOwned = true
                    copy.status = .playing
                    copy.isBacklog = false
                    copy.lastPlayedDate = Date()
                    updateLocal(copy)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

                Button("📦 Lägg i Backlog") {
                    var copy = g
                    copy.isOwned = true
                    copy.status = .notStarted
                    copy.isBacklog = true
                    updateLocal(copy)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

                Button("🏆 Har redan klarat") {
                    var copy = g
                    copy.isOwned = true
                    copy.status = .completed
                    let currentY = Calendar.current.component(.year, from: Date())
                    copy.completedYear = currentY
                    copy.completedDate = Date()
                    copy.storyProgress = .completed
                    updateLocal(copy)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

                Button("Avbryt", role: .cancel) {}
            }
        }
        .alert("Ta bort från önskelistan?", isPresented: $showingRemoveWishlistAlert) {
            Button("Ta bort", role: .destructive) {
                if let g = currentGame {
                    let igdbID = g.igdbID
                    store.games.removeAll(where: { $0.id == g.id })
                    if let id = igdbID {
                        mode = .igdb(id: id)
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Spelet tas bort från din önskelista.")
        }
        .sheet(item: $selectedGuide) { guide in
            SafariView(url: guide.url)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingShareSheet) {
            let title = currentGame?.title ?? remote?.name ?? "Spel"
            let dev = remote?.developerName ?? currentGame?.developers.first
            let year = effectiveReleaseYear
            let coverURL = currentGame?.coverURL ?? remote?.coverURL
            let userRating = currentGame?.rating
            let criticRating = remote?.aggregatedRating != nil ? Int(round(remote!.aggregatedRating!)) : nil
            let status = currentGame?.status
            let platform = currentGame?.platforms.first ?? remote?.platforms?.first?.name
            let hours = currentGame?.estimatedHours

            GameShareSheet(
                cardView: GameShareCardView(
                    gameTitle: title,
                    developer: dev,
                    releaseYear: year,
                    releaseDateText: formattedReleaseDate,
                    coverURL: coverURL,
                    userRating: userRating,
                    criticRating: criticRating,
                    status: status,
                    platform: platform,
                    hoursPlayed: hours
                )
            )
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

        return VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                // Vänster: Omslagsbild (Poster)
                CoverView(title: title, url: coverURL, corner: 14, height: 160)
                    .frame(width: 110)
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)

                // Höger: Information & Betyg
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Betyg (Spelare / Kritiker i eleganta kapslar)
                    if playerRating != nil || criticRating != nil {
                        HStack(spacing: 6) {
                            if let pRating = playerRating {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.yellow)
                                    Text("\(pRating)%")
                                        .font(.caption.bold())
                                        .foregroundStyle(.primary)
                                    Text("Spelare")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(Capsule())
                            }

                            if let cRating = criticRating {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.blue)
                                    Text("\(cRating)%")
                                        .font(.caption.bold())
                                        .foregroundStyle(.primary)
                                    Text("Kritiker")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    // Releasedatum & Utvecklare
                    HStack(spacing: 6) {
                        if let dateText = formattedReleaseDate {
                            Text(dateText)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        if formattedReleaseDate != nil && developer != nil {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let dev = developer, !dev.isEmpty {
                            Text(dev)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .lineLimit(1)

                    // Genrer
                    if let gText = genresText, !gText.isEmpty {
                        Text(gText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // Spellägen & Åldersmärkningar (diskreta ikoner och märken)
                    let modes = remote?.gameModes ?? []
                    let ageLabels = remote?.ageRatings?.compactMap({ $0.label }) ?? []
                    if !modes.isEmpty || !ageLabels.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(modes.prefix(2)) { mode in
                                HStack(spacing: 3) {
                                    Image(systemName: gameModeIcon(mode.name))
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    Text(mode.name)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }

                            ForEach(ageLabels, id: \.self) { label in
                                Text(label)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 3)
                                    .background(Color(.tertiarySystemFill))
                                    .foregroundStyle(.secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Snabbåtgärder & Kontroller

    private func libraryGameHeaderBar(_ g: Game) -> some View {
        HStack(spacing: 0) {
            // 1. Statusväljare
            Menu {
                Section("Status") {
                    ForEach(PlayStatus.allCases) { st in
                        Button {
                            var copy = g
                            copy.status = st
                            if st == .playing {
                                copy.isBacklog = false
                                if copy.lastPlayedDate == nil {
                                    copy.lastPlayedDate = Date()
                                }
                            } else if st == .completed {
                                if copy.completedYear == nil {
                                    copy.completedYear = Calendar.current.component(.year, from: Date())
                                    copy.completedDate = Date()
                                }
                                copy.storyProgress = .completed
                            }
                            updateLocal(copy)
                        } label: {
                            HStack {
                                if g.status == st {
                                    Image(systemName: "checkmark")
                                }
                                Label(
                                    st.title(for: g.playTypes),
                                    systemImage: st.icon(for: g.playTypes)
                                )
                            }
                        }
                    }
                }

                if g.status == .completed {
                    Section("Klarat år (Spelmål)") {
                        Button {
                            var copy = g
                            copy.completedYear = nil
                            updateLocal(copy)
                        } label: {
                            HStack {
                                if g.completedYear == nil { Image(systemName: "checkmark") }
                                Text("Ej angivet (Räkna inte i årets mål)")
                            }
                        }

                        let currentY = Calendar.current.component(.year, from: Date())
                        Button {
                            var copy = g
                            copy.completedYear = currentY
                            if copy.completedDate == nil { copy.completedDate = Date() }
                            updateLocal(copy)
                        } label: {
                            HStack {
                                if g.completedYear == currentY { Image(systemName: "checkmark") }
                                Text("\(String(currentY)) (I år)")
                            }
                        }

                        ForEach((currentY - 10..<currentY).reversed(), id: \.self) { y in
                            Button {
                                var copy = g
                                copy.completedYear = y
                                updateLocal(copy)
                            } label: {
                                HStack {
                                    if g.completedYear == y { Image(systemName: "checkmark") }
                                    Text(String(y))
                                }
                            }
                        }
                    }
                }

                Section("Spelmål & Planering") {
                    let isTarget = profile.isTargetGoal(gameID: g.id)
                    Button {
                        withAnimation {
                            profile.toggleTargetGoal(gameID: g.id)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    } label: {
                        Label(
                            isTarget ? "Ta bort som Fokusmål" : "Sätt som Fokusmål 🎯",
                            systemImage: isTarget ? "target" : "target"
                        )
                    }

                    Button {
                        var copy = g
                        copy.isBacklog.toggle()
                        updateLocal(copy)
                    } label: {
                        Label(
                            g.isBacklog ? "Ta bort från Backlog" : "Lägg till i Backlog",
                            systemImage: g.isBacklog ? "archivebox.fill" : "archivebox"
                        )
                    }
                }

                Section("Speltyp") {
                    ForEach(GamePlayType.allCases) { pt in
                        Button {
                            var copy = g
                            if copy.playTypes.contains(pt) {
                                if copy.playTypes.count > 1 {
                                    copy.playTypes.removeAll(where: { $0 == pt })
                                }
                            } else {
                                copy.playTypes.append(pt)
                            }
                            updateLocal(copy)
                        } label: {
                            HStack {
                                if g.playTypes.contains(pt) {
                                    Image(systemName: "checkmark")
                                }
                                Label(pt.title, systemImage: pt.icon)
                            }
                        }
                    }
                }
            } label: {
                VStack(spacing: 5) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(g.status.color)
                            .frame(width: 8, height: 8)
                            .shadow(color: g.status.color.opacity(0.6), radius: 3)
                        Text(g.statusDisplayTitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 3) {
                        Text("STATUS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(.secondaryLabel))
                            .tracking(0.6)
                        if g.isBacklog {
                            Text("• BACKLOG")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.blue)
                                .tracking(0.6)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 28)

            // 2. Format & Plattform (öppnar dedikerat sheet)
            Button {
                showingPlatformSheet = true
            } label: {
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                        Text(platformsSummaryText(g.platforms))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Text(g.platforms.count > 1 ? "\(g.platforms.count) PLATTFORMAR" : "PLATTFORM")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .tracking(0.6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 28)

            // 3. Betygskort
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
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: (g.rating ?? 0) > 0 ? "star.fill" : "star")
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                        if let r = g.rating, r > 0 {
                            Text("\(r)/10")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                        } else {
                            Text("Betygsätt")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                    }
                    Text("MITT BETYG")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .tracking(0.6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    private func compactPlatformName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("playstation 5") || lower == "ps5" { return "PS5" }
        if lower.contains("playstation 4") || lower == "ps4" { return "PS4" }
        if lower.contains("playstation 3") || lower == "ps3" { return "PS3" }
        if lower.contains("playstation 2") || lower == "ps2" { return "PS2" }
        if lower.contains("playstation") || lower == "ps1" || lower == "psx" { return "PS1" }
        if lower.contains("switch") { return "Switch" }
        if lower.contains("series x") || lower.contains("series s") || lower.contains("xbox series") { return "Xbox" }
        if lower.contains("xbox one") { return "Xbox One" }
        if lower.contains("xbox 360") { return "X360" }
        if lower.contains("xbox") { return "Xbox" }
        if lower.contains("pc") || lower.contains("windows") || lower.contains("steam") { return "PC" }
        if lower.contains("mac") { return "Mac" }
        if lower.contains("nintendo 64") || lower.contains("n64") { return "N64" }
        if lower.contains("super nintendo") || lower.contains("snes") { return "SNES" }
        if lower.contains("nes") { return "NES" }
        if lower.contains("game boy advance") || lower.contains("gba") { return "GBA" }
        if lower.contains("game boy") { return "GB" }
        if lower.contains("gamecube") { return "GCN" }
        if lower.contains("wii u") { return "Wii U" }
        if lower.contains("wii") { return "Wii" }
        if lower.contains("ios") || lower.contains("iphone") || lower.contains("ipad") { return "iOS" }
        if lower.contains("android") { return "Android" }
        return name
    }

    private func platformsSummaryText(_ platforms: [String]) -> String {
        guard !platforms.isEmpty else { return "Välj" }
        let compact = platforms.map { compactPlatformName($0) }
        switch compact.count {
        case 1:
            return compact[0]
        case 2:
            return "\(compact[0]), \(compact[1])"
        default:
            return "\(compact[0]) +\(compact.count - 1)"
        }
    }

    private func platformFormatSheet(_ g: Game) -> some View {
        NavigationStack {
            List {
                Section {
                    ForEach(availablePlatforms(for: g), id: \.self) { platform in
                        let isSelected = g.platforms.contains(platform)
                        Button {
                            togglePlatform(platform, for: g)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack {
                                Image(systemName: "gamecontroller.fill")
                                    .foregroundStyle(platformColor(for: platform))
                                    .frame(width: 28)

                                Text(platform)
                                    .font(.body.weight(isSelected ? .semibold : .regular))
                                    .foregroundStyle(.primary)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.headline)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Välj vilka plattformar du spelar eller äger spelet på.")
                        .font(.caption)
                }
            }
            .navigationTitle("Välj Plattform")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") {
                        showingPlatformSheet = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func platformColor(for name: String) -> Color {
        let lower = name.lowercased()
        if lower.contains("playstation") || lower.contains("ps") { return .blue }
        if lower.contains("xbox") { return .green }
        if lower.contains("switch") || lower.contains("nintendo") { return .red }
        return .secondary
    }

    private func unaddedActionsBar(_ r: IGDBGame) -> some View {
        HStack(spacing: 10) {
            // 1. Lägg till i biblioteket
            Button {
                showingLibraryStatusSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.subheadline.bold())
                    Text("Lägg till i biblioteket")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(.plain)

            // 2. Snabbknapp: Önskelista
            Button {
                addRemoteToWishlist(r)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text("Önskelista")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func wishlistHeaderStrip(_ g: Game) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
                .font(.system(size: 16))

            let dateStr = formattedDateAdded(g.dateAdded)
            HStack(spacing: 4) {
                Text("På önskelistan")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text("Tillagd \(dateStr)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func wishlistActionsBar(_ g: Game) -> some View {
        HStack(spacing: 10) {
            // Flytta till Biblioteket
            Button {
                showingMoveToLibraryDialog = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.subheadline.bold())
                    Text("Flytta till Biblioteket")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(.plain)

            // Hjärt-knapp (toggle / ta bort från önskelistan)
            Button {
                showingRemoveWishlistAlert = true
            } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.red)
                    .frame(width: 48, height: 48)
                    .background(Color.red.opacity(0.15))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.red.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func formattedDateAdded(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func focusGoalAndCompletedBadgeBar(_ g: Game) -> some View {
        if profile.isTargetGoal(gameID: g.id) || g.status == .completed {
            HStack(spacing: 8) {
                if profile.isTargetGoal(gameID: g.id) {
                    HStack(spacing: 5) {
                        Image(systemName: "target")
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                        Text("Fokusmål 🎯")
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.yellow.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(Color.yellow.opacity(0.35), lineWidth: 0.8))
                }

                if g.status == .completed {
                    Menu {
                        Button("Ej angivet (Räkna inte i årets mål)") {
                            var copy = g
                            copy.completedYear = nil
                            updateLocal(copy)
                        }
                        let currentY = Calendar.current.component(.year, from: Date())
                        Button("\(String(currentY)) (I år)") {
                            var copy = g
                            copy.completedYear = currentY
                            if copy.completedDate == nil { copy.completedDate = Date() }
                            updateLocal(copy)
                        }
                        ForEach((currentY - 10..<currentY).reversed(), id: \.self) { y in
                            Button(String(y)) {
                                var copy = g
                                copy.completedYear = y
                                updateLocal(copy)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.checkered")
                                .font(.caption2.bold())
                                .foregroundStyle(.teal)
                            Text(g.completedYear != nil ? "Klarat \(String(g.completedYear!))" : "Klarat (år ej valt)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.teal.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(Color.teal.opacity(0.35), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
    }

    private var remoteLoadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Hämtar utökad spelinformation...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func addRemoteToWishlist(_ r: IGDBGame) {
        let genres = r.genres?.map { $0.name } ?? []
        let available = r.platforms?.map { $0.name } ?? []
        let platforms = PlatformMatcher.resolvePlatforms(availableIGDBPlatforms: available, userProfilePlatforms: profile.platforms)
        let normalizedRating = (r.totalRating ?? 0.0) / 20.0
        let est = r.timeToBeat?.mainStoryHours ?? r.timeToBeat?.mainExtraHours

        let newGame = Game(
            title: r.name,
            platforms: platforms,
            releaseYear: r.releaseYear ?? 0,
            genres: genres,
            developers: r.developerName.map { [$0] } ?? [],
            status: .notStarted,
            rating: nil,
            igdbRating: normalizedRating,
            coverURL: r.coverURL,
            igdbID: r.id,
            firstReleaseDate: r.firstReleaseDate,
            estimatedHours: est,
            isOwned: false
        )
        store.add(newGame)
        mode = .local(newGame)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Flikväljare & Innehåll

    private var libraryTabsBar: some View {
        Picker("Flik", selection: Binding<LibraryDetailTab>(
            get: { selectedLibraryTab },
            set: { newTab in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedLibraryTab = newTab
                }
            }
        )) {
            ForEach(LibraryDetailTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func myPlayTabContent(_ g: Game) -> some View {
        VStack(spacing: 16) {
            if !g.isMultiplayerOrOngoing {
                playtimeProgressCard(g)
            } else {
                multiplayerPlaytimeCard(g)
            }
            notesCard(g)
            collectionsCard(g)
            deleteGameButton(g)
        }
    }

    @ViewBuilder
    private var gameFactsContent: some View {
        VStack(spacing: 16) {
            // 1. Om spelet
            aboutGameSection

            // 2. Gameplay & Media (Skärmdumpar & Trailers)
            if let screenshots = remote?.screenshots, !screenshots.isEmpty {
                screenshotsSection(screenshots)
            }
            if let videos = remote?.videos, !videos.isEmpty {
                trailersSection(videos)
            }

            // 3. Speltid (Referens · HowLongToBeat)
            timeToBeatSection(remote?.timeToBeat)

            // 4. Guider & Resurser (Genomspelning & Community)
            guidesSection

            // 5. Relaterat (Spelserie, DLC & Expansioner, Liknande spel eller Fristående titel)
            relatedSection

            // 6. Fakta & Betyg (Konsoliderad)
            factsAndRatingsSection
        }
    }

    // MARK: - Spelframstegstracker (Kvalitativa milstolpar, HLTB-band & Lägesanteckning)

    private func playtimeProgressCard(_ g: Game) -> some View {
        let hours = g.effectiveHoursPlayed
        let mainHours = remote?.timeToBeat?.mainStoryHours ?? 0
        let extraHours = remote?.timeToBeat?.mainExtraHours ?? 0
        let compHours = remote?.timeToBeat?.completionistHours ?? 0
        let hasHLTB = mainHours > 0 || extraHours > 0 || compHours > 0

        // Single-select, alltid ett val. Default: .justStarted ("Precis börjat")
        let currentMilestone = g.storyProgress ?? .justStarted

        let hoursDisplay: String = {
            if hours == 0 { return "0h" }
            if hours.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(hours))h"
            } else {
                return "\(String(format: "%.1f", hours))h"
            }
        }()

        let maxBandHours = max(compHours, max(extraHours, mainHours))
        let isOverflow = hasHLTB && maxBandHours > 0 && hours > Double(maxBandHours)

        return detailCard(title: "Spelframsteg") {
            VStack(alignment: .leading, spacing: 16) {
                // 1. Tidsangivelse ("36h spelade" - tap för redigering inline)
                HStack(alignment: .center) {
                    if isEditingHours {
                        HStack(spacing: 8) {
                            TextField("0", text: $manualHoursInput)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .frame(width: 80)
                                .onSubmit {
                                    saveManualHours(for: g)
                                }

                            Text("tim")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button("Klar") {
                                saveManualHours(for: g)
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .buttonStyle(.plain)

                            Button("Avbryt") {
                                isEditingHours = false
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button {
                            manualHoursInput = hours > 0 ? (hours.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(hours))" : String(format: "%.1f", hours)) : ""
                            isEditingHours = true
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text("\(hoursDisplay) spelade")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.primary)
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Snabbknappar (-1h, +1h, +5h) - garanterat att aldrig radbrytas
                    if !isEditingHours {
                        HStack(spacing: 6) {
                            if hours > 0 {
                                Button("-1h") {
                                    adjustPlaytime(by: -1.0, for: g)
                                }
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color(.tertiarySystemFill))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                                .buttonStyle(.plain)
                            }

                            Button("+1h") {
                                adjustPlaytime(by: 1.0, for: g)
                            }
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(.tertiarySystemFill))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                            .buttonStyle(.plain)

                            Button("+5h") {
                                adjustPlaytime(by: 5.0, for: g)
                            }
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 2. HLTB-band (Sleek progress bars utan klumpiga kapsel-boxar)
                if hasHLTB {
                    VStack(alignment: .leading, spacing: 10) {
                        if mainHours > 0 {
                            progressHLTBBandRow(name: "Main Story", targetHours: mainHours, hoursPlayed: hours, icon: "📖")
                        }
                        if extraHours > 0 {
                            progressHLTBBandRow(name: "Main + Extra", targetHours: extraHours, hoursPlayed: hours, icon: "➕")
                        }
                        if compHours > 0 {
                            progressHLTBBandRow(name: "Completionist", targetHours: compHours, hoursPlayed: hours, icon: "🏆")
                        }

                        // Overflow-hantering enligt specifikation
                        if isOverflow {
                            HStack(spacing: 5) {
                                Image(systemName: "info.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("Du har spelat mer än genomsnittet för 100%-genomgång")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // 3. Kvalitativt läge (En rad med enhetlig höjd, bryts aldrig)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Var är du i spelet?")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(GameStoryProgress.allCases) { milestone in
                            let isSelected = (currentMilestone == milestone)
                            Button {
                                var copy = g
                                copy.storyProgress = milestone
                                updateLocal(copy)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } label: {
                                Text(milestone.rawValue)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(isSelected ? (milestone == .completed ? Color.green : Color.red) : Color(.tertiarySystemFill))
                                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 4. Anteckning (Valfri fritext, max 140 tecken)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Lägesanteckning")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let updated = g.noteUpdatedAt {
                            Text("Uppdaterad \(formattedRelativeDate(updated))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if isEditingProgressNote {
                        VStack(alignment: .trailing, spacing: 8) {
                            TextField("T.ex. Nuvarande kapitel, quest eller mål...", text: $progressNoteDraft, axis: .vertical)
                                .lineLimit(2...4)
                                .font(.subheadline)
                                .padding(12)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .onChange(of: progressNoteDraft) { _, newValue in
                                    if newValue.count > 140 {
                                        progressNoteDraft = String(newValue.prefix(140))
                                    }
                                }

                            HStack {
                                Text("\(progressNoteDraft.count)/140")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button("Avbryt") {
                                    isEditingProgressNote = false
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)

                                Button("Spara") {
                                    var copy = g
                                    copy.progressNote = progressNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                    copy.noteUpdatedAt = Date()
                                    updateLocal(copy)
                                    isEditingProgressNote = false
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                .font(.caption.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }
                        }
                    } else {
                        Button {
                            progressNoteDraft = g.progressNote ?? ""
                            isEditingProgressNote = true
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "square.and.pencil")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 1)

                                if let note = g.progressNote, !note.isEmpty {
                                    Text(note)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                } else {
                                    Text("Lägg till en lägesanteckning (t.ex. kapitel, quest)...")
                                        .font(.subheadline)
                                        .foregroundStyle(.tertiary)
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func saveManualHours(for g: Game) {
        let sanitized = manualHoursInput.replacingOccurrences(of: ",", with: ".")
        if let val = Double(sanitized), val >= 0 {
            var copy = g
            copy.effectiveHoursPlayed = val
            copy.lastPlayedDate = Date()
            updateLocal(copy)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        isEditingHours = false
    }

    private func formattedRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func progressHLTBBandRow(name: String, targetHours: Int, hoursPlayed: Double, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(icon)
                    .font(.caption)
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(targetHours) tim")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }

            let ratio = targetHours > 0 ? min(1.0, hoursPlayed / Double(targetHours)) : 0.0
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Bakgrundslinje
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 5)

                    // Fyllnad
                    if ratio > 0 {
                        Capsule()
                            .fill(ratio >= 1.0 ? Color.green.opacity(0.9) : Color.red.opacity(0.85))
                            .frame(width: max(5, min(geo.size.width, geo.size.width * CGFloat(ratio))), height: 5)
                    }

                    // Vit markörlinje vid fyllnadsgraden enligt specifikation
                    if ratio > 0 && ratio < 1.0 {
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 2.5, height: 9)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .offset(x: max(0, min(geo.size.width - 2.5, geo.size.width * CGFloat(ratio) - 1.25)))
                    }
                }
            }
            .frame(height: 9)
        }
        .padding(.vertical, 2)
    }

    private func multiplayerPlaytimeCard(_ g: Game) -> some View {
        let loggedHours = g.effectiveHoursPlayed
        let hoursDisplay = loggedHours > 0 ? (loggedHours.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(loggedHours))" : String(format: "%.1f", loggedHours)) : "0"

        return detailCard(title: "Speltid & Aktivitet") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loggedHours > 0 ? "\(hoursDisplay) timmar" : "Ingen tid loggad")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)

                        if let lastPlayed = g.lastPlayedFormatted {
                            Text(lastPlayed)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Aktiv rotation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        Circle()
                            .fill(g.status.color)
                            .frame(width: 7, height: 7)
                        Text(g.statusDisplayTitle)
                            .font(.caption.bold())
                            .foregroundStyle(g.status.color)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(g.status.color.opacity(0.12), in: Capsule())
                }

                // Snabba loggknappar för speltid
                HStack(spacing: 8) {
                    ForEach([1, 2, 5], id: \.self) { delta in
                        Button("+\(delta)h") {
                            adjustPlaytime(by: Double(delta), for: g)
                        }
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemFill))
                        .foregroundStyle(Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    if loggedHours > 0 {
                        Button("-1h") {
                            adjustPlaytime(by: -1.0, for: g)
                        }
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemFill))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private func deleteGameButton(_ g: Game) -> some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Ta bort från biblioteket", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.top, 8)
        .confirmationDialog("Ta bort från biblioteket?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Ta bort spel", role: .destructive) {
                store.games.removeAll(where: { $0.id == g.id })
                dismiss()
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Är du säker på att du vill ta bort \(g.title) från ditt bibliotek?")
        }
    }

    private func adjustPlaytime(by delta: Double, for g: Game) {
        var copy = g
        let current = copy.effectiveHoursPlayed
        let newHours = max(0.0, current + delta)
        copy.effectiveHoursPlayed = newHours
        copy.lastPlayedDate = Date()
        updateLocal(copy)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Spellägen & Co-op

    @ViewBuilder
    private var gameModesSection: some View {
        if let modes = remote?.gameModes, !modes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.red)
                    Text("Spellägen & Co-op")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(modes) { mode in
                            HStack(spacing: 6) {
                                Image(systemName: gameModeIcon(mode.name))
                                    .font(.caption.bold())
                                    .foregroundStyle(.red)
                                Text(mode.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func gameModeIcon(_ mode: String) -> String {
        let lower = mode.lowercased()
        if lower.contains("single") { return "person.fill" }
        if lower.contains("co-op") || lower.contains("cooperative") { return "person.2.fill" }
        if lower.contains("multiplayer") { return "person.3.fill" }
        if lower.contains("split") { return "rectangle.split.2x1.fill" }
        if lower.contains("mmo") { return "globe" }
        return "gamecontroller.fill"
    }

    // MARK: - Relaterat (Spelserie, DLC & Expansioner, Liknande spel eller Fristående titel)

    @ViewBuilder
    private var relatedSection: some View {
        let franchiseGames = remote?.franchiseGames ?? []
        let dlcs = allDLCsAndExpansions
        let similar = remote?.similarGames ?? []
        let franchiseName = remote?.franchiseName ?? "Spelserie"
        let isFranchise = !franchiseGames.isEmpty || !dlcs.isEmpty

        if isFranchise || !similar.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Relaterat")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }

                if isFranchise {
                    // Spelserie
                    if !franchiseGames.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Text("◆")
                                        .font(.caption.bold())
                                        .foregroundStyle(.red)
                                    Text("Spelserie: \(franchiseName)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                Text("\(franchiseGames.count) spel")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(franchiseGames) { game in
                                        NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                CoverView(title: game.name ?? "", url: game.coverURL, corner: 10, height: 128)
                                                    .frame(width: 96, height: 128)
                                                    .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)

                                                Text(game.name ?? "")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.leading)

                                                if let year = game.releaseYear {
                                                    Text(String(year))
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .frame(width: 96)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    // DLC & Expansioner
                    if !dlcs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Text("◈")
                                        .font(.caption.bold())
                                        .foregroundStyle(.purple)
                                    Text("DLC & Expansioner")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                Text("(\(dlcs.count))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(dlcs) { item in
                                        NavigationLink(destination: GameDetailView(igdbID: item.id)) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                CoverView(title: item.name ?? "DLC", url: item.coverURL, corner: 10, height: 62)
                                                    .frame(width: 110, height: 62)
                                                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                                                Text(item.name ?? "DLC")
                                                    .font(.caption2.bold())
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.leading)
                                                    .foregroundStyle(.primary)
                                                    .frame(width: 110, alignment: .topLeading)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                } else {
                    // Fristående titel
                    HStack(spacing: 12) {
                        Text("⧉")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fristående titel")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("Inga ytterligare expansioner eller serietitlar listade på IGDB.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Liknande spel
                if !similar.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("LIKNANDE SPEL")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                                .tracking(0.6)
                            Spacer()
                            Button {
                                showingSimilarGamesSheet = true
                            } label: {
                                Text("Visa alla")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.red)
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(similar) { game in
                                    NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            CoverView(title: game.name ?? "", url: game.coverURL, corner: 10, height: 128)
                                                .frame(width: 96, height: 128)
                                                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)

                                            Text(game.name ?? "")
                                                .font(.caption.bold())
                                                .foregroundStyle(.primary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .frame(width: 96)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Guider & Resurser (Genomspelning & Community)

    @ViewBuilder
    private var guidesSection: some View {
        if let title = currentGame?.title ?? remote?.name {
            let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "safari.fill")
                            .foregroundStyle(.red)
                        Text("Guider & Resurser")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Text("Öppnas i appen")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // 1. GENOMSPELNING
                VStack(alignment: .leading, spacing: 8) {
                    Text("GENOMSPELNING")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .tracking(0.6)

                    if let url = URL(string: "https://www.google.com/search?q=\(encoded)+IGN+walkthrough+guide") {
                        guideItemRow(
                            title: "IGN Walkthrough",
                            subtitle: "Komplett guide & kapitelgenomgång",
                            icon: "book.fill",
                            color: .red,
                            url: url
                        )
                    }

                    if let url = URL(string: "https://www.google.com/search?q=\(encoded)+PowerPyx+trophy+guide") {
                        guideItemRow(
                            title: "PowerPyx Trophy Guide",
                            subtitle: "Troféer & 100%-genomgång",
                            icon: "trophy.fill",
                            color: .yellow,
                            url: url
                        )
                    }

                    if let url = URL(string: "https://www.google.com/search?q=\(encoded)+interactive+map") {
                        guideItemRow(
                            title: "Interaktiv Karta",
                            subtitle: "Samlarobjekt, bossar & kartor",
                            icon: "map.fill",
                            color: .green,
                            url: url
                        )
                    }
                }

                // 2. COMMUNITY
                let cleanCommunity = title.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
                if let url = URL(string: "https://www.reddit.com/r/\(cleanCommunity)/") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COMMUNITY")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .tracking(0.6)
                            .padding(.top, 4)

                        guideItemRow(
                            title: "Reddit Community",
                            subtitle: "Diskussioner, builds & tips",
                            icon: "bubble.left.and.bubble.right.fill",
                            color: .orange,
                            url: url
                        )
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func guideItemRow(title: String, subtitle: String, icon: String, color: Color, url: URL) -> some View {
        Button {
            selectedGuide = GuideWebItem(title: title, subtitle: subtitle, icon: icon, color: color, url: url)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
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

        let hasData = !isMultiplayerOnly && ttb != nil && ((ttb?.hastily ?? 0) > 0 || (ttb?.normally ?? 0) > 0 || (ttb?.completely ?? 0) > 0)

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
                } else if hasData {
                    Text("Referens · HowLongToBeat")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if isMultiplayerOnly {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.blue)
                    Text("Flerspelarspel – ingen fast kampanjtid")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else if let ttb = ttb, hasData {
                VStack(spacing: 8) {
                    refBandRow(icon: "📖", name: "Main Story", val: ttb.mainStoryFormatted)
                    refBandRow(icon: "➕", name: "Main + Extra", val: ttb.mainExtraFormatted)
                    refBandRow(icon: "🏆", name: "Completionist", val: ttb.completionistFormatted)
                }
            } else {
                Text("Ingen speltidsstatistik tillgänglig än.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func refBandRow(icon: String, name: String, val: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 28, height: 28)
                Text(icon)
                    .font(.system(size: 13))
            }
            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(val)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    // MARK: - Fakta & Betyg (Konsoliderad tabell)

    private var factsAndRatingsSection: some View {
        let playerRating: String? = {
            if let tr = remote?.totalRating { return String(format: "%.1f/10", tr / 10.0) }
            if let ir = currentGame?.igdbRating { return String(format: "%.1f/10", ir) }
            return nil
        }()

        let criticRating: String? = {
            if let cr = remote?.aggregatedRating { return "\(Int(round(cr)))/100" }
            return nil
        }()

        let genresText: String? = {
            if let g = currentGame?.genres, !g.isEmpty {
                return g.joined(separator: ", ")
            }
            if let g = remote?.genres?.map(\.name), !g.isEmpty {
                return g.joined(separator: ", ")
            }
            return nil
        }()

        let platformsText: String? = {
            if let plats = remote?.platforms?.map(\.name), !plats.isEmpty {
                return plats.joined(separator: ", ")
            }
            if let plats = currentGame?.platforms, !plats.isEmpty {
                return plats.joined(separator: ", ")
            }
            return nil
        }()

        let dateText = formattedReleaseDate
        let developerName = remote?.developerName ?? currentGame?.developers.first
        let publisherName = remote?.publisherName

        return detailCard(title: "Fakta & Betyg") {
            VStack(spacing: 0) {
                // Betyg
                if playerRating != nil || criticRating != nil {
                    factRow(label: "Betyg") {
                        HStack(spacing: 6) {
                            if let pr = playerRating {
                                HStack(spacing: 3) {
                                    Text("★").foregroundStyle(.yellow)
                                    Text("\(pr) IGDB").bold()
                                }
                            }
                            if playerRating != nil && criticRating != nil {
                                Text("·").foregroundStyle(.secondary)
                            }
                            if let cr = criticRating {
                                HStack(spacing: 3) {
                                    Text("✅").font(.caption2)
                                    Text("\(cr) Kritiker").bold().foregroundStyle(.green)
                                }
                            }
                        }
                        .font(.subheadline)
                    }
                    Divider()
                }

                // Genre
                if let g = genresText, !g.isEmpty {
                    factRow(label: "Genre") {
                        Text(g)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                    Divider()
                }

                // Plattformar
                if let p = platformsText, !p.isEmpty {
                    factRow(label: "Plattformar") {
                        Text(p)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                    Divider()
                }

                // Lanseringsdatum
                if let d = dateText {
                    factRow(label: "Lanseringsdatum") {
                        Text(d)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    if (developerName != nil && !developerName!.isEmpty) || (publisherName != nil && !publisherName!.isEmpty) {
                        Divider()
                    }
                }

                // Utvecklare
                if let dev = developerName, !dev.isEmpty {
                    factRow(label: "Utvecklare") {
                        NavigationLink(destination: CompanyGamesView(companyName: dev, role: .developer)) {
                            HStack(spacing: 4) {
                                Text(dev)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.red)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    if publisherName != nil && !publisherName!.isEmpty {
                        Divider()
                    }
                }

                // Utgivare
                if let pub = publisherName, !pub.isEmpty {
                    factRow(label: "Utgivare") {
                        NavigationLink(destination: CompanyGamesView(companyName: pub, role: .publisher)) {
                            HStack(spacing: 4) {
                                Text(pub)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.red)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
    }

    private func factRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 105, alignment: .leading)
            Spacer()
            content()
        }
        .padding(.vertical, 10)
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



    private var allDLCsAndExpansions: [IGDBRelatedGame] {
        guard let remote = remote else { return [] }
        var combined: [IGDBRelatedGame] = []
        var seenIDs = Set<Int>()
        for item in (remote.dlcs ?? []) + (remote.expansions ?? []) {
            if !seenIDs.contains(item.id) {
                seenIDs.insert(item.id)
                combined.append(item)
            }
        }
        return combined
    }

    private func dlcsSection(_ games: [IGDBRelatedGame]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .foregroundStyle(.purple)
                Text("DLC & Expansioner")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("(\(games.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(games) { item in
                        NavigationLink(destination: GameDetailView(igdbID: item.id)) {
                            VStack(alignment: .leading, spacing: 6) {
                                CoverView(title: item.name ?? "DLC", url: item.coverURL, corner: 12, height: 135)
                                    .frame(width: 95, height: 135)
                                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

                                Text(item.name ?? "DLC")
                                    .font(.caption.bold())
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(.primary)
                                    .frame(width: 95, alignment: .topLeading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let g = currentGame, g.isOwned {
                let isTarget = profile.isTargetGoal(gameID: g.id)
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        profile.toggleTargetGoal(gameID: g.id)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                } label: {
                    Image(systemName: isTarget ? "target" : "target")
                        .symbolVariant(isTarget ? .fill : .none)
                        .foregroundStyle(isTarget ? .yellow : .primary)
                }
                .accessibilityLabel(isTarget ? "Ta bort som fokusmål" : "Sätt som fokusmål")
            }

            Button {
                showingShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }

    // MARK: - Helper logic

    private func cleanGameTitle(_ title: String) -> String {
        var t = title
        // 1. Ta bort text inom parenteser (t.ex. "(Xbox Series X|S)", "(2024)", "(Digital)")
        t = t.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
        // 2. Ta bort text inom hakparenteser (t.ex. "[PS5]")
        t = t.replacingOccurrences(of: "\\s*\\[[^]]*\\]", with: "", options: .regularExpression)
        // 3. Ta bort kända utgåve-suffix om de finns efter ':' eller '-'
        let patterns = [
            ":\\s*Vanguard Edition.*",
            ":\\s*Deluxe Edition.*",
            ":\\s*Collector's Edition.*",
            ":\\s*Premium Edition.*",
            ":\\s*Ultimate Edition.*",
            ":\\s*Standard Edition.*",
            ":\\s*Special Edition.*",
            "-\\s*Deluxe Edition.*",
            "-\\s*Collector's Edition.*"
        ]
        for pattern in patterns {
            t = t.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func configureInitialState() {
        print("[GameDetailView] configureInitialState triggered for mode: \(mode)")
        
        // Om vi redan laddat IGDB-informationen, gör inget (undvik onödig omladdning vid sheet eller flikbyte)
        if case .loaded = remoteState {
            return
        }

        let effectiveIGDBID: Int? = {
            switch mode {
            case .local(let g):
                return currentGame?.igdbID ?? g.igdbID
            case .igdb(let id):
                return id
            }
        }()

        if let id = effectiveIGDBID {
            Task { await loadRemote(id: id) }
        } else if let g = currentGame {
            Task { await ensureRemoteForLocal(g) }
        } else if case .local(let g) = mode {
            Task { await ensureRemoteForLocal(g) }
        }
    }

    private func ensureRemoteForLocal(_ g: Game) async {
        print("[GameDetailView] ensureRemoteForLocal searching IGDB for query: '\(g.title)'")
        await MainActor.run { remoteState = .loading }
        do {
            var searchResults = try await IGDBService.shared.searchGames(query: g.title)
            print("[GameDetailView] searchGames returned \(searchResults.count) results for '\(g.title)'")
            
            // Om inga resultat hittades med rå titel, prova rensad titel (tar bort konsoltaggar/utgåvor)
            if searchResults.isEmpty {
                let cleaned = cleanGameTitle(g.title)
                if cleaned != g.title && !cleaned.isEmpty {
                    print("[GameDetailView] Fallback searching IGDB with cleaned title: '\(cleaned)'")
                    searchResults = (try? await IGDBService.shared.searchGames(query: cleaned)) ?? []
                }
            }

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
        let cleanedTitle = cleanGameTitle(g.title).lowercased()
        let currentYear = Calendar.current.component(.year, from: Date())

        // 1. Exakt titel och samma år
        if g.releaseYear > 0 {
            if let match = results.first(where: { ($0.name.lowercased() == lowerTitle || cleanGameTitle($0.name).lowercased() == cleanedTitle) && $0.releaseYear == g.releaseYear }) {
                return match
            }
        }

        // 2. Om spelet är tänkt som framtida/kommande (>= currentYear), prioritera resultat som också är i framtiden
        if g.releaseYear >= currentYear {
            if let futureMatch = results.first(where: { ($0.name.lowercased() == lowerTitle || cleanGameTitle($0.name).lowercased() == cleanedTitle) && ($0.releaseYear ?? 0) >= currentYear }) {
                return futureMatch
            }
        }

        // 3. Exakt titel eller rensad match
        if let match = results.first(where: { $0.name.lowercased() == lowerTitle || cleanGameTitle($0.name).lowercased() == cleanedTitle }) {
            // Om vårt spel är tänkt som framtida, men match är ett gammalt spel och det finns alternativ
            if g.releaseYear >= currentYear, let rYear = match.releaseYear, rYear < currentYear {
                if let altFuture = results.first(where: { ($0.name.lowercased().hasPrefix(lowerTitle) || cleanGameTitle($0.name).lowercased().hasPrefix(cleanedTitle)) && ($0.releaseYear ?? 0) >= currentYear }) {
                    return altFuture
                }
            }
            return match
        }

        // 4. Spel med mest betyg och flest omdömen som börjar på samma namn (huvudspelet)
        let startingMatches = results.filter { $0.name.lowercased().hasPrefix(lowerTitle) || cleanGameTitle($0.name).lowercased().hasPrefix(cleanedTitle) }
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
                let localClean = cleanGameTitle(g.title).lowercased()
                let remoteClean = cleanGameTitle(game.name).lowercased()
                let currentYear = Calendar.current.component(.year, from: Date())

                // Om det sparade IGDB-ID:t råkade peka på helt fel spel
                if !remoteClean.contains(localClean) && !localClean.contains(remoteClean) {
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
                if g.platforms.isEmpty {
                    let available = game.platforms?.map(\.name) ?? []
                    let resolved = PlatformMatcher.resolvePlatforms(availableIGDBPlatforms: available, userProfilePlatforms: profile.platforms)
                    if !resolved.isEmpty {
                        g.platforms = resolved
                        changed = true
                    }
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
        store.update(updated)
    }

    private func updateStatus(_ status: PlayStatus, for g: Game) {
        var copy = g
        copy.status = status
        if status == .playing {
            copy.isBacklog = false
            if copy.lastPlayedDate == nil {
                copy.lastPlayedDate = Date()
            }
        }
        store.update(copy)
    }

    private func addRemoteToLibrary(_ d: IGDBGame) {
        let genres = d.genres?.map { $0.name } ?? []
        let available = d.platforms?.map { $0.name } ?? []
        let platforms = PlatformMatcher.resolvePlatforms(availableIGDBPlatforms: available, userProfilePlatforms: profile.platforms)
        let normalizedRating = (d.totalRating ?? 0.0) / 20.0
        let est = d.timeToBeat?.mainStoryHours ?? d.timeToBeat?.mainExtraHours
        let inferredTypes = Game.inferPlayTypes(
            genres: genres,
            title: d.name,
            gameModes: d.gameModes?.map(\.name)
        )

        let new = Game(
            title: d.name,
            platforms: platforms,
            releaseYear: d.releaseYear ?? 0,
            genres: genres,
            developers: d.developerName.map { [$0] } ?? [],
            status: .notStarted,
            rating: 0,
            igdbRating: normalizedRating,
            coverURL: d.coverURL,
            igdbID: d.id,
            firstReleaseDate: d.firstReleaseDate,
            estimatedHours: est,
            isOwned: false,
            playTypes: inferredTypes
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
                        .onChange(of: currentIndex) { _, newIndex in
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
