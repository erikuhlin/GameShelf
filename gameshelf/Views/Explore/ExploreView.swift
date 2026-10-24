//
//  ExploreView.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-08.
//

import SwiftUI
import Combine
import SafariServices

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Lightweight preferences
struct ExplorePrefs: Equatable {
    var minAge: Int
    var platforms: [String]

    static let example = ExplorePrefs(minAge: 16, platforms: ["PlayStation 5", "Nintendo Switch"])
}

enum DiscoverTab: String, CaseIterable, Identifiable {
    case forYou = "För dig"
    case trending = "Trendar"
    case toplist = "Topplistor"

    var id: String { rawValue }
}

private enum ExploreSheet: Identifiable {
    case safari(URL)
    case game(Int)
    case trending
    case newsList
    case toplist

    var id: String {
        switch self {
        case .safari(let url): return "safari:" + url.absoluteString
        case .game(let id):    return "game:\(id)"
        case .trending:        return "trending"
        case .newsList:        return "newsList"
        case .toplist:         return "toplist"
        }
    }
}

struct ExploreView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var profile: ProfileStore
    @EnvironmentObject var store: LibraryStore

    @StateObject private var news = NewsFetcher()
    @StateObject private var trending = TrendingFetcher()

    @State private var sheet: ExploreSheet? = nil
    @State private var findError: String? = nil
    @State private var forYouRefreshID = UUID()
    @State private var showingAddGameSheet = false
    @State private var showingProfileSheet = false

    // Startsida State
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var selectedHeroIndex: Int = 0
    @State private var selectedUpcomingPageIndex: Int = 0
    @State private var selectedNewsPageIndex: Int = 0
    @State private var selectedDiscoverTab: DiscoverTab = .forYou
    @State private var selectedStarterCategory: Int = 0
    @State private var upcomingGames: [IGDBGame] = []
    @State private var isLoadingUpcoming: Bool = false
    @State private var showingGamingGoalSheet: Bool = false
    @State private var showingAvatarPickerSheet: Bool = false
    @State private var showingPairingSheet: Bool = false
    @State private var showingWrappedSheet: Bool = false
    @State private var selectedGameForDetail: Game? = nil
    @State private var sheetSelectedGameForDetail: Game? = nil

    private var prefs: ExplorePrefs {
        .init(minAge: profile.age, platforms: Array(profile.platforms))
    }

    private var activePlayingGames: [Game] {
        store.games.filter { $0.status == .playing }
    }

    private var activeFocusGames: [Game] {
        let set = Set(profile.targetGameIDs.map { $0.lowercased() })
        return store.games.filter { set.contains($0.id.uuidString.lowercased()) }
    }

    /// Kombinerad lista för hero-kort (spelar nu + fokusmål)
    private var heroDisplayGames: [Game] {
        var result = activePlayingGames
        for g in activeFocusGames where !result.contains(where: { $0.id == g.id }) {
            result.append(g)
        }
        return result
    }

    private func effectiveReleaseDate(for game: Game) -> Date {
        if let date = game.releaseDate {
            return date
        }
        let year = game.releaseYear > 0 ? game.releaseYear : 2099
        var components = DateComponents()
        components.year = year
        components.month = 12
        components.day = 31
        return Calendar.current.date(from: components) ?? Date.distantFuture
    }

    private var nextWishlistRelease: Game? {
        let now = Date()
        let currentYear = Calendar.current.component(.year, from: now)
        let startOfToday = Calendar.current.startOfDay(for: now)
        let unreleased = store.games
            .filter { game in
                guard !game.isOwned else { return false }
                guard game.isUnreleased else { return false }
                if let releaseDate = game.releaseDate {
                    return releaseDate >= startOfToday
                }
                return game.releaseYear >= currentYear
            }
            .sorted { g1, g2 in
                let d1 = effectiveReleaseDate(for: g1)
                let d2 = effectiveReleaseDate(for: g2)
                if d1 != d2 {
                    return d1 < d2
                }
                return g1.title.localizedCaseInsensitiveCompare(g2.title) == .orderedAscending
            }

        if let first = unreleased.first {
            return first
        }

        return store.games.first(where: { !$0.isOwned })
    }

    private var findAlertBinding: Binding<Bool> {
        Binding<Bool>(
            get: { findError != nil },
            set: { if !$0 { findError = nil } }
        )
    }

    private func runInitialLoad() async {
        await store.syncWithRemote()
        await profile.syncWithRemote()
        news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
        async let trFetch: Void = trending.fetch(platformFamilies: prefs.platforms, news: news.items)
        async let upFetch: Void = loadUpcomingHighlight()
        _ = await (trFetch, upFetch)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if store.games.isEmpty && !hasCompletedOnboarding {
                        // ONBOARDING STATE
                        onboardingView
                    } else {
                        // 1. Header (Profil & Status)
                        greetingHeader

                        // 🏆 GOTY Banner (om säsong)
                        if ProfileStore.isGotySeason {
                            gotyWrappedBanner
                        }

                        // 2. Spelar just nu (Hero Carousel direkt på canvas)
                        heroCarouselSection

                        // 3. Slim Önskelista-banner (alltid under Spelar just nu)
                        wishlistBannerSection

                        // 4. Upptäck & Utforska (Filter Chips + Fixed Sub-header)
                        discoverSection

                        // 5. Kommande spelsläpp (Grouped Date-Cluster Carousel)
                        upcomingReleasesSection

                        // 6. Spelvärlden idag (Paged 3-row news carousel)
                        newsDigestSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: 960)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color.neutralBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task { await runInitialLoad() }
            .refreshable {
                await store.syncWithRemote()
                await profile.syncWithRemote()
                forYouRefreshID = UUID()
                news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
                async let trFetch: Void = trending.fetch(platformFamilies: prefs.platforms, news: news.items, forceReload: true)
                async let upFetch: Void = loadUpcomingHighlight()
                async let fyFetch: Void = ForYouEngine.shared.loadHomeCuratedRecommendations(games: store.games, profile: profile, forceReload: true)
                _ = await (trFetch, upFetch, fyFetch)
            }
            .onChange(of: profile.platforms) { _, _ in
                forYouRefreshID = UUID()
                news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
                Task {
                    async let trFetch: Void = trending.fetch(platformFamilies: prefs.platforms, news: news.items, forceReload: true)
                    async let upFetch: Void = loadUpcomingHighlight()
                    async let fyFetch: Void = ForYouEngine.shared.loadHomeCuratedRecommendations(games: store.games, profile: profile, forceReload: true)
                    _ = await (trFetch, upFetch, fyFetch)
                }
            }
            .sheet(item: $sheet) { route in
                switch route {
                case .safari(let url):
                    SafariSheet(url: url)
                        .ignoresSafeArea()
                case .game(let igdbID):
                    NavigationStack {
                        GameDetailView(igdbID: igdbID)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("Stäng") {
                                        sheet = nil
                                    }
                                }
                            }
                    }
                    .environmentObject(store)
                    .environmentObject(profile)
                    .ignoresSafeArea(edges: .bottom)
                case .trending:
                    TrendingListView(items: trending.items, onRefresh: {
                        await trending.fetch(platformFamilies: prefs.platforms, news: news.items, forceReload: true)
                    })
                    .environmentObject(store)
                    .environmentObject(profile)
                    .presentationDetents([.large])
                case .newsList:
                    NewsListView(
                        items: news.items,
                        canLoadMore: news.canLoadMore,
                        isLoadingMore: news.isLoadingMore,
                        onOpen: { url in sheet = .safari(url) },
                        onFindIGDB: { title in openIGDBFrom(title: title) },
                        onLoadMore: { news.loadMore() },
                        initialPlatformRaw: "Alla",
                        initialKind: nil
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                case .toplist:
                    NavigationStack {
                        ToplistView()
                            .environmentObject(store)
                            .environmentObject(profile)
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingAddGameSheet) {
                AddGameView()
            }
            .sheet(isPresented: $showingGamingGoalSheet) {
                gamingGoalSheet
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .navigationDestination(item: $selectedGameForDetail) { game in
                GameDetailView(game: game)
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingAvatarPickerSheet) {
                AvatarPickerSheet()
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingPairingSheet) {
                DevicePairingView()
                    .environmentObject(store)
                    .environmentObject(profile)
            }
            .sheet(isPresented: $showingProfileSheet) {
                NavigationStack {
                    ProfileView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Klar") { showingProfileSheet = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingWrappedSheet) {
                YearWrappedSheet()
            }
            .alert("Hitta spel i IGDB", isPresented: findAlertBinding) {
                Button("OK", role: .cancel) { findError = nil }
            } message: {
                Text(findError ?? "")
            }
        }
    }

    // MARK: - 1. Header (Profil & Status)
    private var greetingHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                showingProfileSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.neutralSurface)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))

                    if profile.avatarType == "preset:coffee" || profile.avatarType.isEmpty {
                        Text("☕️")
                            .font(.system(size: 16))
                    } else {
                        UserAvatarView(size: 40)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(greetingText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text("Redo för dagens spelsession?")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            // Spelmål Badge (🚩 2/5 klara)
            goalBadge
        }
        .padding(.top, 4)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let prefix: String
        switch hour {
        case 5..<12: prefix = "God morgon"
        case 12..<18: prefix = "God eftermiddag"
        default: prefix = "God kväll"
        }
        let firstName = profile.username.split(separator: " ").first.map(String.init) ?? profile.username
        if !firstName.isEmpty {
            return "\(prefix), \(firstName)"
        } else {
            return prefix
        }
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var currentYearCompletedCount: Int {
        GamingGoalEngine.completedCount(in: store.games, for: currentYear)
    }

    private var goalBadge: some View {
        let completedCount = currentYearCompletedCount
        let targetGoal = max(1, profile.annualGamingGoal)

        return Button {
            showingGamingGoalSheet = true
        } label: {
            HStack(spacing: 5) {
                Text("🚩")
                    .font(.system(size: 11))
                Text("\(completedCount)/\(targetGoal) klara")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(Color.feedbackWarning)
            .background(Color.feedbackWarning.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(Color.feedbackWarning.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Spelar just nu (Hero Carousel direkt på canvas)
    @ViewBuilder
    private var heroCarouselSection: some View {
        let games = heroDisplayGames

        if !games.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Section Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)

                        Text("Spelar just nu")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                    }

                    Spacer()

                    Button {
                        showingGamingGoalSheet = true
                    } label: {
                        Text("Hantera ›")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.brandRed)
                    }
                }

                // Horizontal Carousel direkt på canvas (inga yttre grå boxar eller tjocka ramar)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                            Button {
                                selectedGameForDetail = game
                            } label: {
                                heroCard(game: game, index: index, total: games.count)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 2)
                }
            }
        } else {
            // Slumparen kliver fram vid noll aktiva spel
            SmartGameRouletteCard()
        }
    }

    private func heroCard(game: Game, index: Int, total: Int) -> some View {
        let isGoal = activeFocusGames.contains(where: { $0.id == game.id }) && game.status != .playing

        return HStack(spacing: 11) {
            // 1. Natural Poster Cover (3:4 ratio, crisp & uncropped)
            ZStack {
                Color(hex: "#2C2C2E")

                if let url = game.coverURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            placeholderCoverFallback
                        }
                    }
                } else {
                    placeholderCoverFallback
                }
            }
            .frame(width: 58, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1.5)

            // 2. Info Section
            VStack(alignment: .leading, spacing: 3.5) {
                // Top Row: Status Badge, Betyg & Index Counter
                HStack(alignment: .center, spacing: 4.5) {
                    if isGoal {
                        HStack(spacing: 3) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 7.5, weight: .bold))
                                .foregroundStyle(Color(hex: "#FF9500"))
                            Text("Mål")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(
                            ZStack {
                                Capsule().fill(Color(hex: "#101012").opacity(0.88))
                                Capsule().fill(Color(hex: "#FF9500").opacity(0.15))
                            }
                        )
                        .overlay(Capsule().stroke(Color(hex: "#FF9500").opacity(0.55), lineWidth: 0.8))
                    } else {
                        HStack(spacing: 3.5) {
                            Circle()
                                .fill(Color(hex: "#34C759"))
                                .frame(width: 5, height: 5)
                            Text(game.isMultiplayerOrOngoing ? "Aktiv" : "Spelar nu")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(
                            ZStack {
                                Capsule().fill(Color(hex: "#101012").opacity(0.88))
                                Capsule().fill(Color(hex: "#34C759").opacity(0.15))
                            }
                        )
                        .overlay(Capsule().stroke(Color(hex: "#34C759").opacity(0.55), lineWidth: 0.8))
                    }

                    Spacer(minLength: 2)

                    if let rating = heroRating(for: game) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7.5))
                                .foregroundStyle(.yellow)
                            Text(rating)
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                    }

                    if total > 1 {
                        Text("\(index + 1) av \(total)")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                    }
                }

                // Title
                Text(game.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                // Plattform & Genre
                let metaText = heroMetaText(for: game)
                if !metaText.isEmpty {
                    Text(metaText)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // Speltid / Framsteg (om tillgängligt)
                if let progress = heroProgressInfo(for: game) {
                    HStack(spacing: 3) {
                        Image(systemName: progress.icon)
                            .font(.system(size: 8))
                            .foregroundStyle(Color.textSecondary.opacity(0.85))
                        Text(progress.text)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(9)
        .frame(width: 265, height: 96)
        .background(Color.neutralSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    private var placeholderCoverFallback: some View {
        Color(hex: "#2C2C2E")
            .overlay(
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.white.opacity(0.2))
            )
    }

    private func heroRating(for game: Game) -> String? {
        if let ur = game.rating, ur > 0 {
            return "\(ur)"
        }
        if let ir = Game.normalizeIgdbRating(game.igdbRating), ir > 0 {
            return ir.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(ir))" : String(format: "%.1f", ir)
        }
        return nil
    }

    private func heroMetaText(for game: Game) -> String {
        var parts: [String] = []
        if let plat = game.platforms.first, !plat.isEmpty {
            parts.append(plat)
        }
        if let genre = game.genres.first, !genre.isEmpty {
            parts.append(cleanGenre(genre))
        }
        return parts.joined(separator: " • ")
    }

    private func cleanGenre(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "Role-playing (RPG)" { return "RPG" }
        if trimmed == "Turn-based strategy (TBS)" { return "TBS" }
        if trimmed == "Real-time strategy (RTS)" { return "RTS" }
        if trimmed == "Hack and slash/Beat 'em up" { return "Hack & slash" }
        if trimmed == "Point-and-click" { return "Point & click" }
        return trimmed
    }

    private struct HeroProgress {
        let icon: String
        let text: String
    }

    private func heroProgressInfo(for game: Game) -> HeroProgress? {
        // 1. Loggad tid mot beräknad speltid
        if let logged = game.hoursPlayed, logged > 0 {
            let loggedStr = logged.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(logged))" : String(format: "%.1f", logged)
            if let est = game.estimatedHours, est > 0 {
                return HeroProgress(icon: "clock", text: "\(loggedStr) / ~\(est)h")
            }
            return HeroProgress(icon: "clock", text: "\(loggedStr)h spelat")
        }

        // 2. Beräknad speltid
        if let est = game.estimatedHours, est > 0 {
            return HeroProgress(icon: "clock", text: "~\(est)h speltid")
        }

        // 3. Delmål / Checklistor
        if !game.todos.isEmpty {
            let done = game.todos.filter(\.isDone).count
            return HeroProgress(icon: "checklist", text: "\(done)/\(game.todos.count) delmål")
        }

        // 4. Story status
        if let story = game.storyProgress {
            return HeroProgress(icon: "flag", text: story.rawValue)
        }

        // 5. Senast spelat
        if let last = game.lastPlayedFormatted {
            return HeroProgress(icon: "clock.arrow.circlepath", text: last)
        }

        return nil
    }

    // MARK: - 3. Slim Wishlist Banner (#1C1C1E container)
    @ViewBuilder
    private var wishlistBannerSection: some View {
        if let game = nextWishlistRelease {
            wishlistCountdownCard(game: game)
        } else if let upcoming = upcomingGames.first {
            upcomingWishlistFallbackCard(upcoming: upcoming)
        } else {
            curatedGTAFallbackCard
        }
    }

    private func wishlistCountdownCard(game: Game) -> some View {
        Button {
            selectedGameForDetail = game
        } label: {
            HStack(spacing: 12) {
                // Heart icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#FF3B30").opacity(0.10))
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hex: "#FF3B30").opacity(0.20), lineWidth: 1)
                        )
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#FF3B30"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("ÖNSKELISTA")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Color.textSecondary)

                    Text(game.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                countdownBadge(for: game)
            }
            .padding(12)
            .background(Color.neutralSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func upcomingWishlistFallbackCard(upcoming: IGDBGame) -> some View {
        Button {
            sheet = .game(upcoming.id)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#FF3B30").opacity(0.10))
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hex: "#FF3B30").opacity(0.20), lineWidth: 1)
                        )
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#FF3B30"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("KOMMANDE SLÄPP")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Color.textSecondary)

                    Text(upcoming.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                let text: String = {
                    if let ts = upcoming.firstReleaseDate {
                        let date = Date(timeIntervalSince1970: TimeInterval(ts))
                        let diff = date.timeIntervalSinceNow
                        let days = max(0, Int(ceil(diff / 86400.0)))
                        if days == 0 && Calendar.current.isDateInToday(date) {
                            return "Idag"
                        } else if days > 0 {
                            return "Om \(days) daga    r"
                        }
                    } else if let yr = upcoming.releaseYear {
                        return "\(yr)"
                    }
                    return "Kommande"
                }()

                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#FF3B30"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#FF3B30").opacity(0.10), in: Capsule())
                    .overlay(Capsule().stroke(Color(hex: "#FF3B30").opacity(0.20), lineWidth: 1))
            }
            .padding(12)
            .background(Color.neutralSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var curatedGTAFallbackCard: some View {
        Button {
            openIGDBFrom(title: "Grand Theft Auto VI")
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#FF3B30").opacity(0.10))
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hex: "#FF3B30").opacity(0.20), lineWidth: 1)
                        )
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#FF3B30"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("ÖNSKELISTA")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Color.textSecondary)

                    Text("Grand Theft Auto VI")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                Text("Kommande 2026")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#FF3B30"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#FF3B30").opacity(0.10), in: Capsule())
                    .overlay(Capsule().stroke(Color(hex: "#FF3B30").opacity(0.20), lineWidth: 1))
            }
            .padding(12)
            .background(Color.neutralSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func countdownBadge(for game: Game) -> some View {
        let text: String = {
            if let date = game.releaseDate {
                let diff = date.timeIntervalSinceNow
                let days = max(0, Int(ceil(diff / 86400.0)))
                if days == 0 && Calendar.current.isDateInToday(date) {
                    return "Idag"
                } else if days > 0 {
                    return "Om \(days) dagar"
                } else {
                    let f = DateFormatter()
                    f.locale = Locale(identifier: "sv_SE")
                    f.dateFormat = "d MMM"
                    return f.string(from: date)
                }
            } else if game.releaseYear > Calendar.current.component(.year, from: Date()) {
                return "\(game.releaseYear)"
            } else if game.releaseYear > 0 {
                return "Finns nu"
            }
            return "Önskelista"
        }()

        return Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(hex: "#FF3B30"))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(hex: "#FF3B30").opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(Color(hex: "#FF3B30").opacity(0.20), lineWidth: 1))
    }

    // MARK: - 4. Upptäck & Utforska (Filter Chips + Fixed Sub-header)
    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main Section Header
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)

                Text("Upptäck & Utforska")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
            }

            // Segmented Filter Chips
            HStack(spacing: 8) {
                filterChip(title: "För dig", icon: "sparkles", tab: .forYou)
                filterChip(title: "Trendar", icon: "flame.fill", tab: .trending)
                filterChip(title: "Topplistor", icon: "trophy.fill", tab: .toplist)
            }

            // Fixed height sticky sub-header row (height 28 pt)
            discoverSubHeaderRow
                .frame(height: 28)

            // Content per filter tab
            Group {
                switch selectedDiscoverTab {
                case .forYou:
                    LiveDiscoverySection(refreshTrigger: forYouRefreshID, mode: .forYouOnly)
                case .trending:
                    TrendingSection(
                        items: trending.items,
                        isLoading: trending.isLoading,
                        showHeader: false,
                        onSelect: { sheet = .game($0) },
                        onSeeAll: { sheet = .trending }
                    )
                case .toplist:
                    ToplistSection(
                        showHeader: false,
                        onSelect: { sheet = .game($0) },
                        onSeeAll: { sheet = .toplist }
                    )
                }
            }
            .frame(minHeight: 230, alignment: .top)
        }
    }

    private func filterChip(title: String, icon: String, tab: DiscoverTab) -> some View {
        let isSelected = selectedDiscoverTab == tab
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedDiscoverTab = tab
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.white : Color.neutralSurface)
            .foregroundStyle(isSelected ? Color.neutralBackground : Color.textSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var discoverSubHeaderRow: some View {
        HStack {
            switch selectedDiscoverTab {
            case .forYou:
                Text("REKOMMENDERAT FÖR DIG")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.textSecondary)

                Spacer()

                NavigationLink(destination: ForYouHubView()) {
                    Text("Spel-DNA & Minnen ›")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandRed)
                }
            case .trending:
                Text("TRENDAR JUST NU")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.textSecondary)

                Spacer()

                Button {
                    sheet = .trending
                } label: {
                    Text("Visa alla ›")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandRed)
                }
            case .toplist:
                Text("TOPP 100 SPEL")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.textSecondary)

                Spacer()

                Button {
                    sheet = .toplist
                } label: {
                    Text("Visa alla 100 ›")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandRed)
                }
            }
        }
    }

    // MARK: - 5. Kommande spelsläpp (Grouped Date-Cluster Carousel)
    private var currentMonthName: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.dateFormat = "MMMM"
        let raw = f.string(from: Date())
        return raw.prefix(1).capitalized + raw.dropFirst()
    }

    private var upcomingClusters: [[IGDBGame]] {
        guard !upcomingGames.isEmpty else { return [] }
        return stride(from: 0, to: upcomingGames.count, by: 4).map {
            Array(upcomingGames[$0..<min($0 + 4, upcomingGames.count)])
        }
    }

    @ViewBuilder
    private var upcomingReleasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)

                        Text("Kommande spel")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                    }

                    Text(currentMonthName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.05), in: Capsule())
                }

                Spacer()

                NavigationLink(destination: UpcomingReleasesView()) {
                    Text("Visa kalender (\(upcomingGames.count)) ›")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandRed)
                }
            }

            if isLoadingUpcoming && upcomingGames.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.brandRed)
                    Text("Hämtar kommande spelsläpp...")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else if upcomingGames.isEmpty {
                NavigationLink(destination: UpcomingReleasesView()) {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundStyle(Color.brandRed)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Öppna Releasekalendern")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.textPrimary)
                            Text("Se spelsläpp månad för månad på dina konsoler")
                                .font(.caption2)
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(12)
                    .background(Color.neutralSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                // Paged horizontal cluster carousel (4 vertikala rader per kortkluster, paginering likt nyheter)
                VStack(spacing: 12) {
                    TabView(selection: $selectedUpcomingPageIndex) {
                        ForEach(Array(upcomingClusters.enumerated()), id: \.offset) { pageIndex, cluster in
                            upcomingClusterCard(cluster)
                                .tag(pageIndex)
                                .padding(.horizontal, 1)
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 265)

                    // Centered dot pagination indicator
                    if upcomingClusters.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(0..<upcomingClusters.count, id: \.self) { idx in
                                Capsule()
                                    .fill(selectedUpcomingPageIndex == idx ? Color.brandRed : Color.white.opacity(0.20))
                                    .frame(width: selectedUpcomingPageIndex == idx ? 16 : 5, height: 5)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedUpcomingPageIndex)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
    }

    private func upcomingClusterCard(_ cluster: [IGDBGame]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(cluster.enumerated()), id: \.element.id) { index, game in
                Button {
                    sheet = .game(game.id)
                } label: {
                    upcomingRow(game: game)
                }
                .buttonStyle(.plain)

                if index < cluster.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.05))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.neutralSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func upcomingRow(game: IGDBGame) -> some View {
        let (isToday, monthText, dayText) = parsedReleaseDate(for: game)

        return HStack(spacing: 12) {
            // 1. Square Date Tile (44×44 pt)
            ZStack {
                if isToday {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#8B2424"))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                    Text("Idag")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.neutralBackground)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                    VStack(spacing: 1) {
                        Text(monthText)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.brandRed)
                        Text(dayText)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .frame(width: 44, height: 44)

            // 2. Small Cover Thumbnail (36×44 pt)
            ZStack {
                Color(hex: "#2C2C2E")

                if let url = game.coverURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Color(hex: "#2C2C2E")
                        }
                    }
                }
            }
            .frame(width: 36, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // 3. Title & Platforms / Genre
            VStack(alignment: .leading, spacing: 3) {
                Text(game.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(upcomingPlatformGenreText(for: game))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 4. Hype Indicator (🔥 14 / 🔥 48)
            let hypes = game.hypes ?? 14
            Text("🔥 \(hypes)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "#FF9500"))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "#FF9500").opacity(0.10), in: Capsule())
                .overlay(Capsule().stroke(Color(hex: "#FF9500").opacity(0.20), lineWidth: 1))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
    }

    private func parsedReleaseDate(for game: IGDBGame) -> (isToday: Bool, month: String, day: String) {
        guard let ts = game.firstReleaseDate else {
            return (false, "KOM", "\(game.releaseYear ?? 2026)")
        }
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let isToday = Calendar.current.isDateInToday(date)
        let mf = DateFormatter()
        mf.locale = Locale(identifier: "sv_SE")
        mf.dateFormat = "MMM"
        let month = mf.string(from: date).uppercased()

        let df = DateFormatter()
        df.dateFormat = "d"
        let day = df.string(from: date)

        return (isToday, month, day)
    }

    private func upcomingPlatformGenreText(for game: IGDBGame) -> String {
        var parts: [String] = []
        if let platforms = game.platforms, !platforms.isEmpty {
            let names = platforms.prefix(2).map(\.name)
            parts.append(names.joined(separator: ", "))
        }
        if let genre = game.genres?.first?.name {
            parts.append(genre.replacingOccurrences(of: "Role-playing (RPG)", with: "RPG"))
        }
        return parts.isEmpty ? "Spel" : parts.joined(separator: " • ")
    }

    private func loadUpcomingHighlight() async {
        await MainActor.run {
            isLoadingUpcoming = true
        }

        do {
            let platformIDs = profile.platforms.flatMap { p -> [Int] in
                let lower = p.lowercased()
                if lower.contains("playstation 5") || lower == "ps5" { return [167] }
                if lower.contains("xbox") { return [169] }
                if lower.contains("switch") { return [130] }
                if lower.contains("pc") || lower.contains("windows") { return [6] }
                return []
            }

            let fetched = try await IGDBService.shared.fetchUpcomingReleases(
                platformIDs: platformIDs,
                fromDate: Calendar.current.startOfDay(for: Date()),
                limit: 16
            )

            await MainActor.run {
                self.upcomingGames = fetched
                self.isLoadingUpcoming = false
            }
        } catch {
            print("[ExploreView] loadUpcomingHighlight error: \(error)")
            await MainActor.run {
                self.isLoadingUpcoming = false
            }
        }
    }

    // MARK: - 6. Spelvärlden idag (Paged 4-row news carousel)
    private var newsDigestItems: [NewsItem] {
        Array(news.items.prefix(16))
    }

    private var newsPages: [[NewsItem]] {
        let items = newsDigestItems
        guard !items.isEmpty else { return [] }
        return stride(from: 0, to: items.count, by: 4).map {
            Array(items[$0..<min($0 + 4, items.count)])
        }
    }

    private var newsDigestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "newspaper.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)

                        Text("Spelvärlden idag")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                    }

                    Text("\(newsDigestItems.count) nya")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.05), in: Capsule())
                }

                Spacer()

                NavigationLink(destination: NewsFeedView()) {
                    Text("Magasinet ›")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.brandRed)
                }
            }

            if newsDigestItems.isEmpty {
                Text("Laddar nyheter...")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.vertical, 8)
            } else {
                // Paged Carousel (4 rader per sida)
                VStack(spacing: 12) {
                    TabView(selection: $selectedNewsPageIndex) {
                        ForEach(Array(newsPages.enumerated()), id: \.offset) { pageIndex, pageItems in
                            newsPageBlock(pageItems: pageItems)
                                .tag(pageIndex)
                                .padding(.horizontal, 1)
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 298)

                    // Centered dot pagination indicator
                    if newsPages.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(0..<newsPages.count, id: \.self) { idx in
                                Capsule()
                                    .fill(selectedNewsPageIndex == idx ? Color.brandRed : Color.white.opacity(0.20))
                                    .frame(width: selectedNewsPageIndex == idx ? 16 : 5, height: 5)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedNewsPageIndex)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
    }

    private func newsPageBlock(pageItems: [NewsItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(pageItems.enumerated()), id: \.element.id) { index, item in
                Button {
                    if let u = item.link { sheet = .safari(u) }
                } label: {
                    newsRow(item: item)
                }
                .buttonStyle(.plain)

                if index < pageItems.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.05))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.neutralSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func newsRow(item: NewsItem) -> some View {
        HStack(spacing: 12) {
            // 48×48 pt thumbnail
            ZStack {
                Color(hex: "#2C2C2E")

                if let img = item.image {
                    AsyncImage(url: img) { phase in
                        switch phase {
                        case .success(let i):
                            i.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Color(hex: "#2C2C2E")
                                .overlay(
                                    Image(systemName: "newspaper.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.white.opacity(0.2))
                                )
                        }
                    }
                } else {
                    Color(hex: "#2C2C2E")
                        .overlay(
                            Image(systemName: "newspaper.fill")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.2))
                        )
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4.5) {
                HStack(spacing: 6) {
                    Text(item.source)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#3F51B5"), in: RoundedRectangle(cornerRadius: 5, style: .continuous))

                    if !item.relativePublishedTime.isEmpty {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.textSecondary)
                        Text(item.relativePublishedTime)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Text(item.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
    }

    // MARK: - GOTY Wrapped Banner
    private var gotyWrappedBanner: some View {
        let crownedGame = profile.getGoty(forYear: currentYear).flatMap { id in store.games.first { $0.id == id } }

        return Button {
            showingWrappedSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.feedbackWarning.opacity(0.20))
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.feedbackWarning.opacity(0.35), lineWidth: 1)
                        )
                    Text("👑")
                        .font(.system(size: 18))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("SPELÅRET \(currentYear)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color.feedbackWarning)
                        .tracking(1)

                    if let goty = crownedGame {
                        Text("Ditt GOTY: \(goty.title)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                    } else {
                        Text("Kora ditt Game of the Year!")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                    }

                    Text("Se din Spelåret Wrapped & nominera vinnare")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(crownedGame != nil ? "Öppna" : "Välj nu")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.feedbackWarning)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.feedbackWarning)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.feedbackWarning.opacity(0.12), in: Capsule())
            }
            .padding(12)
            .background(Color.neutralSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.feedbackWarning.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Spelmål Sheet
    private var gamingGoalSheet: some View {
        GameGoalsView()
            .environmentObject(store)
            .environmentObject(profile)
    }

    // MARK: - Onboarding State
    private var onboardingView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(profile.username.trimmingCharacters(in: .whitespaces).isEmpty ? "Välkommen till GameShelf 👋" : "Välkommen, \(profile.username) 👋")
                    .font(.title2.bold())
                    .foregroundStyle(Color.textPrimary)
                Text("Ditt personliga spelbibliotek, smarta rekommendationer, Spel-DNA och spelstatistik på ett och samma ställe.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.neutralSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.brandRed.opacity(0.2), lineWidth: 1)
            )

            // Snabbval för befintliga användare
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundStyle(Color.brandRed)
                        .padding(10)
                        .background(Color.brandRed.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Har du redan ett konto eller bibliotek?")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.textPrimary)

                        Text("Koppla ihop med din andra enhet eller webbkonto för att hämta ditt spelbibliotek och din profil direkt.")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Button {
                    showingPairingSheet = true
                } label: {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Koppla enhet eller logga in")
                            .bold()
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.brandRed)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.neutralSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.brandRed.opacity(0.25), lineWidth: 1)
            )

            // Gå direkt till Utforska
            Button {
                withAnimation {
                    hasCompletedOnboarding = true
                }
            } label: {
                HStack {
                    Text(store.games.isEmpty ? "Hoppa över och gå till Utforska" : "Klar! Börja utforska")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.brandRed)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
    }

    private func openIGDBFrom(title: String) {
        Task {
            if let id = await OnlineSearchClient.firstID(for: title) {
                sheet = .game(id)
            } else {
                findError = "Hittade inget matchande spel i IGDB."
            }
        }
    }
}

// MARK: - In-app Safari sheet
private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

// MARK: - Select Focus Game View
struct SelectFocusGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profile: ProfileStore
    let games: [Game]
    @State private var search: String = ""

    private var availableGames: [Game] {
        let lowerTargets = Set(profile.targetGameIDs.map { $0.lowercased() })
        let owned = games.filter { $0.isOwned && !lowerTargets.contains($0.id.uuidString.lowercased()) }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return owned }
        return owned.filter {
            $0.title.lowercased().contains(q) || $0.platforms.contains(where: { $0.lowercased().contains(q) })
        }
    }

    var body: some View {
        List {
            if availableGames.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller")
                        .font(.largeTitle)
                        .foregroundStyle(Color.textSecondary)
                    Text(search.isEmpty ? "Inga fler tillgängliga spel i biblioteket" : "Inga spel matchade '\(search)'")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(availableGames) { game in
                    Button {
                        profile.toggleTargetGoal(gameID: game.id)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if profile.targetGameIDs.count >= 3 {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if let url = game.coverURL {
                                AsyncImage(url: url) { phase in
                                    if let img = phase.image {
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.gray.opacity(0.3)
                                    }
                                }
                                .frame(width: 38, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 38, height: 50)
                                    .overlay(
                                        Image(systemName: "gamecontroller.fill")
                                            .foregroundStyle(Color.textSecondary)
                                            .font(.caption)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(game.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                                Text(game.platforms.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.feedbackWarning)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.neutralSurface)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.neutralBackground.ignoresSafeArea())
        .searchable(text: $search, prompt: "Sök spel i biblioteket...")
        .navigationTitle("Välj Fokusmål")
        .navigationBarTitleDisplayMode(.inline)
    }
}
