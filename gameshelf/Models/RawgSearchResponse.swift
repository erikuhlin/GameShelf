//
//  RawgSearchResponse.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-26.
//


import Foundation

struct RawgSearchResponse: Codable {
    let results: [RawgGame]
}

struct RawgGame: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let released: String?
    let background_image: String?
    let background_image_additional: String?
    let short_screenshots: [RawgScreenshot]?
    let platforms: [RawgPlatformWrap]?
    let genres: [RawgNamed]?
    let developers: [RawgNamed]? // not always present in search (often nil)
    let rating: Double?          // RAWG user rating 0..5
}

struct RawgPlatformWrap: Codable, Hashable {
    let platform: RawgNamed
}

struct RawgNamed: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
}

struct RawgScreenshot: Codable, Hashable {
    let image: String
}

// MARK: - Mapping till din app-modell `Game`
extension RawgGame {
    private func cropped3x4(from urlString: String?, width: Int = 600, height: Int = 800) -> URL? {
        guard let urlString, var comps = URLComponents(string: urlString) else { return URL(string: urlString ?? "") }
        // Only rewrite RAWG CDN URLs
        if let host = comps.host, host.contains("rawg.io") == false { return comps.url }
        // If already cropped, keep as is
        if comps.path.contains("/media/crop/") { return comps.url }
        guard let mediaRange = comps.path.range(of: "/media/") else { return comps.url }
        let suffix = comps.path[mediaRange.upperBound...]
        comps.path = "/media/crop/\(width)/\(height)/" + suffix
        return comps.url
    }

    private func bestCoverURL() -> URL? {
        let candidates: [String] = [
            background_image,
            background_image_additional,
            short_screenshots?.first?.image
        ].compactMap { $0 }
        let firstURL = candidates.compactMap { URL(string: $0) }.first
        return cropped3x4(from: firstURL?.absoluteString)
    }

    func toGame() -> Game {
        let year: Int = {
            if let r = released, let y = Int(r.prefix(4)) { return y }
            return Calendar.current.component(.year, from: .now)
        }()

        let platformNames = platforms?.map { $0.platform.name } ?? []
        let firstPlatform = platformNames.first ?? "Unknown"

        let genreNames = genres?.map { $0.name } ?? []
        let dev = developers?.first?.name ?? ""

        let mappedRating: Int? = {
            guard let r = rating else { return nil }
            return Int((r * 2.0).rounded())
        }()

        let coverURL = bestCoverURL()

        return Game(
            title: name,
            platform: firstPlatform,
            releaseYear: year,
            genres: genreNames,
            developer: dev,
            status: .wishlist,
            rating: mappedRating,
            coverURL: coverURL
        )
    }
}
