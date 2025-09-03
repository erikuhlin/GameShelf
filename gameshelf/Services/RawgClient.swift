//
//  RawgClient.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-26.
//


import Foundation

struct RawgClient {
    // 1) Hämta din API-nyckel: https://rawg.io/apidocs
    // 2) Lägg in den i Info.plist som RAWG_API_KEY (String)
    private let apiKey: String = {
        Bundle.main.object(forInfoDictionaryKey: "RAWG_API_KEY") as? String ?? ""
    }()

    private let base = URL(string: "https://api.rawg.io/api")!
    private let session: URLSession = .shared

    enum RawgError: Error { case missingKey, badResponse, decoding }

    func searchGames(query: String, pageSize: Int = 20) async throws -> [RawgGame] {
        guard !apiKey.isEmpty else { throw RawgError.missingKey }
        var comps = URLComponents(url: base.appendingPathComponent("games"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "key", value: apiKey),
            .init(name: "search", value: query),
            .init(name: "page_size", value: String(pageSize)),
            .init(name: "search_precise", value: "true")
        ]
        let (data, resp) = try await session.data(from: comps.url!)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw RawgError.badResponse }
        do {
            let decoded = try JSONDecoder().decode(RawgSearchResponse.self, from: data)
            return decoded.results
        } catch {
            throw RawgError.decoding
        }
    }
}