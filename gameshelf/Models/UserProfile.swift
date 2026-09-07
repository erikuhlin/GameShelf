//
//  UserProfile.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-09-06.
//

import Foundation
import SwiftUI
import Combine

public struct UserProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var avatarType: String
    public var avatarCustomImageData: Data?
    public var isPrimary: Bool
    public var linkedEmail: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        avatarType: String = "initial",
        avatarCustomImageData: Data? = nil,
        isPrimary: Bool = false,
        linkedEmail: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.avatarType = avatarType
        self.avatarCustomImageData = avatarCustomImageData
        self.isPrimary = isPrimary
        self.linkedEmail = linkedEmail
        self.createdAt = createdAt
    }
}

@MainActor
public final class ProfileManager: ObservableObject {
    public static let shared = ProfileManager()

    private enum Keys {
        static let profilesList = "profile_manager_profiles_list"
        static let activeProfileId = "profile_manager_active_profile_id"
        static let legacyMigrationDone = "profile_manager_legacy_migration_done"
    }

    @Published public private(set) var profiles: [UserProfile] = []
    @Published public private(set) var activeProfileId: UUID

    public var activeProfile: UserProfile {
        if let found = profiles.first(where: { $0.id == activeProfileId }) {
            return found
        }
        if let first = profiles.first {
            return first
        }
        let fallback = UserProfile(name: "Spelare 1", isPrimary: true)
        return fallback
    }

    private init() {
        let savedActiveIdString = UserDefaults.standard.string(forKey: Keys.activeProfileId)
        let savedActiveId = savedActiveIdString.flatMap { UUID(uuidString: $0) }

        if let data = UserDefaults.standard.data(forKey: Keys.profilesList),
           let list = try? JSONDecoder().decode([UserProfile].self, from: data),
           !list.isEmpty {
            self.profiles = list
            self.activeProfileId = savedActiveId ?? list[0].id
        } else {
            // Migrera befintlig installation (Zero Data Loss)
            let existingDeviceId = UserDefaults.standard.string(forKey: "device_user_uuid").flatMap { UUID(uuidString: $0) } ?? UUID()
            let existingName = UserDefaults.standard.string(forKey: "profile.username") ?? "Erik"
            let existingAvatar = UserDefaults.standard.string(forKey: "profile.avatarType") ?? "initial"
            let existingImageData = UserDefaults.standard.data(forKey: "profile.avatarCustomImageData")

            let initialProfile = UserProfile(
                id: existingDeviceId,
                name: existingName.isEmpty ? "Spelare 1" : existingName,
                avatarType: existingAvatar,
                avatarCustomImageData: existingImageData,
                isPrimary: true
            )

            self.profiles = [initialProfile]
            self.activeProfileId = initialProfile.id
            saveProfiles()
            UserDefaults.standard.set(initialProfile.id.uuidString, forKey: Keys.activeProfileId)
        }
    }

    public func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: Keys.profilesList)
        }
        UserDefaults.standard.set(activeProfileId.uuidString, forKey: Keys.activeProfileId)
    }

    public func addProfile(name: String, avatarType: String = "initial", customImageData: Data? = nil, id: UUID = UUID(), linkedEmail: String? = nil) -> UserProfile {
        let newProfile = UserProfile(
            id: id,
            name: name,
            avatarType: avatarType,
            avatarCustomImageData: customImageData,
            isPrimary: profiles.isEmpty,
            linkedEmail: linkedEmail
        )
        profiles.append(newProfile)
        saveProfiles()
        return newProfile
    }

    public func updateActiveProfile(name: String? = nil, avatarType: String? = nil, customImageData: Data? = nil, linkedEmail: String? = nil) {
        guard let idx = profiles.firstIndex(where: { $0.id == activeProfileId }) else { return }
        var updated = profiles[idx]
        if let name = name { updated.name = name }
        if let avatarType = avatarType { updated.avatarType = avatarType }
        if customImageData != nil { updated.avatarCustomImageData = customImageData }
        if let linkedEmail = linkedEmail { updated.linkedEmail = linkedEmail }
        profiles[idx] = updated
        saveProfiles()
    }

    public func setActiveProfile(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileId = id
        saveProfiles()
    }

    public func deleteProfile(id: UUID) {
        guard profiles.count > 1 else { return } // Behåll minst 1 profil
        profiles.removeAll(where: { $0.id == id })
        if activeProfileId == id {
            activeProfileId = profiles.first?.id ?? UUID()
        }
        saveProfiles()
    }
}
