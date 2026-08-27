//
//  NewsItem.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//

import Foundation
import SwiftUI
import Combine

// Klassificering för typ av artikel
enum NewsKind: String, Codable, Hashable, CaseIterable {
    case review
    case guide
    case opinion
    case preview
    case interview
    case video
    case deal
    case news
    case feature
    case update
    case other

    var localizedName: String {
        switch self {
        case .review: return "Recension"
        case .guide: return "Guide"
        case .opinion: return "Krönika"
        case .preview: return "Förhandstitt"
        case .interview: return "Intervju"
        case .video: return "Trailer"
        case .deal: return "Erbjudande"
        case .news: return "Nyhet"
        case .feature: return "Reportage"
        case .update: return "Uppdatering"
        case .other: return "Övrigt"
        }
    }

    var icon: String {
        switch self {
        case .review: return "star.fill"
        case .guide: return "book.fill"
        case .opinion: return "quote.bubble.fill"
        case .preview: return "sparkles"
        case .interview: return "person.2.fill"
        case .video: return "play.circle.fill"
        case .deal: return "tag.fill"
        case .news: return "newspaper.fill"
        case .feature: return "text.book.closed.fill"
        case .update: return "arrow.triangle.2.circlepath"
        case .other: return "doc.text"
        }
    }
}

// Lätta nyhetsartiklar som visas i Explore
struct NewsItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let title: String
    let source: String
    let link: URL?
    let published: Date?
    let image: URL?
    let tags: [String]
    let kind: NewsKind
    var matchedGameTitle: String? = nil
    var matchedGameCoverURL: URL? = nil
    var matchedGameStatus: String? = nil

    var relativePublishedTime: String {
        guard let pub = published else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: pub, relativeTo: Date())
    }
}

