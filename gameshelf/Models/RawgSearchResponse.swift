//
//  RawgSearchResponse.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-26.
//


import Foundation

struct RawgSearchResponse: Decodable {
    let results: [RawgGame]
    let next: String?
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

    // Robust kandidat-loop: försök RAWG resize först (stabilare än crop), annars original-URL
    private func bestCoverURL() -> URL? {
        let candidates: [String] = [
            background_image,
            background_image_additional,
            short_screenshots?.first?.image
        ].compactMap { $0 }

        for s in candidates {
            // Försök server-resize (lämnar icke-RAWG-URL:er orörda; kan returnera nil om strängen är ogiltig)
            if let resized = RawgImage.resized(from: s, width: 600) {
                return resized
            }
            // Fallback: använd originalsträngen som URL om den är giltig
            if let original = URL(string: s) {
                return original
            }
        }
        return nil
    }

    func toGame() -> Game {
        let year: Int = {
            if let r = released, let y = Int(r.prefix(4)) { return y }
            return Calendar.current.component(.year, from: .now)
        }()

        let platformNames = platforms?.map { $0.platform.name } ?? []

        let genreNames = genres?.map { $0.name } ?? []

        let mappedRating: Int? = {
            guard let r = rating else { return nil }
            return Int((r * 2.0).rounded())
        }()

        let coverURL = bestCoverURL()

        return Game(
            title: name,
            platforms: platformNames,
            releaseYear: year,
            genres: genreNames,
            developers: developers?.map { $0.name } ?? [],
            status: .wishlist,
            rating: mappedRating,
            rawgRating: rating,
            coverURL: coverURL
        )
    }
}

