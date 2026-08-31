//
//  SupabasePairingService.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-27.
//

import Foundation

public actor SupabasePairingService {
    public static let shared = SupabasePairingService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    /// Godkänner en parkopplingskod från webbläsaren och överför användarens session
    public func approvePairing(code: String, username: String? = nil) async throws {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanCode.isEmpty else {
            throw NSError(domain: "PairingError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ange en giltig parkopplingskod."])
        }

        guard let baseURL = URL(string: SupabaseConfig.baseURLString) else {
            throw URLError(.badURL)
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/pairing_sessions"), resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "code", value: "eq.\(cleanCode)")
        ]

        guard let fullURL = components?.url else {
            throw URLError(.badURL)
        }

        let currentUserId = await MainActor.run { SupabaseAuthManager.shared.persistentUserId }
        let currentEmail = await MainActor.run { SupabaseAuthManager.shared.currentUser?.email }
        let currentToken = await MainActor.run { SupabaseAuthManager.shared.session?.accessToken }

        let (storedName, aType, aAge, pPlatforms, fGenres, pPlayFor, fGameIDs, gGoal) = await MainActor.run {
            let store = ProfileStore()
            return (store.username, store.avatarType, store.age, Array(store.platforms), Array(store.favoriteGenres), Array(store.playFor), store.favoriteGameIDs, store.annualGamingGoal)
        }

        let effectiveUsername = (username != nil && !username!.isEmpty) ? username! : storedName
        let prefs = SupabaseSyncService.ProfilePreferencesData(
            age: aAge,
            platforms: pPlatforms,
            favoriteGenres: fGenres,
            playFor: pPlayFor,
            favoriteGameIDs: fGameIDs,
            annualGamingGoal: gGoal,
            avatarType: aType
        )

        try? await SupabaseSyncService.shared.upsertProfile(
            userId: currentUserId,
            username: effectiveUsername,
            avatarUrl: aType,
            preferences: prefs
        )

        let payload: [String: Any] = [
            "status": "approved",
            "user_id": currentUserId.uuidString,
            "session_data": [
                "email": currentEmail ?? "guest@gameshelf.local",
                "username": effectiveUsername,
                "token": currentToken ?? SupabaseConfig.anonKey
            ]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: fullURL)
        request.httpMethod = "PATCH"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200...299).contains(httpRes.statusCode) {
            let errorText = String(data: data, encoding: .utf8) ?? "Kunde inte godkänna parkoppling"
            throw NSError(domain: "PairingError", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
        }
    }
}