@MainActor
final class NewsFetcher: ObservableObject {
    @Published var items: [NewsItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var canLoadMore = false

    // Client-side filters & paging
    private var filterKeywords: [String] = []
    private var filterKind: NewsKind? = nil
    private var onlyLibraryGames: Bool = false
    private var searchFilter: String = ""

    private let pageSize = 20
    private var currentPage = 1
    private var allItems: [NewsItem] = []

    private let feedStrings: [String] = [
        "https://www.ign.com/rss",
        "https://www.eurogamer.net/api/frontpage.rss",
        "https://www.pcgamer.com/rss/",
        "https://www.polygon.com/rss/index.xml",
        "https://www.theverge.com/games/rss/index.xml",
        "https://kotaku.com/rss",
        "https://www.gamespot.com/feeds/mashup/",
        "https://www.videogameschronicle.com/feed/",
        "https://www.gamesradar.com/rss/",
        "https://www.rockpapershotgun.com/feed",
        "https://www.pcgamesn.com/feed",
        "https://www.destructoid.com/feed/",
        "https://www.gematsu.com/feed",
        "https://blog.playstation.com/feed/",
        "https://news.xbox.com/en-us/feed/",
        "https://www.nintendolife.com/feeds/latest",
        "https://www.pushsquare.com/feeds/latest",
        "https://www.purexbox.com/feeds/latest"
    ]

    /// Hämtar alla RSS-källor parallellt på under en sekund och matchar mot biblioteket
    func reload(platforms: [String] = [], minAge: Int = 0, libraryGames: [Game] = []) {
        Task {
            isLoading = true
            items = []
            allItems = []
            canLoadMore = false

            let feeds = feedStrings.compactMap { URL(string: $0) }

            // Parallell hämtning med TaskGroup
            let collected: [NewsItem] = await withTaskGroup(of: [NewsItem].self) { group in
                for url in feeds {
                    group.addTask {
                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            return RSSParser.parse(data: data)
                        } catch {
                            return []
                        }
                    }
                }

                var allResults: [NewsItem] = []
                for await feedItems in group {
                    allResults.append(contentsOf: feedItems)
                }
                return allResults
            }

            // Filtrera bort gamla artiklar (> 60 dagar)
            let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
            let recent = collected.filter { item in
                if let d = item.published { return d >= cutoff }
                return true
            }

            // Sortera efter datum
            let sorted = recent.sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }

            // Matcha mot bibliotekets spel
            let enriched = sorted.map { item -> NewsItem in
                var modItem = item
                let lowerTitle = item.title.lowercased()

                if let matchedGame = libraryGames.first(where: { g in
                    let gTitle = g.title.lowercased()
                    return gTitle.count >= 3 && lowerTitle.contains(gTitle)
                }) {
                    modItem.matchedGameTitle = matchedGame.title
                    modItem.matchedGameCoverURL = matchedGame.coverURL
                    modItem.matchedGameStatus = matchedGame.status.rawValue
                }
                return modItem
            }

            // Blanda källor för variation
            var buckets: [String: [NewsItem]] = [:]
            for it in enriched { buckets[it.source, default: []].append(it) }
            var order = Array(buckets.keys)
            order.sort { (buckets[$0]?.first?.published ?? .distantPast) > (buckets[$1]?.first?.published ?? .distantPast) }

            var mixed: [NewsItem] = []
            var idx: [String: Int] = [:]
            while mixed.count < 300 {
                var progressed = false
                for k in order {
                    let i = idx[k] ?? 0
                    if let arr = buckets[k], i < arr.count {
                        mixed.append(arr[i])
                        idx[k] = i + 1
                        progressed = true
                    }
                }
                if !progressed { break }
            }

            self.allItems = mixed
            self.currentPage = 1
            self.recompute()
            self.isLoading = false
        }
    }

    private var currentCategoryName: String = "Alla"

    func setFilters(platformKeywords: [String], kind: NewsKind?, onlyLibrary: Bool = false, categoryName: String = "Alla", searchText: String = "") {
        self.filterKeywords = platformKeywords.map { $0.lowercased() }
        self.filterKind = kind
        self.onlyLibraryGames = onlyLibrary
        self.currentCategoryName = categoryName
        self.searchFilter = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.currentPage = 1
        self.recompute()
    }

    func loadMore() {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.currentPage += 1
            self.recompute()
            self.isLoadingMore = false
        }
    }

    private func recompute() {
        var list = allItems

        // 1. Filtrera på kategori
        switch currentCategoryName {
        case "Mina spel":
            list = list.filter { $0.matchedGameTitle != nil }
        case "Uppdateringar":
            let tokens = ["update", "patch", "dlc", "hotfix", "expansion", "season", "uppdatering", "fix", "version"]
            list = list.filter { item in
                item.kind == .update || tokens.contains(where: { item.title.localizedCaseInsensitiveContains($0) })
            }
        case "Recensioner":
            let tokens = ["review", "recension", "score", "betyg", "verdict"]
            list = list.filter { item in
                item.kind == .review || tokens.contains(where: { item.title.localizedCaseInsensitiveContains($0) })
            }
        case "Trailers":
            let tokens = ["trailer", "gameplay", "teaser", "video", "watch"]
            list = list.filter { item in
                item.kind == .video || tokens.contains(where: { item.title.localizedCaseInsensitiveContains($0) })
            }
        case "Förhandstittar":
            let tokens = ["preview", "förhandstitt", "hands-on", "first look", "impressions"]
            list = list.filter { item in
                item.kind == .preview || tokens.contains(where: { item.title.localizedCaseInsensitiveContains($0) })
            }
        default:
            break
        }

        // 2. Filtrera på plattforms-nyckelord om sådana valts
        if !filterKeywords.isEmpty {
            list = list.filter { item in
                let text = (item.title + " " + item.tags.joined(separator: " ")).lowercased()
                return filterKeywords.contains { text.contains($0) }
            }
        }

        // 3. Filtrera på söktext
        if !searchFilter.isEmpty {
            list = list.filter {
                $0.title.lowercased().contains(searchFilter) ||
                $0.source.lowercased().contains(searchFilter) ||
                ($0.matchedGameTitle?.lowercased().contains(searchFilter) ?? false)
            }
        }

        let totalAvailable = list.count
        let limit = min(currentPage * pageSize, totalAvailable)
        self.items = Array(list.prefix(limit))
        self.canLoadMore = limit < totalAvailable
    }
}
