//
//  NewsFeedView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-29.
//

import SwiftUI
import Combine
import SafariServices

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

private enum NewsSheetRoute: Identifiable {
    case safari(URL)
    case game(Int)
    case trending

    var id: String {
        switch self {
        case .safari(let u): return "safari:\(u.absoluteString)"
        case .game(let id): return "game:\(id)"
        case .trending: return "trending"
        }
    }
}

struct NewsFeedView: View {
    @EnvironmentObject var profile: ProfileStore
    @EnvironmentObject var store: LibraryStore

    @StateObject private var news = NewsFetcher()
    @StateObject private var trending = TrendingFetcher()

    @State private var selectedNewsCategory: NewsFilterCategory = .all
    @State private var newsSearchText: String = ""
    @State private var sheet: NewsSheetRoute? = nil
    @State private var findError: String? = nil

    private var prefs: ExplorePrefs {
        .init(minAge: profile.age, platforms: Array(profile.platforms))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 1. Sökfält för nyheter
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

                // 2. Kategori- och Snabbchips
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

                // 3. Trendar just nu (Karusell)
                TrendingSection(
                    items: trending.items,
                    isLoading: trending.isLoading,
                    onSelect: { sheet = .game($0) },
                    onSeeAll: { sheet = .trending }
                )

                // 4. Nyhetsflöde
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
                        // Hero-artikel (Första nyheten)
                        if let hero = news.items.first {
                            NewsHeroCard(
                                item: hero,
                                onOpen: { sheet = .safari($0) },
                                onFindIGDB: { openIGDBFrom(title: $0) }
                            )
                        }

                        // Resterande artiklar
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
        .navigationTitle("Nyheter")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
            await trending.fetch(platformFamilies: prefs.platforms, news: news.items)
        }
        .refreshable {
            news.reload(platforms: prefs.platforms, minAge: prefs.minAge, libraryGames: store.games)
            await trending.fetch(platformFamilies: prefs.platforms, news: news.items, forceReload: true)
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .safari(let url):
                SafariViewSheet(url: url)
                    .ignoresSafeArea()
            case .game(let id):
                GameDetailView(igdbID: id)
                    .ignoresSafeArea(edges: .bottom)
            case .trending:
                TrendingListView(items: trending.items, onRefresh: {
                    await trending.fetch(platformFamilies: prefs.platforms, news: news.items, forceReload: true)
                }) { id in
                    sheet = .game(id)
                }
                .presentationDetents([.large])
            }
        }
        .alert("Hitta spel i IGDB", isPresented: Binding<Bool>(
            get: { findError != nil },
            set: { if !$0 { findError = nil } }
        )) {
            Button("OK", role: .cancel) { findError = nil }
        } message: {
            Text(findError ?? "")
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
            if let id = await OnlineSearchClient.firstID(for: title) {
                sheet = .game(id)
            } else {
                findError = "Hittade inget matchande spel i IGDB."
            }
        }
    }
}

private struct SafariViewSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
