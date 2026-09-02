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
        static let targetGameIDs = "profile.targetGameIDs"
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

    private var isUpdatingFromRemote = false

    @Published var username: String {
        didSet {
            if username != oldValue {
                UserDefaults.standard.set(username, forKey: Keys.username)
                syncToRemote()
            }
        }
    }

    @Published var avatarType: String {
        didSet {
            if avatarType != oldValue {
                UserDefaults.standard.set(avatarType, forKey: Keys.avatarType)
                syncToRemote()
            }
        }
    }

    @Published var avatarCustomImageData: Data? {
        didSet {
            UserDefaults.standard.set(avatarCustomImageData, forKey: Keys.avatarCustomImageData)
            syncToRemote()
        }
    }

    @Published var age: Int {
        didSet {
            if age != oldValue {
                UserDefaults.standard.set(age, forKey: Keys.age)
                if let newDate = Calendar.current.date(byAdding: .year, value: -age, to: Date()) {
                    self.birthdate = newDate
                }
                syncToRemote()
            }
        }
    }

    @Published var birthdate: Date {
        didSet {
            if birthdate != oldValue {
                UserDefaults.standard.set(birthdate, forKey: Keys.birthdate)
            }
        }
    }

    @Published var annualGamingGoal: Int {
        didSet {
            if annualGamingGoal != oldValue {
                UserDefaults.standard.set(annualGamingGoal, forKey: Keys.annualGamingGoal)
                syncToRemote()
            }
        }
    }

    @Published var platforms: Set<String> {
        didSet {
            if platforms != oldValue {
                UserDefaults.standard.set(Array(platforms), forKey: Keys.platforms)
                syncToRemote()
            }
        }
    }

    @Published var favoriteGenres: Set<String> {
        didSet {
            if favoriteGenres != oldValue {
                UserDefaults.standard.set(Array(favoriteGenres), forKey: Keys.favoriteGenres)
                syncToRemote()
            }
        }
    }

    @Published var playFor: Set<String> {
        didSet {
            if playFor != oldValue {
                UserDefaults.standard.set(Array(playFor), forKey: Keys.playFor)
                syncToRemote()
            }
        }
    }

    @Published var favoriteGameIDs: [String] {
        didSet {
            if favoriteGameIDs != oldValue {
                UserDefaults.standard.set(favoriteGameIDs, forKey: Keys.favoriteGameIDs)
                syncToRemote()
            }
        }
    }

    @Published var targetGameIDs: [String] {
        didSet {
            if targetGameIDs != oldValue {
                UserDefaults.standard.set(targetGameIDs, forKey: Keys.targetGameIDs)
                syncToRemote()
            }
        }
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

        if let arr = UserDefaults.standard.array(forKey: Keys.targetGameIDs) as? [String] {
            self.targetGameIDs = arr
        } else {
            self.targetGameIDs = []
        }

        self.avatarType = UserDefaults.standard.string(forKey: Keys.avatarType) ?? Self.defaultAvatarType
        self.avatarCustomImageData = UserDefaults.standard.data(forKey: Keys.avatarCustomImageData)

        // Hämta och synka profil mot Supabase i bakgrunden
        Task { [weak self] in
            await self?.syncWithRemote()
        }
    }

    private func syncToRemote() {
        guard !isUpdatingFromRemote else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let userId = await MainActor.run { SupabaseAuthManager.shared.persistentUserId }
            let (uName, aType, aAge, pPlatforms, fGenres, pPlayFor, fGameIDs, gGoal, tGameIDs) = await MainActor.run {
                (self.username, self.avatarType, self.age, Array(self.platforms), Array(self.favoriteGenres), Array(self.playFor), self.favoriteGameIDs, self.annualGamingGoal, self.targetGameIDs)
            }
            let prefs = SupabaseSyncService.ProfilePreferencesData(
                age: aAge,
                platforms: pPlatforms,
                favoriteGenres: fGenres,
                playFor: pPlayFor,
                favoriteGameIDs: fGameIDs,
                annualGamingGoal: gGoal,
                avatarType: aType,
                targetGameIDs: tGameIDs
            )
            try? await SupabaseSyncService.shared.upsertProfile(
                userId: userId,
                username: uName,
                avatarUrl: aType,
                preferences: prefs
            )
        }
    }

    func syncWithRemote() async {
        let userId = await MainActor.run { SupabaseAuthManager.shared.persistentUserId }
        do {
            if let result = try await SupabaseSyncService.shared.fetchProfile(userId: userId) {
                await MainActor.run {
                    self.isUpdatingFromRemote = true
                    defer { self.isUpdatingFromRemote = false }
                    if let u = result.username, !u.isEmpty {
                        self.username = u
                    }
                    if let a = result.avatarUrl, !a.isEmpty {
                        self.avatarType = a
                    }
                    if let prefs = result.preferences {
                        if let age = prefs.age, age > 0 { self.age = age }
                        if let plats = prefs.platforms { self.platforms = Set(plats) }
                        if let genres = prefs.favoriteGenres { self.favoriteGenres = Set(genres) }
                        if let pf = prefs.playFor { self.playFor = Set(pf) }
                        if let favs = prefs.favoriteGameIDs { self.favoriteGameIDs = favs }
                        if let goal = prefs.annualGamingGoal, goal > 0 { self.annualGamingGoal = goal }
                        if let at = prefs.avatarType, !at.isEmpty { self.avatarType = at }
                        if let tg = prefs.targetGameIDs { self.targetGameIDs = tg }
                    }
                }
            } else {
                syncToRemote()
            }
        } catch {
            print("⚠️ ProfileStore syncWithRemote error: \(error)")
        }
    }

    func isTargetGoal(gameID: UUID) -> Bool {
        let str = gameID.uuidString.lowercased()
        return targetGameIDs.contains(where: { $0.lowercased() == str })
    }

    func toggleTargetGoal(gameID: UUID) {
        let str = gameID.uuidString.lowercased()
        if let idx = targetGameIDs.firstIndex(where: { $0.lowercased() == str }) {
            targetGameIDs.remove(at: idx)
        } else {
            // Begränsa till max 3 aktiva fokusmål
            if targetGameIDs.count >= 3 {
                targetGameIDs.removeFirst()
            }
            targetGameIDs.append(str)
        }
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
        let lower = id.lowercased()
        guard !favoriteGameIDs.contains(where: { $0.lowercased() == lower }) else { return }
        guard favoriteGameIDs.count < 10 else { return }
        favoriteGameIDs.append(id)
    }

    func removeFavoriteGame(id: String) {
        let lower = id.lowercased()
        favoriteGameIDs.removeAll { $0.lowercased() == lower }
    }
}
