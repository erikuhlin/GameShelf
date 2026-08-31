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
        static let age = "profile.age"
        static let platforms = "profile.platforms"
        static let username = "profile.username"
        static let annualGamingGoal = "profile.annualGamingGoal"
        static let favoriteGenres = "profile.favoriteGenres"
        static let playFor = "profile.playFor"
        static let favoriteGameIDs = "profile.favoriteGameIDs"
        static let avatarType = "profile.avatarType"
        static let avatarCustomImageData = "profile.avatarCustomImageData"
    }

    static let defaultBirthdate: Date = Calendar.current.date(byAdding: .year, value: -27, to: Date()) ?? Date()
    static let defaultPlatforms: Set<String> = ["PlayStation 5", "PC"]
    static let defaultUsername = "Erik"
    static let defaultAnnualGamingGoal = 12
    static let defaultFavoriteGenres: Set<String> = ["RPG", "Action", "Skräck"]
    static let defaultPlayFor: Set<String> = ["Story", "Utforskning"]
    static let defaultAvatarType = "initial"

    @Published var username: String {
        didSet { if username != oldValue { UserDefaults.standard.set(username, forKey: Keys.username) } }
    }

    @Published var avatarType: String {
        didSet { if avatarType != oldValue { UserDefaults.standard.set(avatarType, forKey: Keys.avatarType) } }
    }

    @Published var avatarCustomImageData: Data? {
        didSet { UserDefaults.standard.set(avatarCustomImageData, forKey: Keys.avatarCustomImageData) }
    }

    @Published var age: Int {
        didSet {
            if age != oldValue {
                UserDefaults.standard.set(age, forKey: Keys.age)
                // Uppdatera även birthdate approximativt
                if let newDate = Calendar.current.date(byAdding: .year, value: -age, to: Date()) {
                    self.birthdate = newDate
                }
            }
        }
    }

    @Published var birthdate: Date {
        didSet { if birthdate != oldValue { UserDefaults.standard.set(birthdate, forKey: Keys.birthdate) } }
    }

    @Published var annualGamingGoal: Int {
        didSet { if annualGamingGoal != oldValue { UserDefaults.standard.set(annualGamingGoal, forKey: Keys.annualGamingGoal) } }
    }

    @Published var platforms: Set<String> {
        didSet { if platforms != oldValue { UserDefaults.standard.set(Array(platforms), forKey: Keys.platforms) } }
    }

    @Published var favoriteGenres: Set<String> {
        didSet { if favoriteGenres != oldValue { UserDefaults.standard.set(Array(favoriteGenres), forKey: Keys.favoriteGenres) } }
    }

    @Published var playFor: Set<String> {
        didSet { if playFor != oldValue { UserDefaults.standard.set(Array(playFor), forKey: Keys.playFor) } }
    }

    @Published var favoriteGameIDs: [String] {
        didSet { if favoriteGameIDs != oldValue { UserDefaults.standard.set(favoriteGameIDs, forKey: Keys.favoriteGameIDs) } }
    }

    init() {
        let savedName = UserDefaults.standard.string(forKey: Keys.username)
        self.username = (savedName != nil && !savedName!.isEmpty) ? savedName! : Self.defaultUsername

        let savedGoal = UserDefaults.standard.integer(forKey: Keys.annualGamingGoal)
        self.annualGamingGoal = savedGoal == 0 ? Self.defaultAnnualGamingGoal : savedGoal

        let savedDate = UserDefaults.standard.object(forKey: Keys.birthdate) as? Date ?? Self.defaultBirthdate
        self.birthdate = savedDate

        let savedAge = UserDefaults.standard.integer(forKey: Keys.age)
        if savedAge > 0 {
            self.age = savedAge
        } else {
            let calculated = Calendar.current.dateComponents([.year], from: savedDate, to: Date()).year ?? 27
            self.age = calculated > 0 ? calculated : 27
        }

        if let arr = UserDefaults.standard.array(forKey: Keys.platforms) as? [String] {
            self.platforms = Set(arr)
        } else {
            self.platforms = Self.defaultPlatforms
        }

        if let arr = UserDefaults.standard.array(forKey: Keys.favoriteGenres) as? [String] {
            self.favoriteGenres = Set(arr)
        } else {
            self.favoriteGenres = Self.defaultFavoriteGenres
        }

        if let arr = UserDefaults.standard.array(forKey: Keys.playFor) as? [String] {
            self.playFor = Set(arr)
        } else {
            self.playFor = Self.defaultPlayFor
        }

        if let arr = UserDefaults.standard.array(forKey: Keys.favoriteGameIDs) as? [String] {
            self.favoriteGameIDs = arr
        } else {
            self.favoriteGameIDs = []
        }

        self.avatarType = UserDefaults.standard.string(forKey: Keys.avatarType) ?? Self.defaultAvatarType
        self.avatarCustomImageData = UserDefaults.standard.data(forKey: Keys.avatarCustomImageData)
    }

    func toggle(_ platform: String) {
        if platforms.contains(platform) { platforms.remove(platform) } else { platforms.insert(platform) }
    }

    func toggleGenre(_ genre: String) {
        if favoriteGenres.contains(genre) {
            favoriteGenres.remove(genre)
        } else {
            favoriteGenres.insert(genre)
        }
    }

    func togglePlayFor(_ motive: String) {
        if playFor.contains(motive) {
            playFor.remove(motive)
        } else {
            playFor.insert(motive)
        }
    }

    func addFavoriteGame(id: String) {
        guard !favoriteGameIDs.contains(id) else { return }
        guard favoriteGameIDs.count < 10 else { return }
        favoriteGameIDs.append(id)
    }

    func removeFavoriteGame(id: String) {
        favoriteGameIDs.removeAll { $0 == id }
    }
}
