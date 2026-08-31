//
//  IGDBAuthConfig.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-12.
//

import Foundation

enum IGDBAuthConfig: Sendable {
    // API-nycklar för Twitch / IGDB
    // Standardplatshållare - faktiska hemligheter ska ALDRIG checkas in i Git.
    // Lokala nycklar kan sättas via:
    // 1. Miljövariabler i Xcode Scheme (TWITCH_CLIENT_ID, TWITCH_CLIENT_SECRET)
    // 2. Git-ignorerad Secrets.plist i bundle
    // 3. UserDefaults (twitch_client_id, twitch_client_secret)
    nonisolated static let defaultClientID = "5f5tlhpr9riinitgw2k846ty5907n7"
    nonisolated static let defaultClientSecret = "wpvp8sqawxyx6861um4di08ia15txk"

    nonisolated static var clientID: String {
        if let env = ProcessInfo.processInfo.environment["TWITCH_CLIENT_ID"], !env.isEmpty {
            return env
        }
        if let plistVal = valueFromSecretsPlist(key: "TWITCH_CLIENT_ID") {
            return plistVal
        }
        if let stored = UserDefaults.standard.string(forKey: "twitch_client_id"), !stored.isEmpty {
            return stored
        }
        return defaultClientID
    }

    nonisolated static var clientSecret: String {
        if let env = ProcessInfo.processInfo.environment["TWITCH_CLIENT_SECRET"], !env.isEmpty {
            return env
        }
        if let plistVal = valueFromSecretsPlist(key: "TWITCH_CLIENT_SECRET") {
            return plistVal
        }
        if let stored = UserDefaults.standard.string(forKey: "twitch_client_secret"), !stored.isEmpty {
            return stored
        }
        return defaultClientSecret
    }

    nonisolated static var isConfigured: Bool {
        return !clientID.isEmpty && clientID != "your_twitch_client_id_here" &&
               !clientSecret.isEmpty && clientSecret != "your_twitch_client_secret_here"
    }

    nonisolated private static func valueFromSecretsPlist(key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let val = plist[key] as? String,
              !val.isEmpty,
              !val.contains("your_twitch") else {
            return nil
        }
        return val
    }
}
