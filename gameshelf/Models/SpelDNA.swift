//
//  SpelDNA.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-31.
//

import SwiftUI

enum SpelDNAArchetypeID: String, CaseIterable, Identifiable, Sendable {
    case storyDrivenExplorer = "story_driven_explorer"
    case rpgCompletionist = "rpg_completionist"
    case indieConnoisseur = "indie_connoisseur"
    case cozyAdventurer = "cozy_adventurer"
    case tacticalOperator = "tactical_operator"
    case hardcoreChallenger = "hardcore_challenger"
    case grandStrategist = "grand_strategist"
    case retroArchivist = "retro_archivist"
    case squadStrategist = "squad_strategist"
    case casualCollector = "casual_collector"
    case genreNomad = "genre_nomad"

    var id: String { rawValue }
}

struct SpelDNAProfile: Identifiable, Sendable {
    let archetypeID: SpelDNAArchetypeID
    let title: String
    let description: String
    let icon: String
    let accentHex: String
    let supportingStats: [String]

    var id: String { archetypeID.rawValue }

    var accentColor: Color {
        Color(hex: accentHex)
    }

    var glowColor: Color {
        accentColor.opacity(0.35)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexClean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 75, 75)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
