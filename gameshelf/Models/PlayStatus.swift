//
//  PlayStatus.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI

enum PlayStatus: String, CaseIterable, Codable, Identifiable {
    case playing = "Spelar nu"
    case backlog = "Backlog"
    case paused = "Pausat"
    case completed = "Klar"
    case abandoned = "Avbrutet"
    case wishlist = "Önskelista"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .playing: return .green
        case .backlog: return .blue
        case .paused: return .orange
        case .completed: return .teal
        case .abandoned: return Color(.systemGray)
        case .wishlist: return .purple
        }
    }

    var icon: String {
        switch self {
        case .playing: return "play.fill"
        case .backlog: return "archivebox.fill"
        case .paused: return "pause.fill"
        case .completed: return "checkmark.seal.fill"
        case .abandoned: return "xmark.circle.fill"
        case .wishlist: return "heart.fill"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "playing", "spelar", "spelar nu", "inprogress", "in_progress", "pågående":
            self = .playing
        case "backlog", "unplayed", "ej spelat", "ej påbörjat":
            self = .backlog
        case "paused", "pausat":
            self = .paused
        case "completed", "klar", "hundredpercent", "100 %", "100%":
            self = .completed
        case "abandoned", "avbruten", "avbrutet", "droppat", "dropped":
            self = .abandoned
        case "wishlist", "önskelista":
            self = .wishlist
        default:
            self = .backlog
        }
    }
}
