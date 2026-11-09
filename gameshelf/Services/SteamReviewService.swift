import Foundation

public struct SteamReviewAuthor: Codable, Sendable {
    public let steamid: String?
    public let playtimeForever: Int? // I minuter
    public let playtimeAtReview: Int?
    
    enum CodingKeys: String, CodingKey {
        case steamid
        case playtimeForever = "playtime_forever"
        case playtimeAtReview = "playtime_at_review"
    }
    
    public var playtimeHours: Double {
        Double(playtimeForever ?? 0) / 60.0
    }
    
    public var formattedPlaytime: String? {
        guard let minutes = playtimeForever, minutes > 0 else { return nil }
        let hours = minutes / 60
        if hours == 0 {
            return "\(minutes) min speltid"
        }
        return "\(hours) tim speltid"
    }
}

public struct SteamReviewItem: Codable, Identifiable, Sendable {
    public var id: String { recommendationid ?? UUID().uuidString }
    public let recommendationid: String?
    public let author: SteamReviewAuthor?
    public let language: String?
    public let review: String
    public let timestampCreated: Int?
    public let votedUp: Bool
    public let votesUp: Int?
    
    enum CodingKeys: String, CodingKey {
        case recommendationid
        case author
        case language
        case review
        case timestampCreated = "timestamp_created"
        case votedUp = "voted_up"
        case votesUp = "votes_up"
    }
    
