//
//  RefreshToken.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 15.02.2026..
//

import SwiftAgent
import Foundation

@main
struct RefreshToken {
    static func main() async throws {
        print("Google OAuth - Get Fresh Token")
        print(String(repeating: "=", count: 60))
        
        // Get credentials from environment or prompt
        let clientId = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? {
            print("\nEnter Client ID: ", terminator: "")
            fflush(stdout)
            return readLine() ?? ""
        }()
        
        let clientSecret = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"] ?? {
            print("\nEnter Client Secret: ", terminator: "")
            fflush(stdout)
            return readLine() ?? ""
        }()
        
        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            print("Client ID and Secret required")
            return
        }
        
        let oauth = GoogleOAuth2(
            clientId: clientId,
            clientSecret: clientSecret,
            redirectUri: "urn:ietf:wg:oauth:2.0:oob"
        )
        
        // Check if we have refresh token
        if let refreshToken = ProcessInfo.processInfo.environment["GOOGLE_REFRESH_TOKEN"], !refreshToken.isEmpty {
            print("\nUsing refresh token to get new access token...")
            
            do {
                let tokens = try await oauth.refreshToken(refreshToken: refreshToken)
                
                print("\nNew Access Token:")
                print(String(repeating: "=", count: 60))
                print(tokens.accessToken)
                print(String(repeating: "=", count: 60))
                print("\nExport:")
                print("export GOOGLE_ACCESS_TOKEN='\(tokens.accessToken)'")
                print("\nToken valid for ~1 hour")
                
            } catch {
                print("Refresh failed: \(error)")
                print("\nRefresh token might be invalid. Getting new auth code...")
                try await getNewToken(oauth: oauth)
            }
            
        } else {
            print("\nNo refresh token found. Need to authorize...")
            try await getNewToken(oauth: oauth)
        }
    }
    
    static func getNewToken(oauth: GoogleOAuth2) async throws {
        let authURL = oauth.getAuthorizationURL(
            scopes: ["https://www.googleapis.com/auth/calendar"]
        )
        
        print("\nOpen this URL in your browser:")
        print(String(repeating: "=", count: 60))
        print(authURL.absoluteString)
        print(String(repeating: "=", count: 60))
        
        print("\nPaste the authorization code: ", terminator: "")
        fflush(stdout)
        
        guard let code = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            print("No code provided")
            return
        }
        
        print("\nExchanging code for tokens...")
        
        let tokens = try await oauth.exchangeCodeForToken(code: code)
        
        print("\nSuccess!\n")
        print("ACCESS TOKEN:")
        print(String(repeating: "=", count: 60))
        print(tokens.accessToken)
        print(String(repeating: "=", count: 60))
        
        if let refreshToken = tokens.refreshToken {
            print("\nREFRESH TOKEN (save this!):")
            print(String(repeating: "=", count: 60))
            print(refreshToken)
            print(String(repeating: "=", count: 60))
        }
        
        print("\n📋 Export these:")
        print("export GOOGLE_ACCESS_TOKEN='\(tokens.accessToken)'")
        if let refreshToken = tokens.refreshToken {
            print("export GOOGLE_REFRESH_TOKEN='\(refreshToken)'")
        }
    }
}
