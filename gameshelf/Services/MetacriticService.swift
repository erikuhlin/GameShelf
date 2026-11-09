import Foundation

public struct MetacriticPlatformScore: Codable, Identifiable, Sendable {
    public var id: String { slug.isEmpty ? name : slug }
    public let name: String
    public let slug: String
    public let score: Int?
    public let reviewCount: Int?
    public let isLeadPlatform: Bool
    
    public nonisolated init(
        name: String,
        slug: String,
        score: Int? = nil,
        reviewCount: Int? = nil,
        isLeadPlatform: Bool = false
    ) {
        self.name = name
        self.slug = slug
        self.score = score
        self.reviewCount = reviewCount
        self.isLeadPlatform = isLeadPlatform
    }
}

public struct MetacriticGameData: Codable, Sendable {
    public let found: Bool
    public let title: String?
    public let slug: String?
    public let url: String?
    public let metascore: Int?
    public let reviewCount: Int?
    public let mustPlay: Bool?
    public let sentiment: String?
    public let platforms: [MetacriticPlatformScore]?
    
    public nonisolated init(
        found: Bool = false,
        title: String? = nil,
        slug: String? = nil,
        url: String? = nil,
        metascore: Int? = nil,
        reviewCount: Int? = nil,
        mustPlay: Bool? = false,
        sentiment: String? = nil,
        platforms: [MetacriticPlatformScore]? = nil
    ) {
        self.found = found
        self.title = title
        self.slug = slug
        self.url = url
        self.metascore = metascore
        self.reviewCount = reviewCount
        self.mustPlay = mustPlay
        self.sentiment = sentiment
        self.platforms = platforms
    }
    
    /// Returnerar det bästa Metascore:t för en given plattform, med fallback till Lead Metascore
    public func score(forPlatform preferredPlatform: String?) -> Int? {
        guard let preferred = preferredPlatform?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !preferred.isEmpty else {
            return metascore
        }
        
        if let platforms = platforms {
            let match = platforms.first { p in
                let pName = p.name.lowercased()
                let pSlug = p.slug.lowercased()
                
                if pName == preferred || pSlug == preferred { return true }
                if preferred.contains("playstation 5") || preferred == "ps5" {
                    return pName.contains("playstation 5") || pSlug.contains("playstation-5")
                }
                if preferred.contains("playstation 4") || preferred == "ps4" {
                    return pName.contains("playstation 4") || pSlug.contains("playstation-4")
                }
                if preferred.contains("switch") || preferred.contains("nintendo") {
                    return pName.contains("switch") || pSlug.contains("switch")
                }
                if preferred.contains("series x") || preferred.contains("series s") || preferred.contains("xbox series") {
                    return pName.contains("series x") || pSlug.contains("series-x")
                }
                if preferred.contains("xbox one") {
                    return pName.contains("xbox one") || pSlug.contains("xbox-one")
                }
                if preferred.contains("pc") || preferred.contains("windows") || preferred.contains("steam") {
                    return pName.contains("pc") || pSlug == "pc"
                }
                return pName.contains(preferred) || preferred.contains(pName)
            }
            if let matchedScore = match?.score, matchedScore > 0 {
                return matchedScore
            }
        }
        return metascore
    }
}

private final class MetacriticCacheBox: @unchecked Sendable {
    let data: MetacriticGameData
    let fetchedAt: Date
    init(data: MetacriticGameData) {
        self.data = data
        self.fetchedAt = Date()
    }
}