    /// Rensar BBCode som Steam-användare flitigt använder (t.ex. [b], [h1], [list], etc.)
    public var cleanedReview: String {
        var text = review
        // Ta bort vanliga bbcode-taggar: [b], [/b], [h1]...[/h1], [url=...]...[/url], etc.
        text = text.replacingOccurrences(of: #"(?i)\[/?[a-z0-9_]+(=[^\]]*)?\]"#, with: "", options: .regularExpression)
        // Normalisera flera tomma rader i rad
        text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct SteamQuerySummary: Codable, Sendable {
    public let numReviews: Int?
    public let reviewScore: Int?
    public let reviewScoreDesc: String?
    public let totalPositive: Int?
    public let totalNegative: Int?
    public let totalReviews: Int?
    
    enum CodingKeys: String, CodingKey {
        case numReviews = "num_reviews"
        case reviewScore = "review_score"
        case reviewScoreDesc = "review_score_desc"
        case totalPositive = "total_positive"
        case totalNegative = "total_negative"
        case totalReviews = "total_reviews"
    }
    
    public var positivePercent: Int {
        guard let total = totalReviews, total > 0, let pos = totalPositive else { return 0 }
        return Int(round((Double(pos) / Double(total)) * 100.0))
    }
    
    public var localizedScoreDesc: String {
        guard let desc = reviewScoreDesc else { return "Betyg saknas" }
        switch desc.lowercased() {
        case "overwhelmingly positive":
            return "Överväldigande positivt"
        case "very positive":
            return "Mycket positivt"
        case "positive":
            return "Positivt"
        case "mostly positive":
            return "Mest positiva"
        case "mixed":
            return "Blandade omdömen"
        case "mostly negative":
            return "Mest negativa"
        case "negative":
            return "Negativt"
        case "very negative":
            return "Mycket negativt"
        case "overwhelmingly negative":
            return "Överväldigande negativt"
        default:
            return desc
        }
    }
    
    public var formattedTotalReviews: String {
        guard let total = totalReviews, total > 0 else { return "0 omdömen" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "sv_SE")
        let formattedCount = formatter.string(from: NSNumber(value: total)) ?? "\(total)"
        return "\(formattedCount) omdömen"
    }
}

public struct SteamAPIEnvelope: Codable, Sendable {
    public let response: SteamReviewsResponse?
    
    public nonisolated init(response: SteamReviewsResponse? = nil) {
        self.response = response
    }
}

public struct SteamReviewsResponse: Codable, Sendable {
    public var appID: String?
    public let success: Int?
    public let querySummary: SteamQuerySummary?
    public let reviews: [SteamReviewItem]?
    
    enum CodingKeys: String, CodingKey {
        case appID
        case success
        case querySummary = "query_summary"
        case reviews
    }
    
    public nonisolated init(
        appID: String? = nil,
        success: Int? = nil,
        querySummary: SteamQuerySummary? = nil,
        reviews: [SteamReviewItem]? = nil
    ) {
        self.appID = appID
        self.success = success
        self.querySummary = querySummary
        self.reviews = reviews
    }
}

/// Cache-wrapper för NSCache
private final class SteamCacheBox: @unchecked Sendable {
    let response: SteamReviewsResponse
    let fetchedAt: Date
    nonisolated init(response: SteamReviewsResponse) {
        self.response = response
        self.fetchedAt = Date()
    }
}

public actor SteamReviewService {
    public static let shared = SteamReviewService()
    
    private let cache = NSCache<NSString, SteamCacheBox>()
    private var titleToAppIDCache: [String: String] = [:]
    private var inFlightTasks: [String: Task<SteamReviewsResponse?, Never>] = [:]
    
    private init() {
        cache.countLimit = 150
    }
    
    /// Slår upp Steam App ID via Steam Store Search API baserat på speltitel (fallback om IGDB saknar Steam-länk)
    public func resolveAppID(forTitle title: String) async -> String? {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        
        let lowerKey = clean.lowercased()
        if let cached = titleToAppIDCache[lowerKey] {
            return cached.isEmpty ? nil : cached
        }
        
        guard let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlString = "https://store.steampowered.com/api/storesearch/?term=\(encoded)&l=english&cc=US"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 6.0
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            
            struct SearchResponse: Decodable {
                struct Item: Decodable {
                    let id: Int
                    let name: String
                }
                let total: Int?
                let items: [Item]?
            }
            
            let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
            guard let items = decoded.items, !items.isEmpty else {
                titleToAppIDCache[lowerKey] = ""
                return nil
            }
            
            // Sök efter matchande kandidat med strikt titellogik via GameTitleMatcher
            if let matched = items.first(where: {
                GameTitleMatcher.isMatch(gameTitle: clean, candidateTitle: $0.name)
            }) {
                let idStr = "\(matched.id)"
                titleToAppIDCache[lowerKey] = idStr
                return idStr
            }
            
            titleToAppIDCache[lowerKey] = ""
            return nil
        } catch {
            return nil
        }
    }
    
    /// Hämtar omdömen och sammanfattning för ett givet Steam App ID eller titel
    public func fetchReviews(appID: String? = nil, title: String? = nil, limit: Int = 3) async -> SteamReviewsResponse? {
        var resolvedID = appID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if resolvedID == nil || resolvedID?.isEmpty == true {
            if let title = title, !title.isEmpty {
                resolvedID = await resolveAppID(forTitle: title)
            }
        }
        
        guard let cleanID = resolvedID, !cleanID.isEmpty else { return nil }
        
        let cacheKey = NSString(string: cleanID)
        if let cached = cache.object(forKey: cacheKey) {
            // Cacha i 1 timme
            if Date().timeIntervalSince(cached.fetchedAt) < 3600 {
                return cached.response
            }
        }
        
        // Återanvänd pågående förfrågan om den redan körs
        if let existingTask = inFlightTasks[cleanID] {
            return await existingTask.value
        }
        
        let task = Task<SteamReviewsResponse?, Never> {
            defer {
                self.removeInFlight(cleanID)
            }
            
            // Använd officiella Steamworks Web API (den gamla store.steampowered.com/appreviews endpointen är pensionerad av Valve)
            let urlString = "https://api.steampowered.com/IUserReviewsService/GetAppReviews/v1/?appid=\(cleanID)&language=all&purchase_type=all&num_per_page=\(limit)&filter=all"
            guard let url = URL(string: urlString) else { return nil }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    return nil
                }
                
                // Nya API:et returnerar { "response": { "query_summary": ..., "reviews": [...] } }
                if let envelope = try? JSONDecoder().decode(SteamAPIEnvelope.self, from: data), var res = envelope.response {
                    res.appID = cleanID
                    self.storeInCache(key: cacheKey, response: res)
                    return res
                }
                
                // Fallback till direkt format om Valve ändrar tillbaka
                if var decoded = try? JSONDecoder().decode(SteamReviewsResponse.self, from: data) {
                    if decoded.querySummary != nil || decoded.success == 1 {
                        decoded.appID = cleanID
                        self.storeInCache(key: cacheKey, response: decoded)
                        return decoded
                    }
                }
                return nil
            } catch {
                return nil
            }
        }
        
        inFlightTasks[cleanID] = task
        return await task.value
    }
    
    private func removeInFlight(_ key: String) {
        inFlightTasks.removeValue(forKey: key)
    }
    
    private func storeInCache(key: NSString, response: SteamReviewsResponse) {
        cache.setObject(SteamCacheBox(response: response), forKey: key)
    }
}
