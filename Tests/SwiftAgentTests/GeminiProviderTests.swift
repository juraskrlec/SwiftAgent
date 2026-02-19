//
//  GeminiProviderTests.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import XCTest
@testable import SwiftAgent

final class GeminiProviderTests: XCTestCase {
    
    var apiKey: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        guard let apiKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"],
              !apiKey.isEmpty else {
            throw XCTSkip("GOOGLE_API_KEY not set")
        }

        self.apiKey = apiKey
    }
    
    override func tearDown() async throws {
        apiKey = nil
        try await super.tearDown()
    }
    
    func testBasicGeneration() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("GOOGLE_API_KEY not set")
        }
        
        let provider = GeminiProvider(apiKey: apiKey, model: .gemini25Flash)
        
        let messages = [
            Message.user("What is 2+2? Answer in one short sentence.")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: nil,
            options: .default
        )
        
        XCTAssertFalse(response.content.isEmpty)
        print("Response: \(response.content)")
    }
    
    func testWithTools() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("GOOGLE_API_KEY not set")
        }
        
        let provider = GeminiProvider(apiKey: apiKey, model: .gemini25Flash)
        
        let messages = [
            Message.user("What's the date 30 days from now?")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: [DateTimeTool()],
            options: .default
        )
        
        print("Stop reason: \(response.stopReason)")
        print("Tool calls: \(response.toolCalls?.map { $0.name } ?? [])")
        
        XCTAssertNotNil(response.toolCalls)
    }
    
    func testStreaming() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("GOOGLE_API_KEY not set")
        }
        
        let provider = GeminiProvider(apiKey: apiKey, model: .gemini25Flash)
        
        let stream = try await provider.stream(
            messages: [Message.user("Count to 3")],
            tools: nil,
            options: .default
        )
        
        var fullText = ""
        
        for try await chunk in stream {
            switch chunk.type {
            case .content(let text):
                fullText += text
                print(text, terminator: "")
            case .done:
                print("\n✅ Done")
            default:
                break
            }
        }
        
        XCTAssertFalse(fullText.isEmpty)
    }
    
    func testAgentWithGemini() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("GOOGLE_API_KEY not set")
        }
        
        let provider = GeminiProvider(apiKey: apiKey, model: .gemini25Flash)
        
        let agent = Agent(
            name: "GeminiAgent",
            provider: provider,
            systemPrompt: "You are a helpful assistant.",
            tools: [DateTimeTool()],
            maxIterations: 5
        )
        
        let result = try await agent.run(task: "What's the date 7 days from now?")
        
        print("Agent result: \(result.output)")
        
        XCTAssertTrue(result.success)
        XCTAssertFalse(result.output.isEmpty)
    }
    
    func testGeminiAgentWithCalendar() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("GOOGLE_API_KEY not set")
        }
        
        let provider = GeminiProvider(apiKey: apiKey, model: .gemini3Flash)
        let token = "<TOKEN>"
        
        let agent = Agent(
            name: "CalendarAgent",
            provider: provider,
            systemPrompt: "You are a calendar assistant. Use google_calendar_tool to check schedules.",
            tools: [DateTimeTool(), GoogleCalendarTool(accessToken: token)],
            maxIterations: 10
        )
        
        let result = try await agent.run(task: "What's on my schedule today?")
        
        print("\nFinal answer:")
        print(result.output)
        print("\nIterations: \(result.state.iterations)")
        print("Messages: \(result.state.messages.count)")
        
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.state.iterations, 0, "Should have used tools")
    }
}