public actor MetacriticService {
    public static let shared = MetacriticService()
    
    private let cache = NSCache<NSString, MetacriticCacheBox>()
    private var inFlightTasks: [String: Task<MetacriticGameData?, Never>] = [:]
    
    private let apiKey = "1MOZgmNFxvmljaQR1X9KAij9Mo4xAY3u"
    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    
    private init() {
        cache.countLimit = 200
    }
    
    private func normalizeTitle(_ t: String) -> String {
        t.lowercased()
            .replacingOccurrences(of: #"[:'’\-–—.,!?]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func fetchMetascore(forTitle title: String) async -> MetacriticGameData? {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        
        let normKey = normalizeTitle(clean)
        let cacheKey = NSString(string: normKey)
        
        if let cached = cache.object(forKey: cacheKey) {
            // Cacha i 24 timmar
            if Date().timeIntervalSince(cached.fetchedAt) < 86400 {
                return cached.data
            }
        }
        
        if let existing = inFlightTasks[normKey] {
            return await existing.value
        }
        
        let task = Task<MetacriticGameData?, Never> {
            defer {
                self.removeInFlight(normKey)
            }
            
            // 1. Sök på Metacritic
            guard let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            let searchUrlString = "https://backend.metacritic.com/finder/metacritic/search/\(encoded)/web?offset=0&limit=5&mcoTypeId=13&componentName=search&componentType=SearchResult&apiKey=\(self.apiKey)"
            guard let searchURL = URL(string: searchUrlString) else { return nil }
            
            var searchReq = URLRequest(url: searchURL)
            searchReq.timeoutInterval = 7.0
            searchReq.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
            searchReq.setValue("application/json", forHTTPHeaderField: "Accept")
            
            do {
                let (searchData, searchRes) = try await URLSession.shared.data(for: searchReq)
                guard let searchHttp = searchRes as? HTTPURLResponse, (200...299).contains(searchHttp.statusCode) else {
                    return nil
                }
                
                struct SearchItem: Decodable {
                    struct CriticSummary: Decodable {
                        let score: Int?
                    }
                    let title: String?
                    let slug: String?
                    let criticScoreSummary: CriticSummary?
                    let mustPlay: Bool?
                }
                struct SearchDataContainer: Decodable {
                    let items: [SearchItem]?
                }
                struct SearchEnvelope: Decodable {
                    let data: SearchDataContainer?
                }
                
                let searchDecoded = try JSONDecoder().decode(SearchEnvelope.self, from: searchData)
                guard let items = searchDecoded.data?.items, !items.isEmpty else {
                    let empty = MetacriticGameData(found: false)
                    self.storeInCache(key: cacheKey, data: empty)
                    return empty
                }
                
                // Välj bästa matchning med strikt titellogik via GameTitleMatcher
                guard let matched = items.first(where: {
                    guard let itemTitle = $0.title else { return false }
                    return GameTitleMatcher.isMatch(gameTitle: clean, candidateTitle: itemTitle)
                }), let slug = matched.slug, !slug.isEmpty else {
                    let empty = MetacriticGameData(found: false)
                    self.storeInCache(key: cacheKey, data: empty)
                    return empty
                }
                
                var leadScore = matched.criticScoreSummary?.score
                var reviewCount: Int? = nil
                var mustPlay = matched.mustPlay ?? false
                var sentiment: String? = nil
                var platforms: [MetacriticPlatformScore] = []
                
                // 2. Hämta detaljer för alla plattformar och recensionsantal
                let detailUrlString = "https://backend.metacritic.com/games/metacritic/\(slug)/web?componentName=product&componentType=Product&apiKey=\(self.apiKey)"
                if let detailURL = URL(string: detailUrlString) {
                    var detailReq = URLRequest(url: detailURL)
                    detailReq.timeoutInterval = 7.0
                    detailReq.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
                    detailReq.setValue("application/json", forHTTPHeaderField: "Accept")
                    
                    if let (detailData, detailRes) = try? await URLSession.shared.data(for: detailReq),
                       let detailHttp = detailRes as? HTTPURLResponse, (200...299).contains(detailHttp.statusCode) {
                        
                        struct DetailCriticSummary: Decodable {
                            let score: Int?
                            let reviewCount: Int?
                            let sentiment: String?
                        }
                        struct DetailPlatform: Decodable {
                            let name: String?
                            let slug: String?
                            let criticScoreSummary: DetailCriticSummary?
                            let isLeadPlatform: Bool?
                        }
                        struct DetailProduct: Decodable {
                            let criticScoreSummary: DetailCriticSummary?
                            let mustPlay: Bool?
                            let platforms: [DetailPlatform]?
                        }
                        struct DetailContainer: Decodable {
                            let item: DetailProduct?
                        }
                        struct DetailEnvelope: Decodable {
                            let data: DetailContainer?
                        }
                        
                        if let detailDecoded = try? JSONDecoder().decode(DetailEnvelope.self, from: detailData),
                           let product = detailDecoded.data?.item {
                            if let s = product.criticScoreSummary?.score { leadScore = s }
                            if let rc = product.criticScoreSummary?.reviewCount { reviewCount = rc }
                            if let sent = product.criticScoreSummary?.sentiment { sentiment = sent }
                            if let mp = product.mustPlay { mustPlay = mp }
                            
                            if let plats = product.platforms {
                                platforms = plats.compactMap { p in
                                    guard let pName = p.name else { return nil }
                                    return MetacriticPlatformScore(
                                        name: pName,
                                        slug: p.slug ?? "",
                                        score: p.criticScoreSummary?.score,
                                        reviewCount: p.criticScoreSummary?.reviewCount,
                                        isLeadPlatform: p.isLeadPlatform ?? false
                                    )
                                }
                            }
                        }
                    }
                }
                
                let result = MetacriticGameData(
                    found: leadScore != nil,
                    title: matched.title,
                    slug: slug,
                    url: "https://www.metacritic.com/game/\(slug)/",
                    metascore: leadScore,
                    reviewCount: reviewCount,
                    mustPlay: mustPlay,
                    sentiment: sentiment,
                    platforms: platforms
                )
                
                self.storeInCache(key: cacheKey, data: result)
                return result
            } catch {
                return nil
            }
        }
        
        inFlightTasks[normKey] = task
        return await task.value
    }
    
    private func removeInFlight(_ key: String) {
        inFlightTasks.removeValue(forKey: key)
    }
    
    private func storeInCache(key: NSString, data: MetacriticGameData) {
        cache.setObject(MetacriticCacheBox(data: data), forKey: key)
    }
}
