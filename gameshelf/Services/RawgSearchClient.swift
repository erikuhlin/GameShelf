//
//  RawgSearchClient.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-09.
//


//  Explore+RAWGSearch.swift
//  Gameshelf

import Foundation

enum RawgSearchClient {
    static func firstID(for title: String) async throws -> Int? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "RAWG_API_KEY") as? String, !key.isEmpty else {
            return nil
        }
        var comps = URLComponents(string: "https://api.rawg.io/api/games")!
        comps.queryItems = [
            .init(name: "key", value: key),
            .init(name: "search", value: title),
            .init(name: "page_size", value: "1")
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let decoded = try JSONDecoder().decode(ExploreRawgGamesResponse.self, from: data)
        return decoded.results.first?.id
    }
}