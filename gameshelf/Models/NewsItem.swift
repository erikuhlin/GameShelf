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
struct NewsItem: Identifiable, Hashable, Sendable, Codable {
    var id: String
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

    init(
        id: String? = nil,
        title: String,
        source: String,
        link: URL?,
        published: Date?,
        image: URL?,
        tags: [String],
        kind: NewsKind,
        matchedGameTitle: String? = nil,
        matchedGameCoverURL: URL? = nil,
        matchedGameStatus: String? = nil
    ) {
        self.id = id ?? (link?.absoluteString ?? UUID().uuidString)
        self.title = title
        self.source = source
        self.link = link
        self.published = published
        self.image = image
        self.tags = tags
        self.kind = kind
        self.matchedGameTitle = matchedGameTitle
        self.matchedGameCoverURL = matchedGameCoverURL
        self.matchedGameStatus = matchedGameStatus
    }

    var relativePublishedTime: String {
        guard let pub = published else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: pub, relativeTo: Date())
    }
}

// Tidsfilter för nyhetsarkiv
enum NewsTimeFilter: String, CaseIterable, Identifiable {
    case all = "Alla tider"
    case past24h = "Senaste 24h"
    case pastWeek = "Senaste veckan"
    case pastMonth = "Senaste månaden"
    case older = "Äldre än 30d"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "clock"
        case .past24h: return "clock.badge.checkmark"
        case .pastWeek: return "calendar"
        case .pastMonth: return "calendar.badge.clock"
        case .older: return "archivebox"
        }
    }
}

@MainActor
final class NewsFetcher: ObservableObject {
    @Published var items: [NewsItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var canLoadMore = false
    @Published var selectedTimeFilter: NewsTimeFilter = .all

    // Client-side filters & paging
    private var filterKeywords: [String] = []
    private var filterKind: NewsKind? = nil
    private var onlyLibraryGames: Bool = false
    private var searchFilter: String = ""
    private var currentCategoryName: String = "Alla"

    private let pageSize = 20
    private var currentPage = 1
    private var allItems: [NewsItem] = []

    private var archiveFileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("gameshelf_news_archive_v1.json")
    }

    private let feedStrings: [String] = [
        // 1. Svenska Spelmedier
        "https://www.gamereactor.se/rss/rss.php?texttype=4", // Nyheter SE
        "https://www.gamereactor.se/rss/rss.php?texttype=2", // Recensioner SE

        // 2. Dedikerade Recensioner & Tester
        "https://feeds.feedburner.com/ign/reviews",
        "https://www.eurogamer.net/feed/reviews",
        "https://www.gamespot.com/feeds/reviews/",
        "https://www.pushsquare.com/feeds/reviews",
        "https://www.nintendolife.com/feeds/reviews",
        "https://www.purexbox.com/feeds/reviews",

        // 3. Ledande Globala Spelmedier
        "https://feeds.feedburner.com/ign/all",
        "https://www.eurogamer.net/feed",
        "https://www.pcgamer.com/rss/",
        "https://www.polygon.com/rss/index.xml",
        "https://kotaku.com/rss",
        "https://www.gamespot.com/feeds/mashup/",
        "https://www.videogameschronicle.com/feed/",
        "https://www.gamesradar.com/rss/",
        "https://www.rockpapershotgun.com/feed",
        "https://www.vg247.com/feed",
        "https://www.pcgamesn.com/feed",
        "https://www.destructoid.com/feed/",
        "https://www.gematsu.com/feed",
        "https://www.siliconera.com/feed/",

        // 4. Officiella & Plattformsspecifika
        "https://news.xbox.com/en-us/feed/",
        "https://blog.playstation.com/feed/",
        "https://www.nintendolife.com/feeds/latest",
        "https://nintendoeverything.com/feed/",
        "https://www.pushsquare.com/feeds/latest",
        "https://www.purexbox.com/feeds/latest",
        "https://toucharcade.com/feed/"
    ]

    init() {
        // Läs in sparat arkiv från disk omedelbart vid start så användaren ser nyheter direkt
        let cached = loadArchiveFromDisk()
        if !cached.isEmpty {
            self.allItems = cached
            self.recompute()
        }
    }

