//
//  NewsItem.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//


//  NewsFetcher.swift
//  Gameshelf

import Foundation
import SwiftUI
import Combine

// Optional classification for article type
enum NewsKind: String, Codable, Hashable {
    case review, guide, opinion, preview, interview, video, deal, news, feature, other
}

// Lätta nyhetsartiklar som visas i Explore
struct NewsItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let source: String
    let link: URL?
    let published: Date?
    let image: URL?
    let tags: [String]
    let kind: NewsKind
}

@MainActor
final class NewsFetcher: ObservableObject {
    @Published var items: [NewsItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var canLoadMore = false

    // Client-side filters & paging
    private var filterKeywords: [String] = []   // lowercased platform keywords
    private var filterKind: NewsKind? = nil
    private let pageSize = 20
    private var currentPage = 1

    private var allItems: [NewsItem] = []

    /// Hämtar och blandar nyheter från flera RSS/Atom-flöden
    func reload(platforms: [String], minAge: Int) {
        Task {
            isLoading = true
            items = []
            allItems = []
            canLoadMore = false

            let feedStrings: [String] = [
                // General multi-platform outlets
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
                "https://www.gameinformer.com/news.xml",
                // Platform-focused official blogs
                "https://blog.playstation.com/feed/",
                "https://news.xbox.com/en-us/feed/",
                "https://www.nintendolife.com/feeds/latest",
                "https://www.pushsquare.com/feeds/latest",
                "https://www.purexbox.com/feeds/latest"
            ]
            let feeds: [URL] = feedStrings.compactMap { URL(string: $0) }
            var collected: [NewsItem] = []
            for url in feeds {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let parsed = RSSParser.parse(data: data)
                    collected.append(contentsOf: parsed)
                } catch { /* ignorera enskilda feed-fel */ }
            }

            let byMatch = collected

            // Drop items older than ~120 days to keep pool relevant (feeds vary in length)
            let cutoff = Calendar.current.date(byAdding: .day, value: -120, to: Date()) ?? Date()
            let recent = byMatch.filter { item in
                if let d = item.published { return d >= cutoff }
                return true // keep if unknown
            }

            // Sortera efter datum och mixa källor (round-robin)
            let sorted = recent.sorted { (a, b) in (a.published ?? .distantPast) > (b.published ?? .distantPast) }
            var buckets: [String: [NewsItem]] = [:]
            for it in sorted { buckets[it.source, default: []].append(it) }
            var order = Array(buckets.keys)
            order.sort { (buckets[$0]?.first?.published ?? .distantPast) > (buckets[$1]?.first?.published ?? .distantPast) }

            var mixed: [NewsItem] = []
            var idx: [String: Int] = [:]
            outer: while mixed.count < 250 {
                var progressed = false
                for k in order {
                    let i = idx[k] ?? 0
                    if let arr = buckets[k], i < arr.count {
                        mixed.append(arr[i]); idx[k] = i + 1; progressed = true
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

    private func recompute() {
        var filtered = allItems
        // kind filter first
        if let k = filterKind {
            filtered = filtered.filter { $0.kind == k }
        }
        // platform keywords filter on title
        if !filterKeywords.isEmpty {
            filtered = filtered.filter { item in
                let t = item.title.lowercased()
                return filterKeywords.contains(where: { t.contains($0) })
            }
        }
        let end = min(filtered.count, currentPage * pageSize)
        self.items = Array(filtered.prefix(end))
        self.canLoadMore = filtered.count > self.items.count
    }

    func setFilters(platformKeywords: [String], kind: NewsKind?) {
        self.filterKeywords = platformKeywords.map { $0.lowercased() }
        self.filterKind = kind
        self.currentPage = 1
        self.recompute()
    }

    /// Reset pagination back to first page and recompute with current filters
    func resetPaging() {
        currentPage = 1
        recompute()
    }

    func loadMore() {
        guard !isLoadingMore, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        currentPage += 1
        recompute()
    }
}
