//
//  OAuthHelper.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 15.02.2026..
//

import SwiftAgent
import Foundation

@main
struct OAuthHelper {
    static func main() async throws {
        guard let clientId = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"],
              let clientSecret = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"] else {
            print("Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET")
            return
        }
        
        let oauth = GoogleOAuth2(clientId: clientId, clientSecret: clientSecret)
        let authURL = oauth.getAuthorizationURL()
        
        print("Visit this URL:")
        print(authURL.absoluteString)
        print("\nPaste code: ", terminator: "")
        
        guard let code = readLine() else { return }
        
        let token = try await oauth.exchangeCodeForToken(code: code)
        print("\nexport GOOGLE_ACCESS_TOKEN='\(token.accessToken)'")
        if let refresh = token.refreshToken {
            print("export GOOGLE_REFRESH_TOKEN='\(refresh)'")
        }
    }
}
