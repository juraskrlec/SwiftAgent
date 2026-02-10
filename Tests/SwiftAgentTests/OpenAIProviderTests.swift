//
//  OpenAIProviderTests.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import XCTest
@testable import SwiftAgent

final class OpenAIProviderTests: XCTestCase {
    
    // MARK: - Setup
    
    var apiKey: String!
    
    override func setUp() {
        super.setUp()
        apiKey = ""
    }
    
    override func tearDown() {
        apiKey = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testBasicGeneration() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        let provider = OpenAIProvider(apiKey: apiKey, model: .gpt51Mini)
        
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
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        let provider = OpenAIProvider(apiKey: apiKey, model: .gpt51Mini)
        
        let messages = [
            Message.user("What's the date 30 days from now?")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: [DateTimeTool()],
            options: .default
        )
        
        print("Response stop reason: \(response.stopReason)")
        print("Tool calls: \(response.toolCalls?.map { $0.name } ?? [])")
        
        XCTAssertNotNil(response.toolCalls, "Provider should return tool calls")
    }
    
    func testAgentWithOpenAI() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        let provider = OpenAIProvider(apiKey: apiKey, model: .gpt51Mini)
        
        let agent = Agent(
            name: "OpenAIAgent",
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
    
    func testStreaming() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        let provider = OpenAIProvider(apiKey: apiKey, model: .gpt51Mini)
        
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
                print("\n Done")
            default:
                break
            }
        }
        
        XCTAssertFalse(fullText.isEmpty)
    }
}
