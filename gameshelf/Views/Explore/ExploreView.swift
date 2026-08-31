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
    case forYou = "✨ För dig"
    case trending = "🔥 Trendar"

    var id: String { rawValue }
}

private enum ExploreSheet: Identifiable {
    case safari(URL)
    case game(Int)
    case trending
    case newsList

    var id: String {
        switch self {
        case .safari(let url): return "safari:" + url.absoluteString
        case .game(let id):    return "game:\(id)"
        case .trending:        return "trending"
        case .newsList:        return "newsList"
        }
    }
}

struct ExploreView: View {
    @EnvironmentObject var profile: ProfileStore
    @EnvironmentObject var store: LibraryStore

    @StateObject private var news = NewsFetcher()
    @StateObject private var trending = TrendingFetcher()

    @State private var sheet: ExploreSheet? = nil
    @State private var findError: String? = nil
    @State private var forYouRefreshID = UUID()
    @State private var showingAddGameSheet = false

    // Startsida State
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var selectedHeroIndex: Int = 0
    @State private var selectedDiscoverTab: DiscoverTab = .forYou
    @State private var selectedStarterCategory: Int = 0
    @State private var upcomingGames: [IGDBGame] = []
    @State private var isLoadingUpcoming: Bool = false
    @State private var showingGamingGoalSheet: Bool = false

    private var prefs: ExplorePrefs {
        .init(minAge: profile.age, platforms: Array(profile.platforms))
    }

    private var activePlayingGames: [Game] {
        store.games.filter { $0.status == .playing }
    }

    private var nextWishlistRelease: Game? {
        let now = Date()
        let currentYear = Calendar.current.component(.year, from: now)
        return store.games
            .filter { game in
                guard game.status == .wishlist else { return false }
                guard game.isUnreleased else { return false }
                if let releaseDate = game.releaseDate {
                    return releaseDate > now
                }
                return game.releaseYear > currentYear
            }
            .sorted { g1, g2 in
                if let d1 = g1.releaseDate, let d2 = g2.releaseDate {
                    return d1 < d2
                }
                if g1.releaseDate != nil { return true }
                if g2.releaseDate != nil { return false }
                return g1.releaseYear < g2.releaseYear
            }
            .first
    }

    private var findAlertBinding: Binding<Bool> {
        Binding<Bool>(
            get: { findError != nil },
            set: { if !$0 { findError = nil } }
        )
    }

