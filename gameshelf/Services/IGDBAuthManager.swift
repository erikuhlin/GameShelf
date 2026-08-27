//
//  Untitled.swift
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-12.
//

import Foundation

actor IGDBAuthManager {
    static let shared = IGDBAuthManager()
    
    private var accessToken: String?
    private var tokenExpirationDate: Date?
    
    private init() {}
    
    func getValidToken() async throws -> String {
        // Återanvänd token om den fortfarande är giltig (med 1 minuts marginal)
        if let token = accessToken,
           let expiration = tokenExpirationDate,
           expiration > Date().addingTimeInterval(60) {
            return token
        }
        
        return try await fetchNewToken()
    }
    
    private func fetchNewToken() async throws -> String {
        guard let url = URL(string: "https://id.twitch.tv/oauth2/token") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyComponents = [
            "client_id=\(IGDBAuthConfig.clientID)",
            "client_secret=\(IGDBAuthConfig.clientSecret)",
            "grant_type=client_credentials"
        ]
        request.httpBody = bodyComponents.joined(separator: "&").data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let tokenResponse = try JSONDecoder().decode(TwitchTokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.accessToken
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        return tokenResponse.accessToken
    }
}

private struct TwitchTokenResponse: Decodable, Sendable {
    let accessToken: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}
