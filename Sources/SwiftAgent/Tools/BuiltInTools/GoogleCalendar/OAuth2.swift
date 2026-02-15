//
//  OAuth2.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 15.02.2026..
//

import Foundation

/// Helper for Google OAuth2 authentication
public struct GoogleOAuth2 {
    private let clientId: String
    private let clientSecret: String
    private let redirectUri: String
    
    public init(clientId: String, clientSecret: String, redirectUri: String = "urn:ietf:wg:oauth:2.0:oob") {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectUri = redirectUri
    }
    
    /// Generate authorization URL for user to visit
    public func getAuthorizationURL(scopes: [String] = ["https://www.googleapis.com/auth/calendar"]) -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        return components.url!
    }
    
    /// Exchange authorization code for access token
    public func exchangeCodeForToken(code: String) async throws -> TokenResponse {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code"
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.authenticationFailed
        }
        
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
    
    /// Refresh access token using refresh token
    public func refreshToken(refreshToken: String) async throws -> TokenResponse {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GoogleCalendarError.authenticationFailed
        }
        
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
    
    public struct TokenResponse: Codable {
        public let accessToken: String
        public let refreshToken: String?
        public let expiresIn: Int
        public let scope: String
        public let tokenType: String
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case scope
            case tokenType = "token_type"
        }
    }
}
