//
//  GameCollection.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-14.
//

import Foundation

struct GameCollection: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var description: String = ""
    var gameIDs: [UUID] = []
    var createdAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id, name, description, gameIDs, createdAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        gameIDs: [UUID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.gameIDs = gameIDs
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        gameIDs = try container.decodeIfPresent([UUID].self, forKey: .gameIDs) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(gameIDs, forKey: .gameIDs)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
