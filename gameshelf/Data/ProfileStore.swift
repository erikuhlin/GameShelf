//
//  ProfileStore.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-08.
//


import Foundation
import Combine

final class ProfileStore: ObservableObject {
    private enum Keys {
        static let birthdate = "profile.birthdate"
        static let platforms = "profile.platforms"
    }

    static let defaultBirthdate: Date = Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()
    static let defaultPlatforms: Set<String> = ["Nintendo Switch", "PlayStation 5"]

    @Published var birthdate: Date {
        didSet { if birthdate != oldValue { UserDefaults.standard.set(birthdate, forKey: Keys.birthdate) } }
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthdate, to: Date()).year ?? 0
    }

    @Published var platforms: Set<String> {
        didSet { if platforms != oldValue { UserDefaults.standard.set(Array(platforms), forKey: Keys.platforms) } }
    }

    init() {
        if let saved = UserDefaults.standard.object(forKey: Keys.birthdate) as? Date {
            self.birthdate = saved
        } else {
            self.birthdate = Self.defaultBirthdate
        }
        if let arr = UserDefaults.standard.array(forKey: Keys.platforms) as? [String] {
            self.platforms = Set(arr)
        } else {
            self.platforms = Self.defaultPlatforms
        }
    }

    func toggle(_ platform: String) {
        if platforms.contains(platform) { platforms.remove(platform) } else { platforms.insert(platform) }
    }
}
