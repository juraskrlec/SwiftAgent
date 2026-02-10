//
//  ClaudeProviderTests.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import XCTest
@testable import SwiftAgent

final class ClaudeProviderTests: XCTestCase {
    func testBasicGeneration() async throws {
        // You'll need to set your API key
        let apiKey = ProcessInfo.processInfo.environment[""] ?? ""
        guard !apiKey.isEmpty else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let provider = ClaudeProvider(apiKey: apiKey)
        
        let messages = [
            Message.user("What is 2+2? Answer in one short sentence.")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: nil,
            options: .default
        )
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertNotNil(response.usage)
        print("Response: \(response.content)")
    }
}
