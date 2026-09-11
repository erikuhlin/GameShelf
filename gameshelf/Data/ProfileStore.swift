//
//  ProfileStore.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2025-09-08.
//


import Foundation
import Combine

final class ProfileStore: ObservableObject {
    public static let shared = ProfileStore()

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
        static let playingMood = "profile.playingMood"
        static let gamerBio = "profile.gamerBio"
        static let playstyle = "profile.playstyle"
        static let gotyByYear = "profile.gotyByYear"
    }

    static let defaultBirthdate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    static let defaultPlatforms: Set<String> = []
    static let defaultUsername = ""
    static let defaultAnnualGamingGoal = 0
    static let defaultFavoriteGenres: Set<String> = []
    static let defaultPlayFor: Set<String> = []
    static let defaultAvatarType = "initial"
    static let defaultPlayingMood = ""
    static let defaultGamerBio = ""
    static let defaultPlaystyle: Set<String> = []

    private var isUpdatingFromRemote = false

    private func currentKey(_ base: String, profileId: UUID? = nil) -> String {
        let pid = profileId ?? ProfileManager.shared.activeProfileId
        return "\(base)_\(pid.uuidString)"
    }

    @Published var username: String {
        didSet {
            if username != oldValue {
                UserDefaults.standard.set(username, forKey: currentKey(Keys.username))
                ProfileManager.shared.updateActiveProfile(name: username)
                syncToRemote()
            }
        }
    }

    @Published var avatarType: String {
        didSet {
            if avatarType != oldValue {
                UserDefaults.standard.set(avatarType, forKey: currentKey(Keys.avatarType))
                ProfileManager.shared.updateActiveProfile(avatarType: avatarType)
                syncToRemote()
            }
        }
    }

    @Published var avatarCustomImageData: Data? {
        didSet {
            UserDefaults.standard.set(avatarCustomImageData, forKey: currentKey(Keys.avatarCustomImageData))
            ProfileManager.shared.updateActiveProfile(customImageData: avatarCustomImageData)
            syncToRemote()
        }
    }

    @Published var age: Int {
        didSet {
            if age != oldValue {
                UserDefaults.standard.set(age, forKey: currentKey(Keys.age))
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
                UserDefaults.standard.set(birthdate, forKey: currentKey(Keys.birthdate))
            }
        }
    }

    @Published var annualGamingGoal: Int {
        didSet {
            if annualGamingGoal != oldValue {
                UserDefaults.standard.set(annualGamingGoal, forKey: currentKey(Keys.annualGamingGoal))
                syncToRemote()
            }
        }
    }

    @Published var platforms: Set<String> {
        didSet {
            if platforms != oldValue {
                UserDefaults.standard.set(Array(platforms), forKey: currentKey(Keys.platforms))
                syncToRemote()
            }
        }
    }

    @Published var favoriteGenres: Set<String> {
        didSet {
            if favoriteGenres != oldValue {
                UserDefaults.standard.set(Array(favoriteGenres), forKey: currentKey(Keys.favoriteGenres))
                syncToRemote()
            }
        }
    }

    @Published var playFor: Set<String> {
        didSet {
            if playFor != oldValue {
                UserDefaults.standard.set(Array(playFor), forKey: currentKey(Keys.playFor))
                syncToRemote()
            }
        }
    }

    @Published var favoriteGameIDs: [String] {
        didSet {
            if favoriteGameIDs != oldValue {
                UserDefaults.standard.set(favoriteGameIDs, forKey: currentKey(Keys.favoriteGameIDs))
                syncToRemote()
            }
        }
    }

    @Published var targetGameIDs: [String] {
        didSet {
            if targetGameIDs != oldValue {
                UserDefaults.standard.set(targetGameIDs, forKey: currentKey(Keys.targetGameIDs))
                syncToRemote()
            }
        }
    }

    @Published var playingMood: String {
        didSet {
            if playingMood != oldValue {
                UserDefaults.standard.set(playingMood, forKey: currentKey(Keys.playingMood))
                syncToRemote()
            }
        }
    }

    @Published var gamerBio: String {
        didSet {
            if gamerBio != oldValue {
                UserDefaults.standard.set(gamerBio, forKey: currentKey(Keys.gamerBio))
                syncToRemote()
            }
        }
    }

    @Published var playstyle: Set<String> {
        didSet {
            if playstyle != oldValue {
                UserDefaults.standard.set(Array(playstyle), forKey: currentKey(Keys.playstyle))
                syncToRemote()
            }
        }
    }

    @Published var gotyByYear: [String: String] {
        didSet {
            if gotyByYear != oldValue {
                UserDefaults.standard.set(gotyByYear, forKey: currentKey(Keys.gotyByYear))
                syncToRemote()
            }
        }
    }

    func setGoty(gameId: UUID?, forYear year: Int) {
        let yearKey = String(year)
        if let gameId = gameId {
            gotyByYear[yearKey] = gameId.uuidString
        } else {
            gotyByYear.removeValue(forKey: yearKey)
        }
    }

    func getGoty(forYear year: Int) -> UUID? {
        guard let idStr = gotyByYear[String(year)], let uuid = UUID(uuidString: idStr) else {
            return nil
        }
        return uuid
    }

    init() {
        self.username = Self.defaultUsername
        self.avatarType = Self.defaultAvatarType
        self.avatarCustomImageData = nil
        self.age = 25
        self.birthdate = Self.defaultBirthdate
        self.annualGamingGoal = Self.defaultAnnualGamingGoal
        self.platforms = Self.defaultPlatforms
        self.favoriteGenres = Self.defaultFavoriteGenres
        self.playFor = Self.defaultPlayFor
        self.favoriteGameIDs = []
        self.targetGameIDs = []
        self.playingMood = Self.defaultPlayingMood
        self.gamerBio = Self.defaultGamerBio
        self.playstyle = Self.defaultPlaystyle
        self.gotyByYear = [:]

        loadProfile(for: ProfileManager.shared.activeProfileId)

        // Hämta och synka profil mot Supabase i bakgrunden
        Task { [weak self] in
            await self?.syncWithRemote()
        }
    }

    public func loadProfile(for profileId: UUID) {
        isUpdatingFromRemote = true
        defer { isUpdatingFromRemote = false }

        let isPrimary = profileId == ProfileManager.shared.profiles.first?.id

        func stringVal(_ key: String, defaultVal: String) -> String {
            if let v = UserDefaults.standard.string(forKey: currentKey(key, profileId: profileId)) {
                return v
            }
            if isPrimary, let legacy = UserDefaults.standard.string(forKey: key), !legacy.isEmpty {
                return legacy
            }
            return defaultVal
        }

        func intVal(_ key: String, defaultVal: Int) -> Int {
            if UserDefaults.standard.object(forKey: currentKey(key, profileId: profileId)) != nil {
                return UserDefaults.standard.integer(forKey: currentKey(key, profileId: profileId))
            }
            if isPrimary, UserDefaults.standard.object(forKey: key) != nil {
                return UserDefaults.standard.integer(forKey: key)
            }
            return defaultVal
        }

        func arrayVal<T>(_ key: String, defaultVal: [T]) -> [T] {
            if let arr = UserDefaults.standard.array(forKey: currentKey(key, profileId: profileId)) as? [T] {
                return arr
            }
            if isPrimary, let legacy = UserDefaults.standard.array(forKey: key) as? [T] {
                return legacy
            }
            return defaultVal
        }

        self.username = stringVal(Keys.username, defaultVal: Self.defaultUsername)
        self.annualGamingGoal = intVal(Keys.annualGamingGoal, defaultVal: Self.defaultAnnualGamingGoal)
        self.age = intVal(Keys.age, defaultVal: 25)
        self.birthdate = Calendar.current.date(byAdding: .year, value: -self.age, to: Date()) ?? Self.defaultBirthdate
        self.platforms = Set(arrayVal(Keys.platforms, defaultVal: Array(Self.defaultPlatforms)))
        self.favoriteGenres = Set(arrayVal(Keys.favoriteGenres, defaultVal: Array(Self.defaultFavoriteGenres)))
        self.playFor = Set(arrayVal(Keys.playFor, defaultVal: Array(Self.defaultPlayFor)))
        self.favoriteGameIDs = arrayVal(Keys.favoriteGameIDs, defaultVal: [])
        self.targetGameIDs = arrayVal(Keys.targetGameIDs, defaultVal: [])
        self.avatarType = stringVal(Keys.avatarType, defaultVal: Self.defaultAvatarType)
        if let data = UserDefaults.standard.data(forKey: currentKey(Keys.avatarCustomImageData, profileId: profileId)) {
            self.avatarCustomImageData = data
        } else if isPrimary {
            self.avatarCustomImageData = UserDefaults.standard.data(forKey: Keys.avatarCustomImageData)
        } else {
            self.avatarCustomImageData = nil
        }
        self.playingMood = stringVal(Keys.playingMood, defaultVal: Self.defaultPlayingMood)
        self.gamerBio = stringVal(Keys.gamerBio, defaultVal: Self.defaultGamerBio)
        self.playstyle = Set(arrayVal(Keys.playstyle, defaultVal: Array(Self.defaultPlaystyle)))
        self.gotyByYear = UserDefaults.standard.dictionary(forKey: currentKey(Keys.gotyByYear, profileId: profileId)) as? [String: String] ?? [:]
    }

    public func importAndSyncProfile(userId: UUID) async {
        do {
            if let result = try await SupabaseSyncService.shared.fetchProfile(userId: userId) {
                await MainActor.run {
                    self.isUpdatingFromRemote = true
                    defer { self.isUpdatingFromRemote = false }
                    if let u = result.username, !u.isEmpty { self.username = u }
                    if let a = result.avatarUrl, !a.isEmpty { self.avatarType = a }
                    if let prefs = result.preferences {
                        if let age = prefs.age, age > 0 { self.age = age }
                        if let plats = prefs.platforms { self.platforms = Set(plats) }
                        if let genres = prefs.favoriteGenres { self.favoriteGenres = Set(genres) }
                        if let pf = prefs.playFor { self.playFor = Set(pf) }
                        if let favs = prefs.favoriteGameIDs { self.favoriteGameIDs = favs }
                        if let goal = prefs.annualGamingGoal, goal > 0 { self.annualGamingGoal = goal }
                        if let at = prefs.avatarType, !at.isEmpty { self.avatarType = at }
                        if let tg = prefs.targetGameIDs { self.targetGameIDs = tg }
                        if let mood = prefs.playingMood, !mood.isEmpty { self.playingMood = mood }
                        if let bio = prefs.gamerBio { self.gamerBio = bio }
                        if let ps = prefs.playstyle { self.playstyle = Set(ps) }
                        if let gy = prefs.gotyByYear { self.gotyByYear = gy }
                    }

                    UserDefaults.standard.set(self.username, forKey: currentKey(Keys.username, profileId: userId))
                    UserDefaults.standard.set(self.avatarType, forKey: currentKey(Keys.avatarType, profileId: userId))
                    UserDefaults.standard.set(self.age, forKey: currentKey(Keys.age, profileId: userId))
                    UserDefaults.standard.set(Array(self.platforms), forKey: currentKey(Keys.platforms, profileId: userId))
                    UserDefaults.standard.set(Array(self.favoriteGenres), forKey: currentKey(Keys.favoriteGenres, profileId: userId))
                    UserDefaults.standard.set(Array(self.playFor), forKey: currentKey(Keys.playFor, profileId: userId))
                    UserDefaults.standard.set(self.annualGamingGoal, forKey: currentKey(Keys.annualGamingGoal, profileId: userId))
                    UserDefaults.standard.set(self.targetGameIDs, forKey: currentKey(Keys.targetGameIDs, profileId: userId))
                    UserDefaults.standard.set(self.playingMood, forKey: currentKey(Keys.playingMood, profileId: userId))
                    UserDefaults.standard.set(self.gamerBio, forKey: currentKey(Keys.gamerBio, profileId: userId))
                    UserDefaults.standard.set(Array(self.playstyle), forKey: currentKey(Keys.playstyle, profileId: userId))
                    UserDefaults.standard.set(self.gotyByYear, forKey: currentKey(Keys.gotyByYear, profileId: userId))
                    ProfileManager.shared.updateActiveProfile(name: self.username, avatarType: self.avatarType)
                }
            }
        } catch {
            print("⚠️ Error importing profile: \(error)")
        }
    }

    public func switchToProfile(id: UUID) {
        ProfileManager.shared.setActiveProfile(id: id)
        loadProfile(for: id)
        Task { [weak self] in
            await self?.syncWithRemote()
        }
    }

    private func syncToRemote() {
        guard !isUpdatingFromRemote else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let userId = await MainActor.run { SupabaseAuthManager.shared.persistentUserId }
            let (uName, aType, aAge, pPlatforms, fGenres, pPlayFor, fGameIDs, gGoal, tGameIDs, pMood, gBio, pStyle, gGoty) = await MainActor.run {
                (self.username, self.avatarType, self.age, Array(self.platforms), Array(self.favoriteGenres), Array(self.playFor), self.favoriteGameIDs, self.annualGamingGoal, self.targetGameIDs, self.playingMood, self.gamerBio, Array(self.playstyle), self.gotyByYear)
            }
            let prefs = SupabaseSyncService.ProfilePreferencesData(
                age: aAge,
                platforms: pPlatforms,
                favoriteGenres: fGenres,
                playFor: pPlayFor,
                favoriteGameIDs: fGameIDs,
                annualGamingGoal: gGoal,
                avatarType: aType,
                targetGameIDs: tGameIDs,
                playingMood: pMood,
                gamerBio: gBio,
                playstyle: pStyle,
                gotyByYear: gGoty
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
                        if let goal = prefs.annualGamingGoal, goal > 0 {
                            self.annualGamingGoal = goal
                            UserDefaults.standard.set(goal, forKey: currentKey(Keys.annualGamingGoal, profileId: userId))
                        }
                        if let at = prefs.avatarType, !at.isEmpty { self.avatarType = at }
                        if let tg = prefs.targetGameIDs {
                            self.targetGameIDs = tg
                            UserDefaults.standard.set(tg, forKey: currentKey(Keys.targetGameIDs, profileId: userId))
                        }
                        if let mood = prefs.playingMood, !mood.isEmpty { self.playingMood = mood }
                        if let bio = prefs.gamerBio { self.gamerBio = bio }
                        if let ps = prefs.playstyle { self.playstyle = Set(ps) }
                        if let gy = prefs.gotyByYear {
                            self.gotyByYear = gy
                            UserDefaults.standard.set(gy, forKey: currentKey(Keys.gotyByYear, profileId: userId))
                        }
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

    func togglePlaystyle(_ style: String) {
        if playstyle.contains(style) {
            playstyle.remove(style)
        } else {
            playstyle.insert(style)
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
