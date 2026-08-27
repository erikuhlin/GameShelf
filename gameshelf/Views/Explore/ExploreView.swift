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

enum ExploreTab: String, CaseIterable, Identifiable {
    case forYou = "För dig"
    case news = "Nyheter"

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

enum NewsFilterCategory: String, CaseIterable, Identifiable {
    case all = "Alla"
    case myGames = "Mina spel"
    case updates = "Uppdateringar"
    case reviews = "Recensioner"
    case trailers = "Trailers"
    case previews = "Förhandstittar"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "sparkles"
        case .myGames: return "gamecontroller.fill"
        case .updates: return "arrow.triangle.2.circlepath"
        case .reviews: return "star.fill"
        case .trailers: return "play.circle.fill"
        case .previews: return "eye.fill"
        }
    }

    var kind: NewsKind? {
        switch self {
        case .all, .myGames: return nil
        case .updates: return .update
        case .reviews: return .review
        case .trailers: return .video
        case .previews: return .preview
        }
    }
}

struct ExploreView: View {
    @EnvironmentObject var profile: ProfileStore
    @EnvironmentObject var store: LibraryStore
    @State private var tab: ExploreTab = .forYou
    @StateObject private var news = NewsFetcher()
    @StateObject private var trending = TrendingFetcher()
    @State private var sheet: ExploreSheet? = nil

    @State private var findError: String? = nil
    @State private var forYouRefreshID = UUID()

    // Filter för nyheter
    @State private var selectedNewsCategory: NewsFilterCategory = .all
    @State private var newsSearchText: String = ""

    private var prefs: ExplorePrefs {
        .init(minAge: profile.age, platforms: Array(profile.platforms))
    }

    private var findAlertBinding: Binding<Bool> {
        Binding<Bool>(
            get: { findError != nil },
            set: { if !$0 { findError = nil } }
        )
    }

    private func runInitialLoad() async {
        news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
        await trending.fetch(platformFamilies: prefs.platforms, news: news.items)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                    .padding(.vertical, 8)

                if tab == .forYou {
                    forYouContent
                } else {
                    newsContent
                }
            }
            .background(Color.ds.background.ignoresSafeArea())
            .navigationTitle("Utforska")
            .navigationBarTitleDisplayMode(.inline)
            .task { await runInitialLoad() }
            .onChange(of: profile.platforms) { _ in
                news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
                Task { await trending.fetch(platformFamilies: prefs.platforms, news: news.items) }
            }
            .onChange(of: profile.birthdate) { _ in
                news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
            }
            .onChange(of: store.games.count) { _ in
                news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
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
                    TrendingListView(items: trending.items) { id in
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
                        initialKind: selectedNewsCategory.kind
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .alert("Hitta spel i IGDB", isPresented: findAlertBinding) {
                Button("OK", role: .cancel) { findError = nil }
            } message: {
                Text(findError ?? "")
            }
        }
    }

    // MARK: - För Dig (Dynamisk Feed)
    private var forYouContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 1. Smart Spelslumpare (Vad ska du spela ikväll?)
                SmartGameRouletteCard()

                // 2. Fortsätt spela (visas bara om man har aktiva spel)
                ContinuePlayingSection()

                // 3. Hur mycket tid har du? (Speltidsväljare)
                PlaytimeFilterSection()

                // 4. Från din backlog (ospelade spel)
                BacklogSpotlightSection()

                // 5. Live IGDB Discovery (För dig, Populärt, Genrer, Kommande)
                LiveDiscoverySection(refreshTrigger: forYouRefreshID)

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable {
            forYouRefreshID = UUID()
            news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
            await trending.fetch(platformFamilies: prefs.platforms, news: news.items)
        }
    }

    // MARK: - Nyheter (Magasin & Kortlayout)
    private var newsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Sökfält för nyheter
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Sök bland nyheter, spel & källor...", text: $newsSearchText)
                        .textFieldStyle(.plain)
                    if !newsSearchText.isEmpty {
                        Button {
                            newsSearchText = ""
                            applyNewsFilters()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: newsSearchText) { _, _ in
                    applyNewsFilters()
                }

                // Kategori- och Snabbchips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(NewsFilterCategory.allCases) { category in
                            let isSelected = selectedNewsCategory == category
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedNewsCategory = category
                                    applyNewsFilters()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: category.icon)
                                        .font(.caption)
                                    Text(category.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isSelected ? Color.red : Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Trendar just nu (Karusell)
                TrendingSection(
                    items: trending.items,
                    onSelect: { sheet = .game($0) },
                    onSeeAll: { sheet = .trending }
                )

                // Nyhetsflöde
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Senaste nyheterna (\(news.items.count))")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)

                        Spacer()

                        if news.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    if news.isLoading && news.items.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView("Hämtar nyheter...")
                                .padding(.vertical, 30)
                            Spacer()
                        }
                    } else if news.items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "newspaper")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Inga nyheter matchar ditt val.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // 1. Hero-artikel (Första nyheten)
                        if let hero = news.items.first {
                            NewsHeroCard(
                                item: hero,
                                onOpen: { url in sheet = .safari(url) },
                                onFindIGDB: { title in openIGDBFrom(title: title) }
                            )
                        }

                        // 2. Resterande artiklar
                        ForEach(news.items.dropFirst()) { item in
                            if let url = item.link {
                                Button {
                                    sheet = .safari(url)
                                } label: {
                                    ArticleRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        openIGDBFrom(title: item.title)
                                    } label: {
                                        Label("Hitta i IGDB", systemImage: "magnifyingglass")
                                    }
                                    .tint(.red)
                                }
                                .contextMenu {
                                    Button {
                                        openIGDBFrom(title: item.title)
                                    } label: {
                                        Label("Hitta spel i IGDB", systemImage: "magnifyingglass")
                                    }
                                    Button {
                                        UIApplication.shared.open(url)
                                    } label: {
                                        Label("Öppna i Safari", systemImage: "safari")
                                    }
                                }
                            } else {
                                ArticleRow(item: item)
                            }
                        }

                        // Ladda fler-knapp
                        if news.canLoadMore {
                            Button {
                                news.loadMore()
                            } label: {
                                HStack(spacing: 8) {
                                    if news.isLoadingMore { ProgressView().scaleEffect(0.9) }
                                    Text(news.isLoadingMore ? "Laddar…" : "Visa fler nyheter")
                                        .font(.subheadline.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable {
            news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
            await trending.fetch(platformFamilies: prefs.platforms, news: news.items)
        }
    }

    private func applyNewsFilters() {
        let onlyMyGames = (selectedNewsCategory == .myGames)
        news.setFilters(
            platformKeywords: [],
            kind: selectedNewsCategory.kind,
            onlyLibrary: onlyMyGames,
            categoryName: selectedNewsCategory.rawValue,
            searchText: newsSearchText
        )
    }

    private func openIGDBFrom(title: String) {
        Task {
            do {
                if let id = try await OnlineSearchClient.firstID(for: title) {
                    sheet = .game(id)
                } else {
                    findError = "Hittade inget matchande spel i IGDB."
                }
            } catch {
                findError = error.localizedDescription
            }
        }
    }

    // MARK: - Komponenter
    private var tabPicker: some View {
        Picker("Utforska", selection: $tab) {
            ForEach(ExploreTab.allCases) { t in
                Text(t.rawValue).tag(t)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
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
