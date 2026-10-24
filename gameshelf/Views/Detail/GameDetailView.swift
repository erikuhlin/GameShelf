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
    @State private var showingCompletionCelebration = false
    @State private var selectedVideo: IGDBVideo? = nil
    @State private var toplistBadgeTitle: String? = nil
    @State private var toplistBadgeGenre: String? = nil
    @State private var showingToplistSheet = false

    // Spelframsteg state
    @State private var isEditingHours = false
    @State private var manualHoursInput = ""
    @State private var isEditingProgressNote = false
    @State private var progressNoteDraft = ""

    @FocusState private var isNotesFocused: Bool
    @State private var newTodoText: String = ""
    @ObservedObject private var priceWatcher = PriceWatcherService.shared

    enum LibraryDetailTab: String, CaseIterable, Identifiable {
        case myPlay = "Mitt spelande"
        case gameFacts = "Info"

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

    /// Alla plattformar spelet finns på (kombinerar IGDB och lokalt sparade plattformar så att bl.a. Xbox aldrig saknas i butikslänkar eller header)
    private var allGamePlatforms: [String] {
        var raw: [String] = []
        if let remotePlats = remote?.platforms?.map(\.name), !remotePlats.isEmpty {
            raw.append(contentsOf: remotePlats)
        }
        if let localPlats = currentGame?.platforms, !localPlats.isEmpty {
            raw.append(contentsOf: localPlats)
        }
        var seen = Set<String>()
        var unique: [String] = []
        for p in raw {
            let short = compactPlatformName(p)
            if seen.insert(short).inserted {
                unique.append(p)
            }
        }
        return unique
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
            return targetDate >= Calendar.current.startOfDay(for: Date())
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
                // --- LAGER 1: HERO HEADER (Identisk i alla lägen) ---
                heroHeader

                // --- LAGER 2, 3 & 4: STATUSRUTA -> KONTEXTKORT -> INNEHÅLL ---
                if let g = currentGame, g.isOwned {
                    // LÄGE C: BIBLIOTEK
                    libraryGameHeaderBar(g)

                    ReleaseCountdownBanner(
                        releaseDate: effectiveReleaseDate,
                        releaseYear: effectiveReleaseYear
                    )

                    libraryTabsBar

                    if isLoadingRemote {
                        remoteLoadingIndicator
                    } else if let errorMsg = remoteErrorMessage {
                        inlineErrorCard(message: errorMsg)
                    }

                    switch selectedLibraryTab {
                    case .myPlay:
                        myPlayTabContent(g)
                    case .gameFacts:
                        infoTabContent(includeTimeToBeat: false)
                    }
                } else if let g = currentGame, !g.isOwned {
                    // LÄGE B: ÖNSKELISTA
                    wishlistStatusCard(g)

                    ReleaseCountdownBanner(
                        releaseDate: effectiveReleaseDate,
                        releaseYear: effectiveReleaseYear
                    )

                    if isLoadingRemote {
                        remoteLoadingIndicator
                    } else if let errorMsg = remoteErrorMessage {
                        inlineErrorCard(message: errorMsg)
                    }

                    infoTabContent(includeTimeToBeat: !isUpcomingGame)
                } else if let r = remote {
                    // LÄGE A: EJ TILLAGD
                    unaddedActionsBar(r)

                    ReleaseCountdownBanner(
                        releaseDate: effectiveReleaseDate,
                        releaseYear: effectiveReleaseYear
                    )

                    infoTabContent(includeTimeToBeat: !isUpcomingGame)
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
            .frame(maxWidth: 880)
            .frame(maxWidth: .infinity, alignment: .center)
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
                    .environmentObject(store)
                    .environmentObject(profile)
            }
        }
        .sheet(isPresented: $showingLibraryStatusSheet) {
            LibraryStatusSheetView(
                title: currentGame?.title ?? remote?.name ?? "Spel",
                coverURL: currentGame?.coverURL ?? remote?.coverURL,
                isInLibrary: currentGame != nil,
                onSelectStatus: { status, isBacklog in
                    if let r = remote {
                        addRemoteWithStatus(r, status: status, isBacklog: isBacklog)
                    }
                },
                onRemove: {
                    if let g = currentGame {
                        store.games.removeAll(where: { $0.id == g.id })
                    }
                }
            )
            .presentationDetents([.height(350)])
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
        .sheet(isPresented: $showingCompletionCelebration) {
            if let g = currentGame {
                GameCompletionCelebrationSheet(game: g) { updatedGame in
                    updateLocal(updatedGame)
                    profile.removeTargetGoal(gameID: updatedGame.id)
                }
            }
        }
        .sheet(isPresented: $showingToplistSheet) {
            NavigationStack {
                ToplistView(prefillGenre: toplistBadgeGenre)
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
        .confirmationDialog(
            "Ta bort från biblioteket?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let g = currentGame {
                Button("Ta bort från biblioteket", role: .destructive) {
                    let igdbID = g.igdbID
                    store.games.removeAll(where: { $0.id == g.id })
                    if let id = igdbID {
                        mode = .igdb(id: id)
                    } else {
                        dismiss()
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Spelet och din loggade historik tas bort från ditt bibliotek.")
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

        let coverURL = currentGame?.coverURL ?? remote?.coverURL
        let genresList = currentGame?.genres.isEmpty == false ? currentGame?.genres : remote?.genres?.map(\.name)
        let genresText = genresList?.prefix(3).joined(separator: ", ")

        let communityRating: Double? = {
            if let tr = remote?.totalRating, tr > 0 { return tr / 10.0 }
            if let ir = currentGame?.igdbRating, ir > 0 { return ir }
            return nil
        }()

        let criticRating: Double? = {
            if let cr = remote?.aggregatedRating, cr > 0 { return cr / 10.0 }
            return nil
        }()

        let developer = remote?.developerName ?? currentGame?.developers.first
        let platforms = allGamePlatforms

        return VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                // Vänster: Omslagsbild (Poster)
                CoverView(title: title, url: coverURL, corner: 14, height: 160)
                    .frame(width: 110)
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)

                // Höger: Identisk header i alla lägen (A, B, C)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // IGDB- och kritikerbetyg (dölj om betyg saknas)
                    if communityRating != nil || criticRating != nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                if let cRating = communityRating {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.yellow)
                                        Text(cRating.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(cRating))" : String(format: "%.1f", cRating))
                                            .font(.caption.bold())
                                            .foregroundStyle(.primary)
                                        Text("IGDB")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(Capsule())
                                }

                                if let cr = criticRating {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.blue)
                                        Text(cr.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(cr))" : String(format: "%.1f", cr))
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
                        }
                        .padding(.vertical, 1)
                    }

                    // Släppdatum · Utvecklare
                    HStack(spacing: 5) {
                        if let dateText = formattedReleaseDate {
                            Text(dateText)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        if formattedReleaseDate != nil && developer != nil && !(developer?.isEmpty ?? true) {
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

                    // Genre
                    if let gText = genresText, !gText.isEmpty {
                        Text(gText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // Alla plattformar som små chips under genre-raden
                    if !platforms.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(platforms, id: \.self) { plat in
                                    HStack(spacing: 3) {
                                        Image(systemName: platformHeaderIcon(for: plat))
                                            .font(.system(size: 8.5, weight: .bold))
                                            .foregroundStyle(platformColor(for: plat))
                                        Text(compactPlatformName(plat))
                                            .font(.system(size: 9.5, weight: .semibold))
                                            .foregroundStyle(.primary)
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3.5)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Spelläge-chips & Åldersmärkningar
                    let modes = remote?.gameModes ?? []
                    let ageLabels = remote?.ageRatings?.compactMap({ $0.label }) ?? []
                    if !modes.isEmpty || !ageLabels.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(modes.prefix(3)) { mode in
                                    HStack(spacing: 3) {
                                        Image(systemName: gameModeIcon(mode.name))
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.secondary)
                                        Text(mode.name)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color(.tertiarySystemFill).opacity(0.65))
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                }

                                ForEach(ageLabels, id: \.self) { label in
                                    Text(label)
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(Color(.tertiarySystemFill).opacity(0.65))
                                        .foregroundStyle(.secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                }
                            }
                        }
                    }

                    // Topplist-indikator
                    if let badgeTitle = toplistBadgeTitle {
                        Button {
                            showingToplistSheet = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.yellow)
                                Text(badgeTitle)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.yellow)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.yellow.opacity(0.7))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Color.yellow.opacity(0.14))
                            .overlay(
                                Capsule()
                                    .stroke(Color.yellow.opacity(0.35), lineWidth: 0.8)
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 4)
    }

    private func platformHeaderIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("playstation") || lower.contains("ps") { return "playstation.logo" }
        if lower.contains("xbox") || lower.contains("series x") || lower.contains("series s") { return "xbox.logo" }
        if lower.contains("switch") || lower.contains("nintendo") { return "gamecontroller.fill" }
        if lower.contains("pc") || lower.contains("windows") || lower.contains("mac") { return "desktopcomputer" }
        return "gamecontroller.fill"
    }

    // MARK: - Läge C: Statusruta i Biblioteket

    private func libraryGameHeaderBar(_ g: Game) -> some View {
        let isTarget = profile.isTargetGoal(gameID: g.id)

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 1. Status (t.ex. Spelar nu)
                Menu {
                    Section("Status") {
                        ForEach(PlayStatus.allCases) { st in
                            Button {
                                if st == .completed && g.status != .completed && !g.isMultiplayerOrOngoing {
                                    showingCompletionCelebration = true
                                } else {
                                    var copy = g
                                    copy.status = st
                                    if st == .playing {
                                        copy.isBacklog = false
                                        if copy.lastPlayedDate == nil {
                                            copy.lastPlayedDate = Date()
                                        }
                                        // Det får inte gå att ha status Spelar nu och framsteg Klar samtidigt
                                        if copy.storyProgress == .completed {
                                            copy.storyProgress = .justStarted
                                        }
                                    } else if st == .completed {
                                        copy.storyProgress = .completed
                                    } else if copy.storyProgress == .completed {
                                        copy.storyProgress = nil
                                    }
                                    updateLocal(copy)
                                }
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
                        Section("Speldagbok") {
                            Button {
                                showingCompletionCelebration = true
                            } label: {
                                Label("Redigera genomspelning...", systemImage: "pencil.and.list.clipboard")
                            }
                        }

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

                    Section("Spelmål") {
                        Button {
                            withAnimation {
                                profile.toggleTargetGoal(gameID: g.id)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        } label: {
                            Label(
                                isTarget ? "Ta bort som Fokusmål" : "Sätt som Fokusmål",
                                systemImage: "target"
                            )
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(g.status.color)
                                .frame(width: 7, height: 7)
                            Text(g.statusDisplayTitle)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        Text("STATUS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(.secondaryLabel))
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 28)

                // 2. Spelar på (t.ex. PS5)
                Button {
                    showingPlatformSheet = true
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 5) {
                            Text(platformsSummaryText(g.platforms))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        Text("SPELAR PÅ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(.secondaryLabel))
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 28)

                // 3. Mitt betyg ("8/10" eller "Inte betygsatt")
                Menu {
                    Section("Sätt betyg (1–10)") {
                        if (g.rating ?? 0) > 0 {
                            Button("Rensa betyg", role: .destructive) {
                                var copy = g
                                copy.rating = nil
                                updateLocal(copy)
                            }
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
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            if let r = g.rating, r > 0 {
                                Image(systemName: "star.fill")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.yellow)
                                Text("\(r)/10")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Inte betygsatt")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        Text("MITT BETYG")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(.secondaryLabel))
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Fokusmål visas EN gång, som markör i statusrutan (matchar mockup)
            if isTarget || g.status == .completed {
                Divider()
                HStack(spacing: 10) {
                    if isTarget {
                        HStack(spacing: 5) {
                            Image(systemName: "record.circle")
                                .font(.system(size: 11, weight: .bold))
                            Text("Fokusmål")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.yellow)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .stroke(Color.yellow.opacity(0.55), lineWidth: 1)
                        )

                        let progress = GamingGoalEngine.calculateProgress(for: g)
                        if progress.hasTasks {
                            Text("\(progress.percentage) % · \(progress.completedTasks) av \(progress.totalTasks) klara")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                        } else if let sp = g.storyProgress {
                            Text("\(progress.percentage) % · \(sp.rawValue)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                        } else {
                            Text(progress.displaySubtext)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
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
                                Text(g.completedYear.map { "Klarat \($0)" } ?? "Välj klarat-år")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemFill).opacity(0.35))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func compactPlatformName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("playstation 5") || lower == "ps5" { return "PS5" }
        if lower.contains("playstation 4") || lower == "ps4" { return "PS4" }
        if lower.contains("playstation 3") || lower == "ps3" { return "PS3" }
        if lower.contains("playstation 2") || lower == "ps2" { return "PS2" }
        if lower.contains("playstation") || lower == "ps1" || lower == "psx" { return "PS1" }
        if lower.contains("switch 2") { return "Switch 2" }
        if lower.contains("switch") { return "Switch" }
        if lower.contains("series x") || lower.contains("series s") || lower.contains("xbox series") { return "Xbox Series X|S" }
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
        let compact = platforms.map {
            let c = compactPlatformName($0)
            return c == "Xbox Series X|S" ? "Xbox" : c
        }
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
                                Image(systemName: platformHeaderIcon(for: platform))
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
                    Text("Välj vilken plattform du spelar eller äger spelet på.")
                        .font(.caption)
                }
            }
            .navigationTitle("Spelar på")
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
        if lower.contains("xbox") || lower.contains("series x") || lower.contains("series s") { return .green }
        if lower.contains("switch") || lower.contains("nintendo") { return .red }
        return .secondary
    }

    // MARK: - Läge A: Statusruta (Ej tillagd)

    private func unaddedActionsBar(_ r: IGDBGame) -> some View {
        HStack(spacing: 10) {
            // 1. Primär: Lägg till i bibliotek (röd)
            Button {
                showingLibraryStatusSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.subheadline.bold())
                    Text("Lägg till i bibliotek")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            // 2. Sekundär: Önskelista (ikon + text)
            Button {
                addRemoteToWishlist(r)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                    Text("Önskelista")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Läge B: Statusruta (Önskelista – sammanslagen i en ruta)

    private func wishlistStatusCard(_ g: Game) -> some View {
        let dateStr = formattedDateAdded(g.dateAdded)

        return VStack(spacing: 12) {
            // Övre rad: "♥ På önskelistan · Tillagd 27 aug." + textlänk "Ta bort"
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.caption.bold())

                Text("På önskelistan")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("·")
                    .foregroundStyle(.secondary)

                Text("Tillagd \(dateStr)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    showingRemoveWishlistAlert = true
                } label: {
                    Text("Ta bort")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Undre rad: Primärknapp "Flytta till biblioteket"
            Button {
                showingMoveToLibraryDialog = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.subheadline.bold())
                    Text("Flytta till biblioteket")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Rea & Priskort (Önskelista & Sök)
    @ViewBuilder
    private func dealCard(title: String) -> some View {
        if let deal = priceWatcher.deal(forTitle: title), deal.isOnSale {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Text("Aktiv rea hos \(deal.storeName)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Text(deal.savingsFormatted)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(
                            LinearGradient(colors: [Color.red, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Capsule()
                        )
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(deal.formattedSalePrice)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.primary)

                    Text(deal.formattedNormalPrice)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .strikethrough()

                    if deal.isHistoricalLow {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10))
                            Text("All-time low!")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.yellow.opacity(0.15), in: Capsule())
                    }
                }

                if let url = deal.dealURL {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Text("Gå till erbjudandet hos \(deal.storeName)")
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
            )
        }
    }

    // MARK: - Diskret Pris- & Butiksrad (under Media)
    @ViewBuilder
    private func storeQuickLinksSection(title: String, platforms: [String]) -> some View {
        let links = priceWatcher.storeLinks(title: title, platforms: platforms)
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "bag")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Kolla pris & butiker")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(links) { link in
                            Link(destination: link.url) {
                                HStack(spacing: 5) {
                                    Image(systemName: link.iconSystemName)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(link.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(Color(.secondarySystemGroupedBackground).opacity(0.85))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color(.separator).opacity(0.35), lineWidth: 0.7)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func formattedDateAdded(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        let calendar = Calendar.current
        if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "d MMM"
        } else {
            formatter.dateFormat = "d MMM yyyy"
        }
        return formatter.string(from: date)
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
        let normalizedRating: Double? = (r.totalRating ?? 0) > 0 ? (r.totalRating! / 10.0) : nil
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
            if g.status == .completed {
                completedCelebrationCard(g)
            }
            if !g.isMultiplayerOrOngoing {
                playtimeProgressCard(g)
            } else {
                multiplayerPlaytimeCard(g)
            }
            notesCard(g)
            collectionsCard(g)
        }
    }

    // MARK: - Genomspelningskort & Mini-recension
    private func completedCelebrationCard(_ g: Game) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: Color.orange.opacity(0.4), radius: 4, y: 2)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Klarat")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    if let date = g.completedDate {
                        Text("Avklarat \(formatCompletionDate(date))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Spelminne / Nostalgi")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                }

                Spacer()

                Button {
                    showingCompletionCelebration = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.caption2)
                        Text("Redigera")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                if let r = g.rating, r > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text("\(r)")
                            .font(.headline.bold())
                            .foregroundStyle(.yellow)
                        Text("/ 10")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                }

                if let hours = g.hoursPlayed, hours > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(String(format: hours.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f h" : "%.1f h", hours))
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                }

                if let plat = g.platforms.first {
                    HStack(spacing: 4) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                        Text(plat)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.2), lineWidth: 0.8)
        )
    }

    private func formatCompletionDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "d MMMM yyyy"
        return df.string(from: date)
    }

    // MARK: - Innehållslager (Om spelet, Speltid, Media, Köp, Liknande spel, Guider, Relaterat, Fakta)

    @ViewBuilder
    private func infoTabContent(includeTimeToBeat: Bool) -> some View {
        let gameTitle = currentGame?.title ?? remote?.name ?? ""

        VStack(spacing: 16) {
            // 1. Om spelet
            aboutGameSection

            // 2. Speltid (kompakt) – visas bara om ej i Bibliotek-Info, ej osläppt och data finns
            if includeTimeToBeat && !isUpcomingGame {
                compactTimeToBeatSection(remote?.timeToBeat)
            }

            // 3. Media (Skärmdumpar & Horisontell Trailerkarusell)
            if let screenshots = remote?.screenshots, !screenshots.isEmpty {
                screenshotsSection(screenshots)
            }
            if let videos = remote?.videos, !videos.isEmpty {
                trailersSection(videos)
            }

            // 4. Köp / Kolla pris & butiker (placerad under Media och diskretare, med alla spelets plattformar)
            if !gameTitle.isEmpty {
                dealCard(title: gameTitle)
                storeQuickLinksSection(title: gameTitle, platforms: allGamePlatforms)
            }

            // 5. Liknande spel
            if let similar = remote?.similarGames, !similar.isEmpty {
                similarGamesStandaloneSection(similar)
            }

            // 6. Guider & Resurser (dölj när spelet är osläppt)
            if !isUpcomingGame {
                guidesSection
            }

            // 7. Relaterat (Spelserie, DLC & Expansioner – dölj helt om tom)
            relatedSection

            // 8. Fakta (rensad från dubbletter som redan finns i headern)
            factsAndRatingsSection
        }
    }

    // MARK: - Spelframsteg (Enhetlig HLTB-tidslinje, Etapper under Spelar nu & 1:1 Walkthrough)

    private func playtimeProgressCard(_ g: Game) -> some View {
        let hours = g.effectiveHoursPlayed
        let mainHours = remote?.timeToBeat?.mainStoryHours ?? 0
        let extraHours = remote?.timeToBeat?.mainExtraHours ?? 0
        let compHours = remote?.timeToBeat?.completionistHours ?? 0
        let hasHLTB = mainHours > 0 || extraHours > 0 || compHours > 0

        let hoursDisplay: String = {
            if hours == 0 { return "0h" }
            if hours.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(hours))h"
            } else {
                return "\(String(format: "%.1f", hours))h"
            }
        }()

        // Under "Spelar nu" får framsteg ALDRIG vara .completed ("Klar")
        let activeMilestone: GameStoryProgress = {
            if let sp = g.storyProgress, sp != .completed {
                return sp
            }
            return .justStarted
        }()

        return detailCard(title: "Spelframsteg") {
            VStack(alignment: .leading, spacing: 16) {
                // 1. Loggad tid + snabbknappar
                playtimeHoursSection(g, hours: hours, hoursDisplay: hoursDisplay)

                // 2. EN sammanslagen tidslinje med markeringar vid Main / Extra / 100%
                if hasHLTB {
                    unifiedHLTBTimelineSection(hours: hours, mainHours: mainHours, extraHours: extraHours, compHours: compHours)
                }

                // 3. "Var är du i spelet?" visas BARA när status är Spelar nu
                if g.status == .playing {
                    playtimeMilestonesSection(g, currentMilestone: activeMilestone)
                }

                // 4. 1:1 Kapitellista & Story är tillgänglig för alla spel i biblioteket
                GameWalkthroughSectionView(
                    game: g,
                    remoteIGDBID: remote?.id,
                    onUpdateGame: { updated in
                        updateLocal(updated)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func playtimeHoursSection(_ g: Game, hours: Double, hoursDisplay: String) -> some View {
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

                Text("timmar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Klar") {
                    saveManualHours(for: g)
                }
                .font(.caption.bold())
                .padding(.horizontal, 14)
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
        } else if hours == 0 {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Speltid")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Ingen tid loggad")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    manualHoursInput = ""
                    isEditingHours = true
                } label: {
                    Label("Logga tid", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack(alignment: .center) {
                Button {
                    manualHoursInput = hours.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(hours))" : String(format: "%.1f", hours)
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

                Spacer()

                HStack(spacing: 6) {
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
    }

    // MARK: - Enhetlig HLTB-tidslinje (En enda tidslinje med markeringar vid Main / Extra / 100%)
    @ViewBuilder
    private func unifiedHLTBTimelineSection(hours: Double, mainHours: Int, extraHours: Int, compHours: Int) -> some View {
        let maxTarget = max(compHours, max(extraHours, mainHours))
        let fillRatio = maxTarget > 0 ? min(1.0, hours / Double(maxTarget)) : 0.0

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TIDSLINJE · HOWLONGTOBEAT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)
                Spacer()
                let parts: [String] = [
                    mainHours > 0 ? "\(mainHours)" : nil,
                    extraHours > 0 ? "\(extraHours)" : nil,
                    compHours > 0 ? "\(compHours)" : nil
                ].compactMap { $0 }
                if !parts.isEmpty {
                    Text("\(parts.joined(separator: " / ")) tim")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            // Själva tidslinjen med markeringar
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    // Bakgrundsspår
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 8)

                    // Fyllnad när tid loggas
                    if fillRatio > 0 {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, width * CGFloat(fillRatio)), height: 8)
                    }

                    // Markör för Main Story
                    if mainHours > 0 && maxTarget > 0 {
                        let pos = width * CGFloat(Double(mainHours) / Double(maxTarget))
                        Rectangle()
                            .fill(hours >= Double(mainHours) ? Color.white : Color.secondary.opacity(0.6))
                            .frame(width: 2, height: 14)
                            .offset(x: min(width - 2, max(0, pos - 1)))
                    }

                    // Markör för Main + Extra
                    if extraHours > 0 && maxTarget > 0 {
                        let pos = width * CGFloat(Double(extraHours) / Double(maxTarget))
                        Rectangle()
                            .fill(hours >= Double(extraHours) ? Color.white : Color.secondary.opacity(0.6))
                            .frame(width: 2, height: 14)
                            .offset(x: min(width - 2, max(0, pos - 1)))
                    }

                    // Markör för 100% (Completionist)
                    if compHours > 0 && maxTarget > 0 {
                        Rectangle()
                            .fill(hours >= Double(compHours) ? Color.green : Color.secondary.opacity(0.6))
                            .frame(width: 2, height: 14)
                            .offset(x: max(0, width - 2))
                    }
                }
            }
            .frame(height: 14)

            // Etiketter under tidslinjen
            HStack {
                if mainHours > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(hours >= Double(mainHours) ? Color.red : Color.secondary.opacity(0.4))
                            .frame(width: 6, height: 6)
                        Text("Main \(mainHours)h")
                            .font(.caption2.weight(hours >= Double(mainHours) ? .bold : .medium))
                            .foregroundStyle(hours >= Double(mainHours) ? .primary : .secondary)
                    }
                }
                Spacer()
                if extraHours > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(hours >= Double(extraHours) ? Color.orange : Color.secondary.opacity(0.4))
                            .frame(width: 6, height: 6)
                        Text("+Extra \(extraHours)h")
                            .font(.caption2.weight(hours >= Double(extraHours) ? .bold : .medium))
                            .foregroundStyle(hours >= Double(extraHours) ? .primary : .secondary)
                    }
                }
                Spacer()
                if compHours > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(hours >= Double(compHours) ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 6, height: 6)
                        Text("100% \(compHours)h")
                            .font(.caption2.weight(hours >= Double(compHours) ? .bold : .medium))
                            .foregroundStyle(hours >= Double(compHours) ? .primary : .secondary)
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func playtimeMilestonesSection(_ g: Game, currentMilestone: GameStoryProgress) -> some View {
        // Endast de 3 pågående etapperna under "Spelar nu" – aldrig "Klar" samtidigt som "Spelar nu"
        let inProgressStages: [GameStoryProgress] = [.justStarted, .midway, .nearEnd]

        VStack(alignment: .leading, spacing: 8) {
            Text("Var är du i spelet?")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(inProgressStages) { milestone in
                    let isSelected = (currentMilestone == milestone)
                    Button {
                        var copy = g
                        copy.storyProgress = milestone
                        updateLocal(copy)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Text(milestone.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .padding(.horizontal, 6)
                            .background(isSelected ? Color.red : Color(.tertiarySystemFill))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
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

                // Story / Uppdragslista även för pågående eller kampanjer i multiplayer-spel
                GameWalkthroughSectionView(
                    game: g,
                    remoteIGDBID: remote?.id,
                    onUpdateGame: { updated in
                        updateLocal(updated)
                    }
                )
            }
        }
    }

    private func moveToWishlist(_ g: Game) {
        var copy = g
        copy.isOwned = false
        copy.isBacklog = false
        copy.status = .notStarted
        updateLocal(copy)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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

    private func gameModeIcon(_ mode: String) -> String {
        let lower = mode.lowercased()
        if lower.contains("single") { return "person.fill" }
        if lower.contains("co-op") || lower.contains("cooperative") { return "person.2.fill" }
        if lower.contains("multiplayer") { return "person.3.fill" }
        if lower.contains("split") { return "rectangle.split.2x1.fill" }
        if lower.contains("mmo") { return "globe" }
        return "gamecontroller.fill"
    }

    // MARK: - Liknande spel (Fristående sektion i innehållsflödet)

    @ViewBuilder
    private func similarGamesStandaloneSection(_ similar: [IGDBRelatedGame]) -> some View {
        let validSimilar = similar.filter { isOfficialValidRelatedItem($0) }
        if !validSimilar.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Liknande spel")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        showingSimilarGamesSheet = true
                    } label: {
                        Text("Visa alla")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(validSimilar) { game in
                            NavigationLink(destination: GameDetailView(igdbID: game.id).environmentObject(store).environmentObject(profile)) {
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
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// Filtrerar bort poster utan omslag eller släppdatum ("Untitled Expansion", platshållare) och fanprojekt
    private func isOfficialValidRelatedItem(_ item: IGDBRelatedGame) -> Bool {
        guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return false
        }
        guard item.coverURL != nil else {
            return false
        }
        guard let year = item.releaseYear, year > 1970 else {
            return false
        }
        let lower = name.lowercased()
        let bannedKeywords = [
            "untitled", "tba", "placeholder", "cancelled", "canceled",
            "fan project", "fan remake", "fan made", "mod ", " mod",
            "demo", "beta", "playtest", "bundle", "soundtrack", "artbook"
        ]
        if bannedKeywords.contains(where: { lower.contains($0) }) {
            return false
        }
        return true
    }

    // MARK: - Relaterat (Spelserie & DLC – dölj helt om tom, filtrera och sortera efter år)

    @ViewBuilder
    private var relatedSection: some View {
        let currentID = remote?.id ?? currentGame?.igdbID
        let franchiseGames = (remote?.franchiseGames ?? [])
            .filter { $0.id != currentID && isOfficialValidRelatedItem($0) }
            .sorted { ($0.releaseYear ?? 9999) < ($1.releaseYear ?? 9999) }

        let dlcs = allDLCsAndExpansions
            .filter { isOfficialValidRelatedItem($0) }
            .sorted { ($0.releaseYear ?? 9999) < ($1.releaseYear ?? 9999) }

        let franchiseName = remote?.franchiseName ?? "Spelserie"

        // Dölj tomma sektioner helt ("Relaterat" utan innehåll visas inte)
        if !franchiseGames.isEmpty || !dlcs.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Relaterat")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }

                // Spelserie (sorterad efter år, endast officiella titlar med omslag & datum)
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
                                    NavigationLink(destination: GameDetailView(igdbID: game.id).environmentObject(store).environmentObject(profile)) {
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
                                    NavigationLink(destination: GameDetailView(igdbID: item.id).environmentObject(store).environmentObject(profile)) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            CoverView(title: item.name ?? "DLC", url: item.coverURL, corner: 10, height: 128)
                                                .frame(width: 96, height: 128)
                                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                                            Text(item.name ?? "DLC")
                                                .font(.caption2.bold())
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                                .foregroundStyle(.primary)
                                                .frame(width: 96, alignment: .topLeading)

                                            if let year = item.releaseYear {
                                                Text(String(year))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
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
        if let title = currentGame?.title ?? remote?.name, !title.isEmpty {
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

    // MARK: - Samlingar (Emoji + Namn)

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
                                    Button {
                                        showingCollectionsSheet = true
                                    } label: {
                                        HStack(spacing: 5) {
                                            Text(col.displayEmoji)
                                                .font(.caption)
                                            Text(col.cleanName)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.primary)
                                        }
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6)
                                        .background(Color(.tertiarySystemFill))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
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

    // MARK: - Sammanslagen Anteckningsruta ("Var jag är" + "Mina anteckningar" med automatisk höjd)

    private func notesCard(_ g: Game) -> some View {
        let personalTodos = g.todos.filter { $0.chapterGroup == nil && $0.order == nil }

        return detailCard(title: "Anteckningar") {
            VStack(alignment: .leading, spacing: 14) {
                // 1. Kort fält för "Var jag är" (progressNote)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Var jag är")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let updated = g.noteUpdatedAt {
                            Text("Uppdaterad \(formattedRelativeDate(updated))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    TextField(
                        "T.ex. Akt 2, precis vid bossen i slottet...",
                        text: Binding<String>(
                            get: { g.progressNote ?? "" },
                            set: { newValue in
                                var copy = g
                                let trimmed = String(newValue.prefix(140))
                                copy.progressNote = trimmed.isEmpty ? nil : trimmed
                                copy.noteUpdatedAt = Date()
                                updateLocal(copy)
                            }
                        )
                    )
                    .focused($isNotesFocused)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // 2. Fritextfält för "Mina anteckningar" med placeholder och automatisk höjd (inte en stor tom ruta)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mina anteckningar")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    TextField(
                        "Skriv tankar, builds, minnen eller omdöme...",
                        text: Binding<String>(
                            get: { g.notes },
                            set: { newNotes in
                                var copy = g
                                copy.notes = newNotes
                                updateLocal(copy)
                            }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(1...8)
                    .focused($isNotesFocused)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // 3. Eventuella egna delmål (som inte tillhör 1:1-walkthroughn)
                if !personalTodos.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Egna mål")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        ForEach(personalTodos) { item in
                            HStack(spacing: 10) {
                                Button {
                                    var copy = g
                                    if let idx = copy.todos.firstIndex(where: { $0.id == item.id }) {
                                        copy.todos[idx].isDone.toggle()
                                        updateLocal(copy)
                                    }
                                } label: {
                                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                        .font(.subheadline)
                                        .foregroundStyle(item.isDone ? .green : .secondary)
                                }
                                .buttonStyle(.plain)

                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundStyle(item.isDone ? .secondary : .primary)
                                    .strikethrough(item.isDone, color: .secondary)

                                Spacer()

                                Button {
                                    var copy = g
                                    copy.todos.removeAll(where: { $0.id == item.id })
                                    updateLocal(copy)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(.tertiarySystemGroupedBackground).opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            }
        }
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
            Text("Om spelet")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 6) {
                if isTextAvailable, let text = textToShow {
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(showingFullSummary ? nil : 3)
                        .lineSpacing(3)

                    if text.count > 120 {
                        Button {
                            withAnimation {
                                showingFullSummary.toggle()
                            }
                        } label: {
                            Text(showingFullSummary ? "mindre" : "mer")
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

    @ViewBuilder
    private func compactTimeToBeatSection(_ ttb: IGDBTimeToBeat?) -> some View {
        let title = currentGame?.title ?? remote?.name ?? "Spel"
        let genres = currentGame?.genres ?? remote?.genres?.map(\.name) ?? []
        let gameModes = remote?.gameModes?.map(\.name) ?? []
        let isMultiplayerOnly = isPureMultiplayer(gameModes: gameModes, gameTitle: title, genres: genres)
        let hasData = !isMultiplayerOnly && ttb != nil && ((ttb?.hastily ?? 0) > 0 || (ttb?.normally ?? 0) > 0 || (ttb?.completely ?? 0) > 0)

        if let ttb = ttb, hasData {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Speltid")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("HowLongToBeat")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .center, spacing: 16) {
                    // Main Story (Stort)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Main Story")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(ttb.mainStoryFormatted)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Divider()
                        .frame(height: 36)

                    // Main + Extra & Completionist (Sekundär text)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Main + Extra")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(ttb.mainExtraFormatted)
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                        }
                        HStack {
                            Text("Completionist")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(ttb.completionistFormatted)
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func isPureMultiplayer(gameModes: [String], gameTitle: String, genres: [String]) -> Bool {
        let lowerModes = gameModes.map { $0.lowercased() }
        let lowerTitle = gameTitle.lowercased()
        let lowerGenres = genres.map { $0.lowercased() }

        let pureMultiplayerKeywords = [
            "hell let loose", "counter-strike", "cs:go", "cs2", "overwatch", "valorant",
            "league of legends", "dota", "apex legends", "pubg", "rainbow six siege",
            "rocket league", "fall guys", "dead by daylight", "team fortress", "world of tanks",
            "war thunder", "battlefield 2042", "sea of thieves", "rust", "dayz"
        ]

        if pureMultiplayerKeywords.contains(where: { lowerTitle.contains($0) }) {
            return true
        }

        if lowerModes.contains(where: { $0.contains("single player") || $0.contains("single-player") || $0.contains("ensamspelare") }) {
            return false
        }

        if !lowerModes.isEmpty && lowerModes.contains(where: { $0.contains("multiplayer") || $0.contains("co-operative") || $0.contains("mmo") }) {
            return true
        }

        if lowerGenres.contains(where: { $0.contains("moba") || $0.contains("card") }) && !lowerModes.contains(where: { $0.contains("single") }) {
            return true
        }

        return false
    }

    // MARK: - Fakta (Rensad från dubbletter i headern)

    @ViewBuilder
    private var factsAndRatingsSection: some View {
        let platformsText: String? = {
            if let plats = remote?.platforms?.map(\.name), !plats.isEmpty {
                return plats.joined(separator: ", ")
            }
            if let plats = currentGame?.platforms, !plats.isEmpty {
                return plats.joined(separator: ", ")
            }
            return nil
        }()

        let developerName = (remote?.developerName ?? currentGame?.developers.first)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let publisherName = remote?.publisherName?.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasDev = developerName != nil && !developerName!.isEmpty
        let hasPub = publisherName != nil && !publisherName!.isEmpty
        let isSameCompany: Bool = {
            guard let d = developerName, let p = publisherName, hasDev, hasPub else { return false }
            return d.caseInsensitiveCompare(p) == .orderedSame
        }()

        let hasAnyFact = (platformsText != nil && !platformsText!.isEmpty) || hasDev || hasPub

        if hasAnyFact {
            detailCard(title: "Fakta") {
                VStack(spacing: 0) {
                    if let p = platformsText, !p.isEmpty {
                        factRow(label: "Plattformar") {
                            Text(p)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.trailing)
                        }
                        if hasDev || hasPub {
                            Divider()
                        }
                    }

                    if isSameCompany, let company = developerName {
                        factRow(label: "Utvecklare & utgivare") {
                            NavigationLink(destination: CompanyGamesView(companyName: company, role: .developer).environmentObject(store).environmentObject(profile)) {
                                HStack(spacing: 4) {
                                    Text(company)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.red)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    } else {
                        if let dev = developerName, hasDev {
                            factRow(label: "Utvecklare") {
                                NavigationLink(destination: CompanyGamesView(companyName: dev, role: .developer).environmentObject(store).environmentObject(profile)) {
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
                            if hasPub {
                                Divider()
                            }
                        }

                        if let pub = publisherName, hasPub {
                            factRow(label: "Utgivare") {
                                NavigationLink(destination: CompanyGamesView(companyName: pub, role: .publisher).environmentObject(store).environmentObject(profile)) {
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
        }
    }

    private func factRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 145, alignment: .leading)
            Spacer()
            content()
        }
        .padding(.vertical, 10)
    }

    private func uniqueVideoTitle(for video: IGDBVideo, at index: Int, in videos: [IGDBVideo]) -> String {
        let base = (video.name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Trailer"
        let matchingIndices = videos.enumerated().compactMap { idx, v -> Int? in
            let name = (v.name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Trailer"
            return name.caseInsensitiveCompare(base) == .orderedSame ? idx : nil
        }
        if matchingIndices.count > 1, let occurrence = matchingIndices.firstIndex(of: index) {
            return "\(base) #\(occurrence + 1)"
        }
        return base
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                        Button {
                            selectedVideo = video
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    AsyncImage(url: video.thumbnailURL) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 240, height: 135)
                                                // Beskär bort 4:3 svarta kanter på YouTube hqdefault-miniatyrer (t.ex. Dev Diary)
                                                .scaleEffect(1.16)
                                                .frame(width: 240, height: 135)
                                                .clipped()
                                        } else {
                                            Rectangle()
                                                .fill(Color(.tertiarySystemFill))
                                                .frame(width: 240, height: 135)
                                        }
                                    }

                                    Image(systemName: "play.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .padding(12)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .frame(width: 240, height: 135)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Text(uniqueVideoTitle(for: video, at: index, in: videos))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .frame(width: 240, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
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
                        NavigationLink(destination: GameDetailView(igdbID: item.id).environmentObject(store).environmentObject(profile)) {
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

            AnyView(content())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showingShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }

            Menu {
                if let g = currentGame, g.isOwned {
                    let isTarget = profile.isTargetGoal(gameID: g.id)
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            profile.toggleTargetGoal(gameID: g.id)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    } label: {
                        Label(
                            isTarget ? "Ta bort som fokusmål" : "Sätt som fokusmål",
                            systemImage: isTarget ? "target" : "scope"
                        )
                    }

                    Button {
                        showingCollectionsSheet = true
                    } label: {
                        Label("Samlingar", systemImage: "folder")
                    }

                    Divider()

                    Button {
                        moveToWishlist(g)
                    } label: {
                        Label("Flytta till önskelistan", systemImage: "heart")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Ta bort från biblioteket", systemImage: "trash")
                    }
                } else if let g = currentGame, !g.isOwned {
                    Button {
                        showingMoveToLibraryDialog = true
                    } label: {
                        Label("Flytta till biblioteket", systemImage: "plus.circle")
                    }

                    Button(role: .destructive) {
                        showingRemoveWishlistAlert = true
                    } label: {
                        Label("Ta bort från önskelistan", systemImage: "trash")
                    }
                } else if let d = remote {
                    Button {
                        addRemoteToLibrary(d)
                    } label: {
                        Label("Lägg till i bibliotek", systemImage: "plus.circle")
                    }

                    Button {
                        addRemoteToWishlist(d)
                    } label: {
                        Label("Lägg på önskelistan", systemImage: "heart")
                    }
                }

                Divider()

                Button {
                    showingShareSheet = true
                } label: {
                    Label("Dela spel", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
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
            Task { await loadToplistBadge(id: id) }
        } else if let g = currentGame {
            Task { await ensureRemoteForLocal(g) }
        } else if case .local(let g) = mode {
            Task { await ensureRemoteForLocal(g) }
        }

        if let g = currentGame {
            Task { await priceWatcher.fetchDeals(for: [g]) }
        } else if case .local(let g) = mode {
            Task { await priceWatcher.fetchDeals(for: [g]) }
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
            Task {
                await priceWatcher.fetchDeal(title: game.name)
            }
            Task {
                await loadToplistBadge(id: game.id)
            }
        } catch {
            print("[GameDetailView] Failed loadRemote for IGDB ID \(id): \(error.localizedDescription)")
            await MainActor.run {
                remoteState = .error("Kunde inte hämta detaljer från IGDB (\(error.localizedDescription)).")
            }
        }
    }

    private func loadToplistBadge(id: Int) async {
        guard let ratingItem = await ToplistService.shared.fetchGameRating(igdbID: id) else {
            return
        }

        var title: String? = nil
        var genre: String? = nil

        if let overall = ratingItem.overall_rank, overall > 0, overall <= 100 {
            title = "#\(overall) på Topp 100 Spel"
        } else if let genreRanks = ratingItem.genre_ranks, !genreRanks.isEmpty {
            let sorted = genreRanks.sorted { $0.value < $1.value }
            if let best = sorted.first, best.value > 0, best.value <= 100 {
                let short = (best.key == "Role-playing (RPG)") ? "RPG" : best.key
                title = "#\(best.value) på Topp 100 \(short)"
                genre = best.key
            }
        }

        if let t = title {
            await MainActor.run {
                self.toplistBadgeTitle = t
                self.toplistBadgeGenre = genre
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

    private func addRemoteWithStatus(
        _ d: IGDBGame,
        status: PlayStatus,
        isBacklog: Bool = false
    ) {
        let genres = d.genres?.map { $0.name } ?? []
        let available = d.platforms?.map { $0.name } ?? []
        let platforms = PlatformMatcher.resolvePlatforms(availableIGDBPlatforms: available, userProfilePlatforms: profile.platforms)
        let normalizedRating: Double? = (d.totalRating ?? 0) > 0 ? (d.totalRating! / 10.0) : nil
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
            status: status,
            rating: 0,
            igdbRating: normalizedRating,
            coverURL: d.coverURL,
            igdbID: d.id,
            firstReleaseDate: d.firstReleaseDate,
            estimatedHours: est,
            isOwned: true,
            playTypes: inferredTypes,
            isBacklog: isBacklog,
            lastPlayedDate: status == .playing ? Date() : nil,
            completedYear: status == .completed ? (d.releaseYear.map { $0 > 0 ? $0 : nil } ?? nil) : nil,
            completedDate: nil,
            storyProgress: status == .completed ? .completed : nil
        )
        store.add(new)
        mode = .local(new)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func addRemoteToLibrary(_ d: IGDBGame) {
        addRemoteWithStatus(d, status: .notStarted, isBacklog: true)
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

    private func uniqueVideoTitle(for video: IGDBVideo, at index: Int) -> String {
        let base = (video.name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Trailer"
        let matchingIndices = videos.enumerated().compactMap { idx, v -> Int? in
            let name = (v.name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Trailer"
            return name.caseInsensitiveCompare(base) == .orderedSame ? idx : nil
        }
        if matchingIndices.count > 1, let occurrence = matchingIndices.firstIndex(of: index) {
            return "\(base) #\(occurrence + 1)"
        }
        return base
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                            Button {
                                onSelectVideo(video)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        AsyncImage(url: video.thumbnailURL) { phase in
                                            if let image = phase.image {
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 110, height: 68)
                                                    .scaleEffect(1.16)
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
                                    }
                                    .frame(width: 110, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(uniqueVideoTitle(for: video, at: index))
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)

                                        Text("Spela video")
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
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(games) { game in
                            NavigationLink(destination: GameDetailView(igdbID: game.id).environmentObject(store).environmentObject(profile)) {
                                HStack(spacing: 14) {
                                    CoverView(title: game.name ?? "Spel", url: game.coverURL, corner: 8, height: 100)
                                        .frame(width: 70)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(game.name ?? "Spel")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)

                                        HStack(spacing: 6) {
                                            if let year = game.releaseYear, year > 0 {
                                                Text(year > Calendar.current.component(.year, from: Date()) ? "Kommande" : "\(year)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            if let r = game.ratingOutOfTen {
                                                if game.releaseYear != nil && (game.releaseYear ?? 0) > 0 {
                                                    Text("•")
                                                        .font(.caption)
                                                        .foregroundStyle(.tertiary)
                                                }

                                                HStack(spacing: 3) {
                                                    Image(systemName: "star.fill")
                                                        .foregroundStyle(.yellow)
                                                        .font(.caption)
                                                    Text(r.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(r))" : String(format: "%.1f", r))
                                                        .font(.caption.bold())
                                                        .foregroundStyle(.primary)
                                                }
                                            } else if game.releaseYear == nil || (game.releaseYear ?? 0) == 0 {
                                                Text("Ej betygsatt")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }

                                    Spacer()

                                    let isInLibrary = store.games.contains { $0.igdbID == game.id }
                                    Image(systemName: isInLibrary ? "checkmark.circle.fill" : "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(isInLibrary ? .green : .red)
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
    let onSelectStatus: (PlayStatus, Bool) -> Void
    let onRemove: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Header row with mini cover and title
            HStack(spacing: 12) {
                CoverView(title: title, url: coverURL, corner: 6, height: 48)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !isInLibrary {
                        Text("Välj hur du vill lägga till spelet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            VStack(spacing: 10) {
                if isInLibrary {
                    Button(role: .destructive) {
                        onRemove()
                        dismiss()
                    } label: {
                        Label("Ta bort från biblioteket", systemImage: "trash.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button {
                        onSelectStatus(.playing, false)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.headline)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Börja spela nu")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("Sätter status till Spelar nu")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onSelectStatus(.notStarted, true)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "archivebox.fill")
                                .font(.headline)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lägg i Backlog")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("Sätter status till Inte påbörjat")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onSelectStatus(.completed, false)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .font(.headline)
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Har redan klarat (Spelminne)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("Sparas som genomspelat i samlingen")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        onSelectStatus(.abandoned, false)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Avslutat / Spelat förr")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("Sparas i samlingen utan att räknas som genomspelat")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Avbryt")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
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
