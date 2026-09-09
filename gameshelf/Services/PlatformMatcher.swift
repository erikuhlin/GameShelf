//
//  PlatformMatcher.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-30.
//

import Foundation

struct PlatformMatcher {
    /// Hämtar användarens sparade profilplattformar direkt från UserDefaults
    static func currentProfilePlatforms() -> Set<String> {
        if let arr = UserDefaults.standard.array(forKey: "profile.platforms") as? [String] {
            return Set(arr)
        }
        return ProfileStore.defaultPlatforms
    }

    /// Matchar spelets tillgängliga IGDB-plattformar mot användarens valda profilplattformar.
    /// Om en eller flera matchningar finns returneras dessa så att spelet automatiskt får rätt konsol/plattform.
    /// Om ingen matchning finns (t.ex. för äldre retrospel) returneras en lämplig fallback (spelets primära plattform).
    static func resolvePlatforms(availableIGDBPlatforms: [String], userProfilePlatforms: Set<String>? = nil) -> [String] {
        guard !availableIGDBPlatforms.isEmpty else { return [] }
        let userPlatforms = userProfilePlatforms ?? currentProfilePlatforms()
        guard !userPlatforms.isEmpty else {
            return [availableIGDBPlatforms.first!]
        }

        var matched: [String] = []

        for igdbName in availableIGDBPlatforms {
            let lowerIGDB = igdbName.lowercased()

            for userPlat in userPlatforms {
                let lowerUser = userPlat.lowercased()

                if isMatch(igdb: lowerIGDB, user: lowerUser) {
                    if !matched.contains(igdbName) {
                        matched.append(igdbName)
                    }
                    break
                }
            }
        }

        // 1. Om vi fick träff på användarens profilplattformar, använd dessa!
        if !matched.isEmpty {
            return matched
        }

        // 2. Fallback: Inget matchade användarens profil
        // Prioritera vanliga moderna plattformar framför nedlagda/nischade som Stadia, Ouya etc.
        let priorityList = ["PlayStation 5", "PC (Microsoft Windows)", "Xbox Series X|S", "Nintendo Switch", "PlayStation 4", "Xbox One"]
        for p in priorityList {
            if let found = availableIGDBPlatforms.first(where: { isMatch(igdb: $0.lowercased(), user: p.lowercased()) }) {
                return [found]
            }
        }
        return [availableIGDBPlatforms.first!]
    }

    private static func isMatch(igdb: String, user: String) -> Bool {
        // Exakt match eller enkel delsträng
        if igdb == user {
            return true
        }

        // PlayStation 5 / PS5
        if (user.contains("playstation 5") || user.contains("ps5")) {
            if igdb.contains("playstation 5") || igdb == "ps5" { return true }
        }

        // PlayStation 4 / PS4
        if (user.contains("playstation 4") || user.contains("ps4")) {
            if igdb.contains("playstation 4") || igdb == "ps4" { return true }
        }

        // Nintendo Switch
        if user.contains("switch") {
            if igdb.contains("switch") { return true }
        }

        // Xbox Series X|S
        if user.contains("series x") || user.contains("series s") || user.contains("xbox series") {
            if igdb.contains("series x") || igdb.contains("series s") || igdb.contains("xbox series") { return true }
        }

        // Xbox One
        if user.contains("xbox one") {
            if igdb.contains("xbox one") { return true }
        }

        // PC / Steam Deck / Windows
        if user == "pc" || user.contains("steam") || user.contains("windows") {
            if igdb.contains("pc") || igdb.contains("windows") || igdb.contains("steam") { return true }
        }

        // Mac / iOS
        if user.contains("mac") {
            if igdb.contains("mac") { return true }
        }
        if user.contains("ios") || user.contains("mobile") {
            if igdb.contains("ios") || igdb.contains("iphone") || igdb.contains("ipad") || igdb.contains("android") { return true }
        }

        // Breda grupper från ProfileView (t.ex. "Nintendo (NES/SNES/64/Switch)")
        if user.contains("nintendo") {
            if igdb.contains("nintendo") || igdb.contains("switch") || igdb.contains("game boy") ||
               igdb.contains("nes") || igdb.contains("snes") || igdb.contains("n64") ||
               igdb.contains("gamecube") || igdb.contains("wii") || igdb.contains("ds") {
                return true
            }
        }

        if user.contains("playstation") {
            if igdb.contains("playstation") || igdb.contains("ps1") || igdb.contains("ps2") ||
               igdb.contains("ps3") || igdb.contains("ps4") || igdb.contains("ps5") ||
               igdb.contains("psp") || igdb.contains("vita") {
                return true
            }
        }

        if user.contains("xbox") {
            if igdb.contains("xbox") {
                return true
            }
        }

        return false
    }

    /// Returnerar ett kompakt, snyggt plattformsnamn anpassat för kort och kompakta etiketter
    static func shortName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower.contains("windows") || lower == "pc (microsoft windows)" { return "PC" }
        if lower.contains("playstation 5") || lower == "ps5" { return "PS5" }
        if lower.contains("playstation 4") || lower == "ps4" { return "PS4" }
        if lower.contains("playstation 3") || lower == "ps3" { return "PS3" }
        if lower.contains("playstation 2") || lower == "ps2" { return "PS2" }
        if lower.contains("playstation") { return "PlayStation" }
        if lower.contains("series x") || lower.contains("series s") || lower.contains("xbox series") { return "XSX|S" }
        if lower.contains("xbox one") { return "Xbox One" }
        if lower.contains("xbox 360") { return "Xbox 360" }
        if lower == "xbox" { return "Xbox" }
        if lower.contains("switch") { return "Switch" }
        if lower.contains("mac") || lower.contains("macos") { return "Mac" }
        if lower.contains("ios") || lower.contains("iphone") || lower.contains("ipad") { return "iOS" }
        if lower.contains("android") { return "Android" }
        return trimmed
    }
}
