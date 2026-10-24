//
//  GameCollection.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import Foundation

struct GameCollection: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var name: String
    var emoji: String? = nil
    var description: String = ""
    var gameIDs: [UUID] = []
    var createdAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, description, gameIDs, createdAt
    }

    var displayEmoji: String {
        if let e = emoji, !e.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return e
        }
        if let first = name.first, first.unicodeScalars.first?.properties.isEmojiPresentation == true || (first.unicodeScalars.first?.value ?? 0) > 0x238C {
            return String(first)
        }
        let lower = name.lowercased()
        if lower.contains("favorit") || lower.contains("älsk") || lower.contains("bäst") { return "❤️" }
        if lower.contains("goty") || lower.contains("topp") || lower.contains("mästerverk") || lower.contains("10/10") { return "🏆" }
        if lower.contains("co-op") || lower.contains("coop") || lower.contains("vänner") || lower.contains("multi") { return "🤝" }
        if lower.contains("skräck") || lower.contains("horror") { return "👻" }
        if lower.contains("rpg") || lower.contains("rollspel") || lower.contains("fantasy") { return "⚔️" }
        if lower.contains("zelda") || lower.contains("nintendo") || lower.contains("switch") { return "🛡️" }
        if lower.contains("ps5") || lower.contains("playstation") { return "🎮" }
        if lower.contains("backlog") || lower.contains("att spela") || lower.contains("nästa") { return "📌" }
        if lower.contains("mys") || lower.contains("cozy") || lower.contains("indie") { return "✨" }
        if lower.contains("nostalgi") || lower.contains("klassiker") || lower.contains("retro") { return "🕹️" }
        return "🗂️"
    }

    var cleanName: String {
        if let first = name.first, first.unicodeScalars.first?.properties.isEmojiPresentation == true || (first.unicodeScalars.first?.value ?? 0) > 0x238C {
            return String(name.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return name
    }

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        emoji: String? = nil,
        description: String = "",
        gameIDs: [UUID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.description = description
        self.gameIDs = gameIDs
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        gameIDs = try container.decodeIfPresent([UUID].self, forKey: .gameIDs) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(emoji, forKey: .emoji)
        try container.encode(description, forKey: .description)
        try container.encode(gameIDs, forKey: .gameIDs)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
