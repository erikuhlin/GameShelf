//
//  ExploreView.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-08.
//
import SwiftUI
import Combine
import SafariServices

extension URL: Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Lightweight preferences (to be replaced by real Profile later)
struct ExplorePrefs: Equatable {
    var minAge: Int
    var platforms: [String]
    

    static let example = ExplorePrefs(minAge: 16, platforms: ["PlayStation 5", "Nintendo Switch"]) // fallback until Profile exists
}

enum ExploreTab: String, CaseIterable, Identifiable { case forYou = "For You", news = "News"; var id: String { rawValue } }
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
    // Read from ProfileStore (age + platforms)
    @EnvironmentObject var profile: ProfileStore
    @State private var tab: ExploreTab = .forYou
    @StateObject private var news = NewsFetcher()
    @StateObject private var trending = TrendingFetcher()
    @State private var sheet: ExploreSheet? = nil
    
    @State private var findError: String? = nil

  
    @State private var newsPlatformFilter: NewsPlatformFilter = .all
    @State private var newsKindFilter: NewsKind? = nil

    private enum NewsPlatformFilter: String, CaseIterable {
        case all = "All", playstation = "PlayStation", xbox = "Xbox", nintendo = "Nintendo", pc = "PC", mobile = "Mobile"
    }

    private func keywords(for filter: NewsPlatformFilter) -> [String] {
        switch filter {
        case .all:
            return []
        case .playstation:
            return [
                "ps5", "ps4", "playstation", "playstation 5", "playstation 4"
            ]
        case .xbox:
            return [
                "xbox", "xbox series x", "xbox series s", "series x", "series s", "xbox one"
            ]
        case .nintendo:
            return [
                "switch", "nintendo switch", "nintendo"
            ]
        case .pc:
            return [
                "pc", "steam", "epic games store", "epic store", "gog"
            ]
        case .mobile:
            return [
                "iphone", "ios", "ipad", "ipadOS", "android", "mobile"
            ]
        }
    }


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
        news.reload(platforms: prefs.platforms, minAge: prefs.minAge)
        news.setFilters(platformKeywords: keywords(for: newsPlatformFilter), kind: newsKindFilter)
        await trending.fetch(platformFamilies: prefs.platforms, news: news.items)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .forYou:
            forYouContent
        case .news:
            newsContent
        }
    }

    var body: some View {
        AnyView(
            NavigationStack {
                content
                    .id(tab)
            }
        )
        .background(Color.ds.background.ignoresSafeArea())
        .navigationTitle("Explore")
        .task { await runInitialLoad() }
        .onChange(of: profile.platforms) { _ in
            news.reload(platforms: prefs.platforms, minAge: prefs.minAge)
            news.setFilters(platformKeywords: keywords(for: newsPlatformFilter), kind: newsKindFilter)
            Task { await trending.fetch(platformFamilies: prefs.platforms, news: news.items) }
        }
        .onChange(of: profile.birthdate) { _ in
            news.reload(platforms: prefs.platforms, minAge: prefs.minAge)
            news.setFilters(platformKeywords: keywords(for: newsPlatformFilter), kind: newsKindFilter)
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .safari(let url):
                SafariSheet(url: url)
                    .ignoresSafeArea()
            case .game(let rawgID):
                GameDetailView(rawgID: rawgID)
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
                    onFindRawg: { title in openRawgFrom(title: title) },
                    onLoadMore: { news.loadMore() },
                    initialPlatformRaw: newsPlatformFilter.rawValue,
                    initialKind: newsKindFilter
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .alert("Find on RAWG", isPresented: findAlertBinding) {
            Button("OK", role: .cancel) { findError = nil }
        } message: {
            Text(findError ?? "")
        }
    }

    private var forYouContent: some View {
        AnyView(
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    tabPicker
                    ForYouSection(prefs: prefs)
                    Spacer(minLength: 20)
                }
                .padding(.vertical, 8)
            }
        )
    }

    @ViewBuilder
    private func newsRow(_ a: NewsItem) -> some View {
        if let url = a.link {
            Button { sheet = .safari(url) } label: { ArticleRow(item: a) }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button { openRawgFrom(title: a.title) } label: { Label("Find on RAWG", systemImage: "magnifyingglass") }
                        .tint(.ds.brandRed)
                }
                .contextMenu {
                    Button { openRawgFrom(title: a.title) } label: { Label("Find on RAWG", systemImage: "magnifyingglass") }
                    Button { UIApplication.shared.open(url) } label: { Label("Open in Safari", systemImage: "safari") }
                }
        } else {
            HStack {
                ArticleRow(item: a)
                Button { openRawgFrom(title: a.title) } label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.borderless)
            }
        }
    }

    private var latestNewsHeader: some View {
        HStack {
            Text("Latest news")
            Spacer()
            Menu {
                ForEach(NewsPlatformFilter.allCases, id: \.self) { f in
                    Button(action: {
                        newsPlatformFilter = f
                        news.setFilters(platformKeywords: keywords(for: f), kind: newsKindFilter)
                    }) {
                        if newsPlatformFilter == f { Image(systemName: "checkmark") }
                        Text(f.rawValue)
                    }
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
            Menu {
                Button(action: {
                    newsKindFilter = nil
                    news.setFilters(platformKeywords: keywords(for: newsPlatformFilter), kind: nil)
                }) {
                    if newsKindFilter == nil { Image(systemName: "checkmark") }
                    Text("All types")
                }
                Divider()
                ForEach([NewsKind.review, .preview, .guide, .opinion, .interview, .video, .deal, .feature, .news], id: \.self) { k in
                    Button(action: {
                        newsKindFilter = k
                        news.setFilters(platformKeywords: keywords(for: newsPlatformFilter), kind: k)
                    }) {
                        if newsKindFilter == k { Image(systemName: "checkmark") }
                        Text(k.rawValue.capitalized)
                    }
                }
            } label: {
                Label("Type", systemImage: "line.3.horizontal.decrease")
            }
            Button("See all") { sheet = .newsList }
                .font(.callout)
        }
    }

    private var newsContent: some View {
        AnyView(
            List {
                // Tab picker as the first section header
                Section { EmptyView() } header: { tabPicker }

                // Trending carousel section
                Section {
                    TrendingSection(
                        items: trending.items,
                        onSelect: { sheet = .game($0) },
                        onSeeAll: { sheet = .trending }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                // Latest news list section
                Section {
                    ForEach(news.items) { a in
                        newsRow(a)
                    }

                    if news.canLoadMore {
                        Button(action: news.loadMore) {
                            HStack(spacing: 8) {
                                if news.isLoadingMore { ProgressView().scaleEffect(0.9) }
                                Text(news.isLoadingMore ? "Loading…" : "See more")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.ds.brandRed)
                    }
                } header: {
                    latestNewsHeader
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                news.reload(platforms: prefs.platforms, minAge: prefs.minAge)
                news.setFilters(platformKeywords: keywords(for: newsPlatformFilter), kind: newsKindFilter)
            }
        )
    }

    private func openRawgFrom(title: String) {
        Task {
            do {
                if let id = try await RawgSearchClient.firstID(for: title) {
                    sheet = .game(id)
                } else {
                    findError = "No matching game found on RAWG."
                }
            } catch {
                findError = error.localizedDescription
            }
        }
    }

    // MARK: - Components
    private var tabPicker: some View {
        Picker("Explore", selection: $tab) {
            ForEach(ExploreTab.allCases) { t in
                Text(t.rawValue).tag(t)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}

// MARK: - Sections (scaffold)


// MARK: - Small components
private func sectionHeader(title: String) -> some View {
    HStack {
        Text(title).font(.title3.bold())
        Spacer()
        Button { /* TODO: push full list */ } label: { Text("See all").font(.callout) }
    }
    .padding(.horizontal)
}

private func hint(_ text: String) -> some View {
    Text(text)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
}



// MARK: - In-app Safari sheet
private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
