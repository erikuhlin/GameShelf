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
    private let deviceUserKey = "device_user_uuid"
    private let urlSession: URLSession

    public var persistentUserId: UUID {
        if let sessionUser = currentUser, sessionUser.isLinkedWithRealEmail {
            return sessionUser.id
        }
        return ProfileManager.shared.activeProfileId
    }

    public func setExplicitUserId(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: deviceUserKey)
        if currentUser == nil || !(currentUser?.isLinkedWithRealEmail ?? false) {
            let updatedUser = SupabaseUser(id: id, email: nil, isAnonymous: true)
            self.currentUser = updatedUser
            let dummySession = SupabaseSession(
                accessToken: SupabaseConfig.anonKey,
                refreshToken: nil,
                user: updatedUser
            )
            saveSession(dummySession)
        }
    }

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
        UserDefaults.standard.set(session.user.id.uuidString, forKey: deviceUserKey)
        ProfileManager.shared.updateActiveProfile(linkedEmail: session.user.email)
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

    // MARK: - Sign Up (Skapa nytt konto)
    public func signUp(email: String, password: String, username: String? = nil) async throws {
        isLoading = true
        defer { isLoading = false }
        authError = nil

        guard let url = URL(string: "\(SupabaseConfig.baseURLString)/auth/v1/signup") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanUsername = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? (cleanEmail.components(separatedBy: "@").first ?? "Spelare")

        let body: [String: Any] = [
            "email": cleanEmail,
            "password": password,
            "data": [
                "is_anonymous": false,
                "username": cleanUsername
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpRes = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if (200...299).contains(httpRes.statusCode) {
            // Försök avkoda direkt session (om bekräftelse ej krävs)
            if let decoded = try? JSONDecoder().decode(SupabaseSession.self, from: data),
               !decoded.accessToken.isEmpty {
                saveSession(decoded)
                return
            }

            // Om Supabase skickade user-objekt utan session (e-postbekräftelse krävs)
            if let rawJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let idStr = rawJson["id"] as? String,
               let userId = UUID(uuidString: idStr) {
                let user = SupabaseUser(id: userId, email: cleanEmail, isAnonymous: false)
                let tempSession = SupabaseSession(accessToken: SupabaseConfig.anonKey, refreshToken: nil, user: user)
                saveSession(tempSession)
                return
            }

            // Fallback: prova direkt inloggning med samma uppgifter
            try await signIn(email: cleanEmail, password: password)
        } else {
            let errorJson = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            var errorMsg = errorJson["msg"] as? String ?? errorJson["message"] as? String ?? errorJson["error_description"] as? String ?? "Kunde inte skapa konto"

            if errorMsg.localizedCaseInsensitiveContains("already registered") {
                errorMsg = "Det finns redan ett konto med denna e-postadress. Välj 'Logga in' istället."
            } else if errorMsg.localizedCaseInsensitiveContains("password") {
                errorMsg = "Lösenordet är för svagt. Ange minst 6 tecken."
            }

            self.authError = errorMsg
            throw NSError(domain: "SupabaseAuth", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }

    // MARK: - Link Account (E-post & Lösenord)
    /// Länkar en e-post och ett lösenord till den aktuella användaren så att samma konto kan användas på webben
    public func linkAccount(email: String, password: String) async throws {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Om vi har en giltig användartoken som inte är default anonKey: prova PUT /auth/v1/user
        if let currentSession = session, currentSession.accessToken != SupabaseConfig.anonKey {
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
                "email": cleanEmail,
                "password": password,
                "data": [
                    "is_anonymous": false,
                    "username": cleanEmail.components(separatedBy: "@").first ?? "Spelare"
                ]
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            if let (data, response) = try? await urlSession.data(for: request),
               let httpRes = response as? HTTPURLResponse,
               (200...299).contains(httpRes.statusCode) {
                var updatedUser = currentSession.user
                updatedUser.email = cleanEmail
                updatedUser.isAnonymous = false
                let updatedSession = SupabaseSession(
                    accessToken: currentSession.accessToken,
                    refreshToken: currentSession.refreshToken,
                    user: updatedUser
                )
                saveSession(updatedSession)
                return
            }
        }

        // Standard: Registrera kontot via signUp
        try await signUp(email: cleanEmail, password: password)
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

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let body: [String: Any] = [
            "email": cleanEmail,
            "password": password
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            let errorJson = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            var errorMsg = errorJson["error_description"] as? String ?? errorJson["msg"] as? String ?? errorJson["message"] as? String ?? "Inloggning misslyckades"

            if errorMsg.localizedCaseInsensitiveContains("invalid login credentials") ||
               errorMsg.localizedCaseInsensitiveContains("invalid_grant") {
                errorMsg = "Felaktig e-postadress eller lösenord. Kontrollera dina uppgifter."
            } else if errorMsg.localizedCaseInsensitiveContains("email not confirmed") {
                errorMsg = "E-postadressen är inte bekräftad än. Kontrollera din inkorg."
            }

            self.authError = errorMsg
            throw NSError(domain: "SupabaseAuth", code: (response as? HTTPURLResponse)?.statusCode ?? 401, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        let decoded = try JSONDecoder().decode(SupabaseSession.self, from: data)
        saveSession(decoded)
    }

    // MARK: - Sign Out
    public func signOut() {
        clearSession()
        authError = nil
    }
}
