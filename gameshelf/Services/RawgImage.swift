//
//  RawgImage.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-27.
//


import Foundation

enum RawgImage {
    /// Gör om RAWG-bildens URL till en 3:4-croppad variant via deras CDN.
    /// Exempel: https://media.rawg.io/media/games/.. -> https://media.rawg.io/media/crop/600/800/games/..
    static func cropped3x4(from url: URL?, width: Int = 600, height: Int = 800) -> URL? {
        guard let url = url else { return nil }
        // Only process RAWG CDN URLs; leave others untouched
        guard let host = url.host, host.contains("rawg.io") else { return url }
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }

        var path = comps.path
        // Only transform when path includes /media/
        guard path.contains("/media/") else { return url }
        // Avoid double transforming if already cropped or resized
        guard !path.contains("/media/crop/") && !path.contains("/media/resize/") else { return url }

        // Transform /media/... -> /media/crop/W/H/...
        path = path.replacingOccurrences(of: "/media/", with: "/media/crop/\(width)/\(height)/")
        comps.path = path
        // Ensure https scheme
        comps.scheme = "https"
        return comps.url ?? url
    }

    /// Convenience overload for String? sources
    static func cropped3x4(from string: String?, width: Int = 600, height: Int = 800) -> URL? {
        guard let s = string, let url = URL(string: s) else { return nil }
        return cropped3x4(from: url, width: width, height: height)
    }
}