    private func runInitialLoad() async {
        news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
        async let trFetch: Void = trending.fetch(platformFamilies: prefs.platforms, news: news.items)
        async let upFetch: Void = loadUpcomingHighlight()
        _ = await (trFetch, upFetch)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if store.games.isEmpty && !hasCompletedOnboarding {
                        // ONBOARDING STATE (När biblioteket är helt tomt)
                        onboardingView
                    } else {
                        // 1. Välkomsthälsning & Spelmål 2026
                        greetingHeader

                        // 2. Zon 1: Ditt Spel (Hero / Multi-game switcher ELLER Spelslumpare om noll aktiva)
                        heroSection

                        // 3. Zon 2: Spelvärlden idag (4 kurerade nyheter)
                        newsDigestSection

                        // 4. Zon 3: Upptäck & Utforska (Konsoliderad flikad hub)
                        discoverSection

                        // 5. Releasekalender (Kommande spelsläpp)
                        upcomingReleasesTeaserSection

                        // 6. Önskeliste-nedräkning (om sparade kommande spel finns)
                        if let nextGame = nextWishlistRelease {
                            wishlistCountdownCard(game: nextGame)
                        }
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .background(Color.ds.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task { await runInitialLoad() }
            .refreshable {
                forYouRefreshID = UUID()
                news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
                async let trFetch: Void = trending.fetch(platformFamilies: prefs.platforms, news: news.items, forceReload: true)
                async let upFetch: Void = loadUpcomingHighlight()
                _ = await (trFetch, upFetch)
            }
            .onChange(of: profile.platforms) { _, _ in
                news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
                Task {
                    async let trFetch: Void = trending.fetch(platformFamilies: prefs.platforms, news: news.items, forceReload: true)
                    async let upFetch: Void = loadUpcomingHighlight()
                    _ = await (trFetch, upFetch)
                }
            }
            .sheet(item: $sheet) { route in
                switch route {
                case .safari(let url):
                    SafariSheet(url: url)
                        .ignoresSafeArea()
                case .game(let igdbID):
                    GameDetailView(igdbID: igdbID)
                        .ignoresSafeArea(edges: .bottom)
                case .trending:
                    TrendingListView(items: trending.items, onRefresh: {
                        await trending.fetch(platformFamilies: prefs.platforms, news: news.items, forceReload: true)
                    }) { id in
                        sheet = .game(id)
                    }
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
                }
            }
            .sheet(isPresented: $showingAddGameSheet) {
                AddGameView()
            }
            .sheet(isPresented: $showingGamingGoalSheet) {
                gamingGoalSheet
            }
            .alert("Hitta spel i IGDB", isPresented: findAlertBinding) {
                Button("OK", role: .cancel) { findError = nil }
            } message: {
                Text(findError ?? "")
            }
        }
    }

    // MARK: - 1. Välkomsthälsning & Spelmål
    private var greetingHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            UserAvatarView(size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("Redo för dagens spelsession?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Spelmål Badge
            goalBadge
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let prefix: String
        switch hour {
        case 5..<12: prefix = "God morgon"
        case 12..<18: prefix = "God eftermiddag"
        default: prefix = "God kväll"
        }
        if !profile.username.isEmpty {
            return "\(prefix), \(profile.username) 👋"
        } else {
            return "\(prefix) 👋"
        }
    }

    private var goalBadge: some View {
        let completedCount = store.games.filter { $0.status == .completed }.count
        let targetGoal = max(1, profile.annualGamingGoal)
        let isGoalReached = completedCount >= targetGoal

        return Button {
            showingGamingGoalSheet = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isGoalReached ? "trophy.fill" : "flag.checkered")
                    .font(.caption2.bold())
                    .foregroundStyle(isGoalReached ? .yellow : .orange)

                if isGoalReached {
                    Text("\(completedCount) klara")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("🎉")
                        .font(.caption2)
                } else {
                    Text("\(completedCount)/\(targetGoal) klara")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.yellow.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Color.yellow.opacity(0.35), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    private var gamingGoalSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "trophy.fill")
                                .font(.title)
                                .foregroundStyle(.yellow)
                        )

                    Text("Ditt Spelmål för \(String(Calendar.current.component(.year, from: Date())))")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    let completedCount = store.games.filter { $0.status == .completed }.count
                    Text("Du har klarat \(completedCount) spel totalt! Välj ett årsmål som motiverar dig.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 16)

                VStack(spacing: 10) {
                    ForEach([12, 25, 50, 75, 100], id: \.self) { goal in
                        let isSelected = profile.annualGamingGoal == goal
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                profile.annualGamingGoal = goal
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        } label: {
                            HStack {
                                Text("\(goal) spel")
                                    .font(.body.weight(isSelected ? .bold : .regular))
                                    .foregroundStyle(.primary)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.headline)
                                }
                            }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? Color.yellow : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .navigationTitle("Spelmål")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") {
                        showingGamingGoalSheet = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - 2. Zon 1: Ditt Spel (Spelar just nu)
    @ViewBuilder
    private var heroSection: some View {
        if !activePlayingGames.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Sektionsrubrik med antal spel som spelas nu
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Spelar just nu")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("\(activePlayingGames.count)")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }

                    Spacer()

                    if activePlayingGames.count > 1 {
                        Text("\(selectedHeroIndex + 1) av \(activePlayingGames.count)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if activePlayingGames.count == 1 {
                    heroActiveCard(game: activePlayingGames[0])
                } else {
                    VStack(spacing: 8) {
                        TabView(selection: $selectedHeroIndex) {
                            ForEach(Array(activePlayingGames.enumerated()), id: \.element.id) { index, game in
                                heroActiveCard(game: game)
                                    .tag(index)
                                    .padding(.horizontal, 1)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: 128)

                        // Subtila eleganta sidprickar (Page dots)
                        HStack(spacing: 6) {
                            ForEach(0..<activePlayingGames.count, id: \.self) { idx in
                                Capsule()
                                    .fill(selectedHeroIndex == idx ? Color.green : Color.secondary.opacity(0.35))
                                    .frame(width: selectedHeroIndex == idx ? 16 : 6, height: 6)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedHeroIndex)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        } else {
            // Om man INTE har några aktiva spel: Slumparen kliver fram som Hero mot backlog paralysis!
            SmartGameRouletteCard()
        }
    }

    private func heroActiveCard(game: Game) -> some View {
        NavigationLink(destination: GameDetailView(game: game)) {
            HStack(spacing: 14) {
                CoverView(title: game.title, url: game.coverURL, corner: 10, height: 105)
                    .frame(width: 76, height: 105)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if let plat = game.platforms.first {
                            Text(plat)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                        }

                        Spacer()

                        Text("Aktiv idag")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    Text(game.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !game.todos.isEmpty {
                        let done = game.todos.filter(\.isDone).count
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(done) av \(game.todos.count) delmål klara")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            ProgressView(value: Double(done), total: Double(game.todos.count))
                                .tint(.green)
                                .scaleEffect(y: 0.7, anchor: .center)
                        }
                    } else if let hours = game.estimatedHours, hours > 0 {
                        Text("~ \(hours)h uppskattad speltid")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Tryck för att logga framsteg ›")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Color(.tertiarySystemGroupedBackground).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. Zon 2: Spelvärlden idag (Kompakt nyhetsdigest som hel sektion)
    private var newsDigestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "newspaper.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Text("Spelvärlden idag")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                NavigationLink(destination: NewsFeedView()) {
                    Text("Nyhetsmagasinet ›")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }

            // Kurerat 4-korts nyhetsdigest
            let digestItems = Array(news.items.prefix(4))

            if digestItems.isEmpty {
                Text("Laddar nyheter...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(digestItems.enumerated()), id: \.element.id) { index, item in
                        let isPersonal = item.matchedGameTitle != nil
                        let badge: String = {
                            if isPersonal { return "Ditt spel" }
                            if index == 0 { return "Toppnyhet" }
                            if item.kind == .review { return "Recension" }
                            if item.kind == .video { return "Trailer" }
                            if item.kind == .update { return "Uppdatering" }
                            return "Nyhet"
                        }()

                        compactNewsRow(item: item, badgeText: badge, isPersonal: isPersonal)

                        if index < digestItems.count - 1 {
                            Divider()
                                .opacity(0.4)
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func compactNewsRow(item: NewsItem, badgeText: String, isPersonal: Bool) -> some View {
        Button {
            if let u = item.link { sheet = .safari(u) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if let img = item.image {
                        AsyncImage(url: img) { phase in
                            switch phase {
                            case .success(let i): i.resizable().scaledToFill()
                            default: Color(.tertiarySystemFill)
                            }
                        }
                    } else {
                        Color(.tertiarySystemFill)
                            .overlay(Image(systemName: "newspaper").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(badgeText)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isPersonal ? Color.red.opacity(0.85) : Color(.tertiarySystemFill))
                            .foregroundStyle(isPersonal ? Color.white : Color.primary)
                            .clipShape(Capsule())

                        Text(item.source)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                        Spacer()

                        if !item.relativePublishedTime.isEmpty {
                            Text(item.relativePublishedTime)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4. Kommande Spelsläpp Teaser (Releasekalender)
    private var upcomingReleasesTeaserSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Text("Kommande spelsläpp")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                NavigationLink(destination: UpcomingReleasesView()) {
                    Text("Visa kalender ›")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }

            if isLoadingUpcoming && upcomingGames.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.red)
                    Text("Hämtar kommande spelsläpp...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else if upcomingGames.isEmpty {
                NavigationLink(destination: UpcomingReleasesView()) {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Öppna Releasekalendern")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("Se spelsläpp månad för månad på dina konsoler")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(upcomingGames) { game in
                            NavigationLink(destination: GameDetailView(igdbID: game.id)) {
                                upcomingExploreCard(game: game)
                            }
                            .buttonStyle(.plain)
                        }

                        // Sista kortet: Gå till full kalender
                        NavigationLink(destination: UpcomingReleasesView()) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color.red.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "calendar")
                                            .foregroundStyle(.red)
                                            .font(.headline)
                                    )
                                Text("Hela kalendern")
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                Text("Alla datum & plattformar")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 10)
                            .frame(width: 120, height: 185)
                            .background(Color(.tertiarySystemGroupedBackground).opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func upcomingExploreCard(game: IGDBGame) -> some View {
        let isWishlisted = store.games.contains(where: {
            ($0.igdbID != nil && $0.igdbID == game.id) ||
            $0.title.lowercased() == game.name.lowercased()
        })

        // Beräkna releasedatum-badge
        let dateText: String = {
            guard let ts = game.firstReleaseDate else {
                if let year = game.releaseYear, year > Calendar.current.component(.year, from: Date()) {
                    return "Kommande \(year)"
                }
                return "Kommande"
            }
            let date = Date(timeIntervalSince1970: TimeInterval(ts))
            if date > Date() && date.isYearPlaceholderDate {
                if let year = game.releaseYear {
                    return "Kommande \(year)"
                }
                return "Kommande"
            }
            let cal = Calendar.current
            let daysUntil = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
            if daysUntil == 0 { return "Idag" }
            if daysUntil == 1 { return "Imorgon" }
            if daysUntil > 1 && daysUntil <= 14 { return "Om \(daysUntil)d" }
            let f = DateFormatter()
            f.locale = Locale(identifier: "sv_SE")
            f.dateFormat = "d MMM"
            return f.string(from: date)
        }()

        return VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                CoverView(title: game.name, url: game.coverURL, corner: 12, height: 125)
                    .frame(width: 125, height: 125)

                // Datum-badge
                Text(dateText)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.primary)
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(game.name)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack {
                    if let hypes = game.hypes, hypes > 0 {
                        Text("🔥 \(hypes)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.orange)
                    } else if let genre = game.genres?.first?.name {
                        Text(genre)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isWishlisted {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
            .frame(width: 125, alignment: .leading)
        }
        .padding(8)
        .background(Color(.tertiarySystemGroupedBackground).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
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
                fromDate: Date(),
                limit: 12
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

    // MARK: - 5. Zon 3: Upptäck & Utforska (Konsoliderad flikad hub)
    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upptäck & Utforska")
                .font(.headline)
                .foregroundStyle(.primary)

            // Segmented Picker för Upptäckar-hubben
            Picker("Upptäck", selection: $selectedDiscoverTab) {
                ForEach(DiscoverTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            // Innehåll baserat på vald flik med fast minHeight för att förhindra hopp vid byte
            Group {
                switch selectedDiscoverTab {
                case .forYou:
                    LiveDiscoverySection(refreshTrigger: forYouRefreshID, mode: .forYouOnly)
                case .trending:
                    TrendingSection(
                        items: trending.items,
                        isLoading: trending.isLoading,
                        onSelect: { sheet = .game($0) },
                        onSeeAll: { sheet = .trending }
                    )
                }
            }
            .frame(minHeight: 230, alignment: .top)
        }
    }

    // MARK: - 5. Önskeliste-nedräkning
    private func wishlistCountdownCard(game: Game) -> some View {
        NavigationLink(destination: GameDetailView(game: game)) {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NÄSTA SLÄPP I DIN ÖNSKELISTA")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text(game.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer()

                if let date = game.releaseDate {
                    let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
                    if days > 0 && days <= 60 {
                        Text("Om \(days) dagar")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.12), in: Capsule())
                            .foregroundStyle(.red)
                    } else {
                        let formatter: DateFormatter = {
                            let f = DateFormatter()
                            f.locale = Locale(identifier: "sv_SE")
                            f.dateFormat = "d MMM yyyy"
                            return f
                        }()
                        Text(formatter.string(from: date))
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.12), in: Capsule())
                            .foregroundStyle(.red)
                    }
                } else if game.releaseYear > 0 {
                    Text("\(String(game.releaseYear))")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.12), in: Capsule())
                        .foregroundStyle(.red)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Onboarding State (Om biblioteket är helt tomt)
    private var onboardingView: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Välkomstkort
            VStack(alignment: .leading, spacing: 8) {
                Text(profile.username.trimmingCharacters(in: .whitespaces).isEmpty ? "Välkommen till GameShelf 👋" : "Välkommen, \(profile.username) 👋")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text("Ditt personliga spelbibliotek, smarta rekommendationer och de senaste nyheterna på ett och samma ställe.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.15), Color.orange.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Steg 1: Profilnamn
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(.red)
                    Text("1. Vad vill du kallas?")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                HStack {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                    TextField("Ange ditt namn eller gamer-tag...", text: $profile.username)
                        .font(.subheadline)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Steg 2: Välj dina plattformar
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundStyle(.red)
                    Text("2. Välj dina plattformar")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                let platforms = [
                    "PlayStation 5", "PlayStation 4",
                    "PC", "Steam Deck",
                    "Nintendo Switch",
                    "Xbox Series X|S", "Xbox One",
                    "Mac / iOS", "Retro & Klassiker"
                ]

                FlowLayout(spacing: 8) {
                    ForEach(platforms, id: \.self) { plat in
                        let isSelected = profile.platforms.contains(plat)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                profile.toggle(plat)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                Text(plat)
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.red : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Steg 3: Sätt ditt spelmål för 2026
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("3. Sätt ditt spelmål för 2026")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                Text("Hur många spel siktar du på att klara i år?")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach([6, 12, 20, 30], id: \.self) { goal in
                        let isSelected = profile.annualGamingGoal == goal
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                profile.annualGamingGoal = goal
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(goal)")
                                    .font(.subheadline.bold())
                                Text(goal == 6 ? "Lugnt" : (goal == 12 ? "Standard" : (goal == 20 ? "Entusiast" : "Hardcore")))
                                    .font(.system(size: 9))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.yellow.opacity(0.18) : Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(isSelected ? Color.yellow : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Steg 4: Kickstarta samlingen med kurerade spel
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("4. Kickstarta din samling")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                Text("Välj ett eller flera spel att lägga till i biblioteket:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Kategori-väljare
                Picker("Kategori", selection: $selectedStarterCategory) {
                    Text("🔥 Hett just nu").tag(0)
                    Text("👑 Mästerverk").tag(1)
                    Text("✨ Indiepärlor").tag(2)
                }
                .pickerStyle(.segmented)

                let starterGames: [StarterGameItem] = {
                    switch selectedStarterCategory {
                    case 0:
                        return [
                            StarterGameItem(title: "Kingdom Come: Deliverance II", plats: "PS5, PC, Xbox", year: 2025, genre: "RPG"),
                            StarterGameItem(title: "Monster Hunter Wilds", plats: "PS5, PC, Xbox", year: 2025, genre: "Action"),
                            StarterGameItem(title: "Civilization VII", plats: "PC, PS5, Switch", year: 2025, genre: "Strategi"),
                            StarterGameItem(title: "Helldivers 2", plats: "PS5, PC", year: 2024, genre: "Shooter"),
                            StarterGameItem(title: "Black Myth: Wukong", plats: "PS5, PC", year: 2024, genre: "Action RPG")
                        ]
                    case 1:
                        return [
                            StarterGameItem(title: "Elden Ring", plats: "PS5, PC, Xbox", year: 2022, genre: "Action RPG"),
                            StarterGameItem(title: "Baldur's Gate 3", plats: "PC, PS5, Xbox", year: 2023, genre: "RPG"),
                            StarterGameItem(title: "The Witcher 3: Wild Hunt", plats: "Multi", year: 2015, genre: "RPG"),
                            StarterGameItem(title: "The Legend of Zelda: Tears of the Kingdom", plats: "Switch", year: 2023, genre: "Äventyr"),
                            StarterGameItem(title: "Cyberpunk 2077", plats: "PC, PS5, Xbox", year: 2020, genre: "Sci-Fi RPG")
                        ]
                    default:
                        return [
                            StarterGameItem(title: "Balatro", plats: "PC, Switch, PS5, Xbox", year: 2024, genre: "Roguelike"),
                            StarterGameItem(title: "Hades", plats: "Multi", year: 2020, genre: "Roguelike"),
                            StarterGameItem(title: "Hollow Knight", plats: "Multi", year: 2017, genre: "Metroidvania"),
                            StarterGameItem(title: "Dave the Diver", plats: "Switch, PC, PS5", year: 2023, genre: "Äventyr"),
                            StarterGameItem(title: "Animal Well", plats: "PS5, PC, Switch", year: 2024, genre: "Pussel")
                        ]
                    }
                }()

                VStack(spacing: 8) {
                    ForEach(starterGames) { game in
                        let isAlreadyInLibrary = store.games.contains(where: { $0.title.lowercased() == game.title.lowercased() })
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(game.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("\(game.plats) • \(String(game.year)) • \(game.genre)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isAlreadyInLibrary {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Tillagd")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                            } else {
                                Menu {
                                    Button {
                                        addStarterGame(title: game.title, platform: game.plats.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "PC", year: game.year, status: .playing)
                                    } label: {
                                        HStack {
                                            Image(systemName: "play.circle.fill")
                                            Text("Spelar nu")
                                        }
                                    }
                                    Button {
                                        addStarterGame(title: game.title, platform: game.plats.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "PC", year: game.year, status: .completed)
                                    } label: {
                                        HStack {
                                            Image(systemName: "checkmark.circle")
                                            Text("Har klarat")
                                        }
                                    }
                                    Button {
                                        addStarterGame(title: game.title, platform: game.plats.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "PC", year: game.year, status: .wishlist)
                                    } label: {
                                        HStack {
                                            Image(systemName: "bookmark")
                                            Text("Önskelista")
                                        }
                                    }
                                } label: {
                                    Text("+ Lägg till")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundStyle(.green)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                // Sök fler
                Button {
                    showingAddGameSheet = true
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Sök och lägg till ett annat spel...")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

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
                .background(Color.red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .red.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
    }

    private func addStarterGame(title: String, platform: String, year: Int, status: PlayStatus = .playing) {
        let game = Game(
            title: title,
            platforms: [platform],
            releaseYear: year,
            genres: ["Action", "Äventyr"],
            developers: [],
            status: status,
            rating: status == .completed ? 8 : 0,
            coverURL: nil,
            isOwned: status != .wishlist
        )
        store.add(game)
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

// MARK: - Modeller för Onboarding
private struct StarterGameItem: Identifiable {
    var id: String { title }
    let title: String
    let plats: String
    let year: Int
    let genre: String
}

// MARK: - Enkel FlowLayout för plattformsval
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                height += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: height + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
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
