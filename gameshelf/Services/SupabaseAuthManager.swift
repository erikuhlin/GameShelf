//
//  SupabaseAuthManager.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-27.
//

import Foundation
import Combine

public struct SupabaseUser: Codable, Identifiable {
    public var id: UUID
    public var email: String?
    public var isAnonymous: Bool
    public var createdAt: String?

    public var isLinkedWithRealEmail: Bool {
        guard let email = email, !email.isEmpty else { return false }
        return !isAnonymous && !email.hasPrefix("anon_")
    }

    enum CodingKeys: String, CodingKey {
        case id, email, isAnonymous = "is_anonymous", createdAt = "created_at"
    }

    public init(id: UUID, email: String? = nil, isAnonymous: Bool = true, createdAt: String? = nil) {
        self.id = id
        self.email = email
        self.isAnonymous = isAnonymous
        self.createdAt = createdAt
    }
}

public struct SupabaseSession: Codable {
    public var accessToken: String
    public var refreshToken: String?
    public var user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

@MainActor
public final class SupabaseAuthManager: ObservableObject {
    public static let shared = SupabaseAuthManager()

    @Published public private(set) var currentUser: SupabaseUser?
    @Published public private(set) var session: SupabaseSession?
    @Published public private(set) var isLoading: Bool = false
    @Published public var authError: String?

    private let sessionStorageKey = "supabase_user_session"
    private let urlSession: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.urlSession = URLSession(configuration: config)

        loadPersistedSession()
    }

    // MARK: - Persistence
    private func loadPersistedSession() {
        if let data = UserDefaults.standard.data(forKey: sessionStorageKey),
           let saved = try? JSONDecoder().decode(SupabaseSession.self, from: data) {
            self.session = saved
            self.currentUser = saved.user
        }
    }

    private func saveSession(_ session: SupabaseSession) {
        self.session = session
        self.currentUser = session.user
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionStorageKey)
        }
    }

    public func clearSession() {
        self.session = nil
        self.currentUser = nil
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
    }

    // MARK: - Auto Anonymous Sign-In
    /// Säkerställer att användaren är inloggad (anonymt om inget konto finns)
    public func ensureAnonymousAuth() async {
        if currentUser != nil { return }

        isLoading = true
        defer { isLoading = false }

        // Försök registrera en anonym session via Supabase Auth API
        guard let url = URL(string: "\(SupabaseConfig.baseURLString)/auth/v1/signup") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Generera ett unikt anonymt id / e-post för lokal dev
        let anonymousUUID = UUID()
        let anonymousEmail = "anon_\(anonymousUUID.uuidString.prefix(8).lowercased())@gameshelf.local"
        let randomPassword = UUID().uuidString + "Aa1!"

        let body: [String: Any] = [
            "email": anonymousEmail,
            "password": randomPassword,
            "data": [
                "is_anonymous": true,
                "username": "Gäst-\(anonymousUUID.uuidString.prefix(4))"
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = httpBody

        do {
            let (data, response) = try await urlSession.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                if let decoded = try? JSONDecoder().decode(SupabaseSession.self, from: data) {
                    saveSession(decoded)
                    return
                }
            }

            // Fallback för helt lokal simulation utan nätverk
            let fallbackUser = SupabaseUser(id: anonymousUUID, email: nil, isAnonymous: true)
            let fallbackSession = SupabaseSession(accessToken: SupabaseConfig.anonKey, refreshToken: nil, user: fallbackUser)
            saveSession(fallbackSession)
        } catch {
            let fallbackUser = SupabaseUser(id: anonymousUUID, email: nil, isAnonymous: true)
            let fallbackSession = SupabaseSession(accessToken: SupabaseConfig.anonKey, refreshToken: nil, user: fallbackUser)
            saveSession(fallbackSession)
        }
    }

    // MARK: - Link Account (E-post & Lösenord)
    /// Länkar en e-post och ett lösenord till den aktuella användaren så att samma konto kan användas på webben
    public func linkAccount(email: String, password: String) async throws {
        guard let currentSession = session else {
            throw URLError(.userAuthenticationRequired)
        }

        isLoading = true
        defer { isLoading = false }
        authError = nil

        guard let url = URL(string: "\(SupabaseConfig.baseURLString)/auth/v1/user") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(currentSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": email,
            "password": password,
            "data": [
                "is_anonymous": false,
                "username": email.components(separatedBy: "@").first ?? "Spelare"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpRes = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if (200...299).contains(httpRes.statusCode) {
            var updatedUser = currentSession.user
            updatedUser.email = email
            updatedUser.isAnonymous = false
            let updatedSession = SupabaseSession(
                accessToken: currentSession.accessToken,
                refreshToken: currentSession.refreshToken,
                user: updatedUser
            )
            saveSession(updatedSession)
        } else {
            let errorText = String(data: data, encoding: .utf8) ?? "Kunde inte länka kontot"
            self.authError = errorText
            throw NSError(domain: "SupabaseAuth", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
        }
    }

    // MARK: - Sign In Existing User
    public func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        authError = nil

        guard let url = URL(string: "\(SupabaseConfig.baseURLString)/auth/v1/token?grant_type=password") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": email,
            "password": password
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Inloggning misslyckades"
            self.authError = errorText
            throw NSError(domain: "SupabaseAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: errorText])
        }

        let decoded = try JSONDecoder().decode(SupabaseSession.self, from: data)
        saveSession(decoded)
    }
}
