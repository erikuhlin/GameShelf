//
//  ToplistService.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-10-02.
//

import Foundation

public struct ToplistGameItem: Identifiable, Codable, Sendable {
    public let igdb_id: Int
    public let title: String
    public let slug: String?
    public let cover_url: String?
    public let release_year: Int?
    public let first_release_date: Int?
    public let genres: [String]?
    public let platforms: [String]?
    public let total_rating: Double?
    public let total_rating_count: Int?
    public let weighted_score: Double?
    public let overall_rank: Int?
    public let genre_ranks: [String: Int]?

    public var id: Int { igdb_id }

    public var isLowVotes: Bool {
        (total_rating_count ?? 0) < 50
    }

    public var formattedScore: String {
        guard let score = weighted_score, score > 0 else { return "–" }
        return String(format: "%.1f", score / 10.0)
    }

    public var rawRatingFormatted: String {
        guard let rating = total_rating, rating > 0 else { return "–" }
        return String(format: "%.1f", rating / 10.0)
    }

    public var coverURL: URL? {
        guard let urlString = cover_url, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
}

public actor ToplistService {
    public static let shared = ToplistService()

    private var cache: [Int: ToplistGameItem] = [:]

    private init() {}

    /// Hämtar topplistan med valfria filter från Supabase game_ratings-tabellen
    public func fetchToplist(
        platform: String? = nil,
        genre: String? = nil,
        yearFrom: Int? = nil,
        yearTo: Int? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [ToplistGameItem] {
        guard let baseURL = URL(string: "\(SupabaseConfig.baseURLString)/rest/v1/game_ratings") else {
            throw URLError(.badURL)
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "weighted_score.desc,total_rating_count.desc"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
        ]

        if let p = platform, !p.isEmpty, p != "Alla" {
            // Postgres contains operator on array: cs.{"PlayStation 5"}
            queryItems.append(URLQueryItem(name: "platforms", value: "cs.{\(p)}"))
        }

        if let g = genre, !g.isEmpty, g != "Alla" {
            let actualGenre = (g.lowercased() == "rpg") ? "Role-playing (RPG)" : g
            queryItems.append(URLQueryItem(name: "genres", value: "cs.{\(actualGenre)}"))
        }

        if let yFrom = yearFrom {
            queryItems.append(URLQueryItem(name: "release_year", value: "gte.\(yFrom)"))
        }

        if let yTo = yearTo {
            queryItems.append(URLQueryItem(name: "release_year", value: "lte.\(yTo)"))
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems

        guard let requestURL = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let items = try JSONDecoder().decode([ToplistGameItem].self, from: data)

        // Uppdatera cache för snabb tillgång vid detaljvisning
        for item in items {
            cache[item.igdb_id] = item
        }

        return items
    }

    /// Hämtar rankning och betyg för ett specifikt IGDB-ID (används av GameDetailView)
    public func fetchGameRating(igdbID: Int) async -> ToplistGameItem? {
        if let cached = cache[igdbID] {
            return cached
        }

        guard let baseURL = URL(string: "\(SupabaseConfig.baseURLString)/rest/v1/game_ratings") else {
            return nil
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "igdb_id", value: "eq.\(igdbID)"),
            URLQueryItem(name: "limit", value: "1"),
        ]

        guard let requestURL = components?.url else { return nil }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let items = try JSONDecoder().decode([ToplistGameItem].self, from: data)
            if let first = items.first {
                cache[igdbID] = first
                return first
            }
            return nil
        } catch {
            return nil
        }
    }
}
