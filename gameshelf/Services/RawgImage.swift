//
//  RawgImage.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-27.
//

import Foundation

enum RawgImage {
    // MARK: - Public API

    /// Normalisera en RAWG-bild-URL på ett robust sätt.
    /// - Gör alltid https.
    /// - Om path innehåller "/screenshots/", lämna orörd (ingen resize/crop).
    /// - Om path innehåller "/media/" (t.ex. "/games/...") och inte redan är resize/crop, använd resize med given bredd.
    /// - Om redan resize/crop, lämna som är.
    /// - Om inte RAWG-host, returnera original-URL.
    static func normalize(from url: URL?, width: Int = 600, height: Int = 800) -> URL? {
        guard let url = url else { return nil }
        let httpsURL = ensureHTTPS(url)
        guard isRawgHost(httpsURL) else { return httpsURL }

        let path = httpsURL.path

        // Viktigt: screenshots ska INTE forceras till resize/crop – returnera original
        if path.contains("/screenshots/") {
            return httpsURL
        }

        // Om redan resize eller crop, lämna orörd
        if path.contains("/media/resize/") || path.contains("/media/crop/") {
            return httpsURL
        }

        // Om RAWG /media/... (t.ex. /games/...), använd resize
        if path.contains("/media/") {
            return resized(from: httpsURL, width: width) ?? httpsURL
        }

        return httpsURL
    }

    /// Overload för String?
    static func normalize(from string: String?, width: Int = 600, height: Int = 800) -> URL? {
        guard let s = string, let url = URL(string: s) else { return nil }
        return normalize(from: url, width: width, height: height)
    }

    /// Gör om RAWG-bildens URL till en 3:4-croppad variant via deras CDN.
    /// Exempel: https://media.rawg.io/media/games/... -> https://media.rawg.io/media/crop/600/800/games/...
    /// Notera: crop kan ibland fallera för vissa paths; överväg `normalize` eller `resized` i första hand.
    static func cropped3x4(from url: URL?, width: Int = 600, height: Int = 800) -> URL? {
        guard let url = url else { return nil }
        guard let host = url.host, host.contains("rawg.io") else { return url }
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }

        var path = comps.path
        guard path.contains("/media/") else { return url }
        guard !path.contains("/media/crop/") && !path.contains("/media/resize/") else { return url }

        path = path.replacingOccurrences(of: "/media/", with: "/media/crop/\(width)/\(height)/")
        comps.path = path
        comps.scheme = "https"
        return comps.url ?? url
    }

    static func cropped3x4(from string: String?, width: Int = 600, height: Int = 800) -> URL? {
        guard let s = string, let url = URL(string: s) else { return nil }
        return cropped3x4(from: url, width: width, height: height)
    }

    /// Skapa en RAWG-URL som använder resize-endpointen: /media/resize/W/...
    /// Detta är ofta mer tillförlitligt än crop för background_image-länkar.
    static func resized(from url: URL?, width: Int = 600) -> URL? {
        guard let url = url else { return nil }
        guard let host = url.host, host.contains("rawg.io") else { return url }
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }

        var path = comps.path
        guard path.contains("/media/") else { return url }
        // Undvik dubbeltransformering; OBS: Detta kommer också att lämna crop som crop.
        guard !path.contains("/media/crop/") && !path.contains("/media/resize/") else { return url }

        path = path.replacingOccurrences(of: "/media/", with: "/media/resize/\(width)/")
        comps.path = path
        comps.scheme = "https"
        return comps.url ?? url
    }

    static func resized(from string: String?, width: Int = 600) -> URL? {
        guard let s = string, let url = URL(string: s) else { return nil }
        return resized(from: url, width: width)
    }

    // MARK: - Helpers

    private static func ensureHTTPS(_ url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        if comps.scheme?.lowercased() != "https" {
            comps.scheme = "https"
        }
        return comps.url ?? url
    }

    private static func isRawgHost(_ url: URL) -> Bool {
        (url.host?.contains("rawg.io") == true)
    }
}
