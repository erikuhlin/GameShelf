//
//  PlayStatus.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2025-08-25.
//

import SwiftUI

// MARK: - Game Play Type
enum GamePlayType: String, CaseIterable, Codable, Identifiable, Sendable {
    case singlePlayer = "singlePlayer"
    case multiplayer = "multiplayer"
    case coOp = "coOp"
    case ongoing = "ongoing"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singlePlayer: return "Singleplayer"
        case .multiplayer: return "Multiplayer"
        case .coOp: return "Co-op"
        case .ongoing: return "Ongoing / Live Service"
        }
    }

    var icon: String {
        switch self {
        case .singlePlayer: return "person.fill"
        case .multiplayer: return "person.3.fill"
        case .coOp: return "person.2.fill"
        case .ongoing: return "bolt.shield.fill"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "singleplayer", "single_player", "single-player", "solo":
            self = .singlePlayer
        case "multiplayer", "multi_player", "multi-player", "pvp":
            self = .multiplayer
        case "coop", "co_op", "co-op", "co-operative", "cooperative":
            self = .coOp
        case "ongoing", "live_service", "liveservice", "live-service", "mmo", "online":
            self = .ongoing
        default:
            self = .singlePlayer
        }
    }
}

// MARK: - Play Priority (Next Up)
enum PlayPriority: String, CaseIterable, Codable, Identifiable, Sendable {
    case none = "none"
    case low = "low"
    case normal = "normal"
    case high = "high"
    case nextUp = "nextUp"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Ingen prioritet"
        case .low: return "Låg prioritet"
        case .normal: return "Normal prioritet"
        case .high: return "Hög prioritet"
        case .nextUp: return "Nästa upp"
        }
    }

    var icon: String {
        switch self {
        case .none: return "minus"
        case .low: return "arrow.down"
        case .normal: return "arrow.right"
        case .high: return "flame.fill"
        case .nextUp: return "pin.fill"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "low", "låg":
            self = .low
        case "normal":
            self = .normal
        case "high", "hög":
            self = .high
        case "nextup", "next_up", "nästa upp", "nästaupp":
            self = .nextUp
        default:
            self = .none
        }
    }
}

// MARK: - User Play Status
enum PlayStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case notStarted = "notStarted"
    case playing = "playing"
    case paused = "paused"
    case completed = "completed"
    case abandoned = "abandoned"

    var id: String { rawValue }

    // Standard / Singleplayer display text
    var defaultTitle: String {
        title(isMultiplayerOrOngoing: false)
    }

    // Dynamic title based on play types
    func title(for playTypes: [GamePlayType]) -> String {
        let isMulti = playTypes.contains(.multiplayer) || playTypes.contains(.ongoing)
        return title(isMultiplayerOrOngoing: isMulti)
    }

    func title(isMultiplayerOrOngoing: Bool) -> String {
        if isMultiplayerOrOngoing {
            switch self {
            case .notStarted: return "Inte spelat"
            case .playing: return "Aktiv"
            case .paused: return "Tar paus"
            case .completed: return "Inte aktiv längre"
            case .abandoned: return "Slutat spela"
            }
        } else {
            switch self {
            case .notStarted: return "Inte påbörjat"
            case .playing: return "Spelar nu"
            case .paused: return "Pausat"
            case .completed: return "Genomspelat"
            case .abandoned: return "Avbrutet"
            }
        }
    }

    // Dynamic icon based on play types
    func icon(for playTypes: [GamePlayType]) -> String {
        let isMulti = playTypes.contains(.multiplayer) || playTypes.contains(.ongoing)
        return icon(isMultiplayerOrOngoing: isMulti)
    }

    func icon(isMultiplayerOrOngoing: Bool) -> String {
        if isMultiplayerOrOngoing {
            switch self {
            case .notStarted: return "circle"
            case .playing: return "circle.fill"
            case .paused: return "pause.fill"
            case .completed: return "circle.slash"
            case .abandoned: return "xmark.circle.fill"
            }
        } else {
            switch self {
            case .notStarted: return "circle"
            case .playing: return "play.fill"
            case .paused: return "pause.fill"
            case .completed: return "checkmark.seal.fill"
            case .abandoned: return "xmark.circle.fill"
            }
        }
    }

    // Default icon
    var defaultIcon: String {
        icon(isMultiplayerOrOngoing: false)
    }

    // Color theme
    var color: Color {
        switch self {
        case .notStarted: return Color(.systemGray)
        case .playing: return .green
        case .paused: return .orange
        case .completed: return .teal
        case .abandoned: return Color(.systemGray2)
        }
    }

    // Robust decoding supporting legacy strings
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        switch value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "notstarted", "not_started", "ej påbörjat", "ej spelat", "inte påbörjat", "inte spelat", "unplayed":
            self = .notStarted
        case "playing", "spelar", "spelar nu", "inprogress", "in_progress", "pågående", "aktiv":
            self = .playing
        case "paused", "pausat", "paus", "tar paus":
            self = .paused
        case "completed", "klar", "klart", "genomspelat", "inte aktiv längre", "hundredpercent", "100 %", "100%":
            self = .completed
        case "abandoned", "avbruten", "avbrutet", "droppat", "dropped", "slutat spela":
            self = .abandoned
        case "backlog":
            self = .notStarted
        case "wishlist", "önskelista":
            self = .notStarted
        default:
            self = .notStarted
        }
    }
}
