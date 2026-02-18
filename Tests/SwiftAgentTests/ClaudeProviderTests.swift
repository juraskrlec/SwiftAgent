//
//  ClaudeProviderTests.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import XCTest
@testable import SwiftAgent

final class ClaudeProviderTests: XCTestCase {
    
    // MARK: - Setup
    
    var apiKey: String!
    
    override func setUp() {
        super.setUp()
        
        // Get API key from environment variable
        apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        
        // Skip all tests if API key is not set
        guard apiKey != nil && !apiKey.isEmpty else {
            return
        }
    }
    
    override func tearDown() {
        apiKey = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testBasicGeneration() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let provider = ClaudeProvider(apiKey: apiKey, model: .haiku)
        
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
    
    func testStreamingGeneration() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let provider = ClaudeProvider(apiKey: apiKey, model: .haiku)
        
        let messages = [
            Message.user("Count to 3. Just the numbers.")
        ]
        
        let stream = try await provider.stream(
            messages: messages,
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
    
    func testWithTools() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let provider = ClaudeProvider(apiKey: apiKey, model: .haiku)
        
        let messages = [
            Message.user("What's the date 30 days from now?")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: [DateTimeTool()],
            options: .default
        )
        
        print("Response content: '\(response.content)'")
        print("Stop reason: \(response.stopReason)")
        print("Tool calls: \(response.toolCalls?.map { $0.name } ?? [])")
        
        // Assert that we got EITHER content OR tool calls
        let hasContent = !response.content.isEmpty
        let hasToolCalls = response.toolCalls != nil && !response.toolCalls!.isEmpty
        
        XCTAssertTrue(
            hasContent || hasToolCalls,
            "Response should have either text content or tool calls"
        )
        
        // If tool calls, verify stop reason
        if hasToolCalls {
            XCTAssertEqual(response.stopReason, .toolUse, "Stop reason should be toolUse when tools are called")
        }
    }
    
    func testAgentWithClaude() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let provider = ClaudeProvider(apiKey: apiKey, model: .haiku)
        
        let agent = Agent(
            name: "TestAgent",
            provider: provider,
            systemPrompt: "You are a helpful assistant.",
            tools: [DateTimeTool()],
            maxIterations: 5
        )
        
        let result = try await agent.run(task: "What's the date 7 days from now?")
        
        print("Agent result: \(result.output)")
        print("Iterations: \(result.state.iterations)")
        
        XCTAssertTrue(result.success)
        XCTAssertFalse(result.output.isEmpty)
    }
    
    func testMultipleModels() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let models: [ClaudeProvider.Model] = [.haiku, .sonnet, .opus]
        
        for model in models {
            let provider = ClaudeProvider(apiKey: apiKey, model: model)
            
            let messages = [
                Message.user("Say hi in one word.")
            ]
            
            let response = try await provider.generate(
                messages: messages,
                tools: nil,
                options: .default
            )
            
            print("\(model.rawValue): \(response.content)")
            XCTAssertFalse(response.content.isEmpty)
        }
    }
    
    func testClaudeToolCalling() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
              let token = ProcessInfo.processInfo.environment["GOOGLE_ACCESS_TOKEN"] else {
            throw XCTSkip("Missing keys")
        }
        
        let provider = ClaudeProvider(apiKey: apiKey, model: .sonnet)
        
        let response = try await provider.generate(
            messages: [
                .system("You have a google_calendar_tool. When asked about calendars, USE IT. Don't explain - just call it with action='list_calendars'."),
                .user("Use the google_calendar_tool with action list_calendars")
            ],
            tools: [GoogleCalendarTool(accessToken: token)],
            options: .default
        )
        
        print("Content: \(response.content)")
        print("Tool calls: \(response.toolCalls?.count ?? 0)")
        
        XCTAssertNotNil(response.toolCalls, "Should call tool")
        XCTAssertEqual(response.toolCalls?.first?.name, "google_calendar_tool")
    }
    
    func testClaudeNonStreaming() async throws {
        
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
              let token = ProcessInfo.processInfo.environment["GOOGLE_ACCESS_TOKEN"] else {
            throw XCTSkip("Missing keys")
        }
        
        let provider = ClaudeProvider(apiKey: apiKey, model: .sonnet)
        
        let response = try await provider.generate(
            messages: [
                .system("You must use the google_calendar_tool when asked about schedules."),
                .user("What's on my schedule tomorrow?")
            ],
            tools: [GoogleCalendarTool(accessToken: token)],
            options: .default
        )
        
        print("Content: \(response.content)")
        print("Tool calls: \(response.toolCalls?.count ?? 0)")
        
        if let toolCalls = response.toolCalls {
            for tc in toolCalls {
                print("  - \(tc.name)")
                print("    args: \(tc.arguments)")
            }
        }
        
        XCTAssertNotNil(response.toolCalls)
    }
    
    func testClaudeAgentWithCalendar() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
              let token = ProcessInfo.processInfo.environment["GOOGLE_ACCESS_TOKEN"] else {
            throw XCTSkip("Missing keys")
        }
        
        let provider = ClaudeProvider(apiKey: apiKey, model: .sonnet)
        
        let agent = Agent(
            name: "CalendarAgent",
            provider: provider,
            systemPrompt: "You are a calendar assistant. Use google_calendar_tool to check schedules.",
            tools: [DateTimeTool(), GoogleCalendarTool(accessToken: token)],
            maxIterations: 10
        )
        
        let result = try await agent.run(task: "What's on my schedule tomorrow?")
        
        print("\nFinal answer:")
        print(result.output)
        print("\nIterations: \(result.state.iterations)")
        print("Messages: \(result.state.messages.count)")
        
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.state.iterations, 0, "Should have used tools")
    }
}