    private func loadArchiveFromDisk() -> [NewsItem] {
        guard let url = archiveFileURL, FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([NewsItem].self, from: data)
            return decoded
        } catch {
            return []
        }
    }

    private func saveArchiveToDisk(_ items: [NewsItem]) {
        guard let url = archiveFileURL else { return }
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            // Ignorera sparfel
        }
    }

    /// Hämtar alla RSS-källor parallellt, sparar i disk-arkiv och matchar mot biblioteket
    func reload(platforms: [String] = [], minAge: Int = 0, libraryGames: [Game] = []) {
        Task {
            isLoading = true

            // Läs in tidigare sparat arkiv så vi inte tappar äldre artiklar
            let existingArchive = self.loadArchiveFromDisk()
            if self.allItems.isEmpty {
                self.allItems = existingArchive
                self.recompute()
            }

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

            // Slå ihop nya artiklar med befintligt arkiv
            let merged = collected + existingArchive

            // Filtrera bort dubbletter baserat på förenklad titel eller unik länk
            var seenKeys = Set<String>()
            let uniqueCollected = merged.filter { item in
                let key = item.link?.absoluteString ?? item.title.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
                if seenKeys.contains(key) { return false }
                seenKeys.insert(key)
                return true
            }

            // Sortera efter datum (nyast först) och behåll upp till 800 historiska artiklar
            let sorted = uniqueCollected
                .sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }
                .prefix(800)

            let finalArchive = Array(sorted)

            // Spara det uppdaterade arkivet till disk
            self.saveArchiveToDisk(finalArchive)

            // Matcha mot bibliotekets spel
            let enriched = finalArchive.map { item -> NewsItem in
                var modItem = item
                let lowerTitle = item.title.lowercased()

                if let matchedGame = libraryGames.first(where: { g in
                    let gTitle = g.title.lowercased()
                    return gTitle.count >= 3 && lowerTitle.contains(gTitle)
                }) {
                    modItem.matchedGameTitle = matchedGame.title
                    modItem.matchedGameCoverURL = matchedGame.coverURL
                    modItem.matchedGameStatus = matchedGame.statusDisplayTitle
                }
                return modItem
            }

            self.allItems = enriched
            self.currentPage = 1
            self.recompute()
            self.isLoading = false
        }
    }

    func setFilters(
        platformKeywords: [String],
        kind: NewsKind?,
        onlyLibrary: Bool = false,
        categoryName: String = "Alla",
        searchText: String = "",
        timeFilter: NewsTimeFilter? = nil
    ) {
        self.filterKeywords = platformKeywords.map { $0.lowercased() }
        self.filterKind = kind
        self.onlyLibraryGames = onlyLibrary
        self.currentCategoryName = categoryName
        self.searchFilter = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let tf = timeFilter {
            self.selectedTimeFilter = tf
        }
        self.currentPage = 1
        self.recompute()
    }

    func setTimeFilter(_ filter: NewsTimeFilter) {
        self.selectedTimeFilter = filter
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

        // 1. Filtrera på tidsintervall
        let now = Date()
        switch selectedTimeFilter {
        case .all:
            break
        case .past24h:
            let cutoff = Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now
            list = list.filter { ($0.published ?? .distantPast) >= cutoff }
        case .pastWeek:
            let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            list = list.filter { ($0.published ?? .distantPast) >= cutoff }
        case .pastMonth:
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
            list = list.filter { ($0.published ?? .distantPast) >= cutoff }
        case .older:
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
            list = list.filter { ($0.published ?? .distantPast) < cutoff }
        }

        // 2. Filtrera på kategori
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

        // 3. Filtrera på plattforms-nyckelord om sådana valts
        if !filterKeywords.isEmpty {
            list = list.filter { item in
                let text = (item.title + " " + item.tags.joined(separator: " ")).lowercased()
                return filterKeywords.contains { text.contains($0) }
            }
        }

        // 4. Filtrera på söktext (söker genom titel, källa och matchat biblioteksspel)
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
