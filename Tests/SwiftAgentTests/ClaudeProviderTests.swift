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
        apiKey = "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"
        
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
}
