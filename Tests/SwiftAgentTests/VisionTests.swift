//
//  VisionTests.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 27.02.2026..
//

import XCTest
@testable import SwiftAgent

final class VisionTests: XCTestCase {
    
    var openAIKey: String?
    var claudeKey: String?
    var geminiKey: String?
    
    override func setUp() async throws {
        try await super.setUp()
        
        openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        claudeKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        geminiKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"]

    }
    
    override func tearDown() async throws {
        try await super.tearDown()
    }
    
    // MARK: - OpenAI Vision Tests
    
    func testOpenAIRealImageDubrovnik() async throws {
        guard let apiKey = openAIKey, !apiKey.isEmpty else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        let imageData = try loadDubrovnikImage()
        let image = Message.ImageContent(
            data: imageData,
            mimeType: "image/webp"
        )
        
        let provider = OpenAIProvider(apiKey: apiKey, model: .defaultChatGPTModel)
        let agent = Agent(name: "OpenAI-VisionAgent", provider: provider)
        
        let result = try await agent.run(
            task: "Describe this image. What city is this? What are the main features?",
            images: [image]
        )
        
        print("\n[OPENAI VISION TEST] GPT-4o Response:")
        print(result.output)
        
        XCTAssertTrue(result.success)
        
        let output = result.output.lowercased()
        XCTAssertTrue(
            output.contains("dubrovnik") || output.contains("croatia") || output.contains("adriatic"),
            "Expected to recognize Dubrovnik or Croatia, got: \(result.output)"
        )
        
        XCTAssertTrue(
            output.contains("wall") || output.contains("fort") || output.contains("sea") || output.contains("coast"),
            "Expected to describe coastal/wall features"
        )
    }

    func testOpenAIRealImageDetailed() async throws {
        guard let apiKey = openAIKey, !apiKey.isEmpty else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        let imageData = try loadDubrovnikImage()
        let image = Message.ImageContent(
            data: imageData,
            mimeType: "image/webp",
            detail: .high
        )
        
        let provider = OpenAIProvider(apiKey: apiKey, model: .defaultChatGPTModel)
        let agent = Agent(name: "OpenAI-DetailedVision", provider: provider)
        
        let result = try await agent.run(
            task: """
            Analyze this image in detail and provide:
            1. Location/city name
            2. Main architectural features
            3. Natural features (water, landscape)
            4. Colors and atmosphere
            5. Any historical significance you can identify
            """,
            images: [image]
        )
        
        print("\n[OPENAI DETAILED ANALYSIS]")
        print(result.output)
        
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.output.count, 200, "Expected detailed response")
    }

    func testOpenAIRealImageStreaming() async throws {
        guard let apiKey = openAIKey, !apiKey.isEmpty else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        let imageData = try loadDubrovnikImage()
        let image = Message.ImageContent(data: imageData, mimeType: "image/webp")
        
        let provider = OpenAIProvider(apiKey: apiKey, model: .defaultChatGPTModel)
        let agent = Agent(name: "OpenAI-StreamVision", provider: provider)
        
        var output = ""
        var completed = false
        
        print("\n[OPENAI STREAMING VISION]")
        
        let stream = await agent.stream(
            task: "Describe this coastal city in detail.",
            images: [image]
        )
        
        for try await event in stream {
            switch event {
            case .thinking(let text):
                print(text, terminator: "")
                output += text
                
            case .completed(let result):
                print("\n")
                output = result.output
                completed = true
                
            case .error(let error):
                XCTFail("Stream error: \(error)")
                
            default:
                break
            }
        }
        
        XCTAssertTrue(completed)
        XCTAssertFalse(output.isEmpty)
        print("\n[OPENAI FINAL OUTPUT]")
        print(output)
    }
    
    // MARK: - Claude Vision Tests
    
    func testClaudeRealImageDubrovnik() async throws {
        guard let apiKey = claudeKey, !apiKey.isEmpty else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let imageData = try loadDubrovnikImage()
        let image = Message.ImageContent(
            data: imageData,
            mimeType: "image/webp"
        )
        
        let provider = ClaudeProvider(apiKey: apiKey, model: .sonnet)
        let agent = Agent(name: "Claude-VisionAgent", provider: provider)
        
        let result = try await agent.run(
            task: "Describe this image. What city is this? What are the main features?",
            images: [image]
        )
        
        print("\n[CLAUDE VISION TEST] Claude Sonnet Response:")
        print(result.output)
        
        XCTAssertTrue(result.success)
        
        let output = result.output.lowercased()
        XCTAssertTrue(
            output.contains("dubrovnik") || output.contains("croatia") || output.contains("adriatic"),
            "Expected to recognize Dubrovnik or Croatia, got: \(result.output)"
        )
        
        XCTAssertTrue(
            output.contains("wall") || output.contains("fort") || output.contains("sea") || output.contains("coast"),
            "Expected to describe coastal/wall features"
        )
    }
    
    func testClaudeRealImageDetailed() async throws {
        guard let apiKey = claudeKey, !apiKey.isEmpty else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let imageData = try loadDubrovnikImage()
        let image = Message.ImageContent(
            data: imageData,
            mimeType: "image/webp"
        )
        
        let provider = ClaudeProvider(apiKey: apiKey, model: .sonnet)
        let agent = Agent(name: "Claude-DetailedVision", provider: provider)
        
        let result = try await agent.run(
            task: """
            Analyze this image in detail and provide:
            1. Location/city name
            2. Main architectural features
            3. Natural features (water, landscape)
            4. Colors and atmosphere
            5. Any historical significance you can identify
            """,
            images: [image]
        )
        
        print("\n[CLAUDE DETAILED ANALYSIS]")
        print(result.output)
        
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.output.count, 200, "Expected detailed response")
    }
    
    func testClaudeRealImageWithTools() async throws {
        guard let apiKey = claudeKey, !apiKey.isEmpty else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let imageData = try loadDubrovnikImage()
        let image = Message.ImageContent(data: imageData, mimeType: "image/webp")
        
        let provider = ClaudeProvider(apiKey: apiKey, model: .sonnet)
        let agent = Agent(
            name: "Claude-VisionWithTools",
            provider: provider,
            tools: [DateTimeTool(), JSONParserTool()]
        )
        
        let result = try await agent.run(
            task: """
            1. Identify the city in this image
            2. Return the information as JSON with: city, country, features (array)
            """,
            images: [image]
        )
        
        print("\n[CLAUDE VISION + TOOLS]")
        print(result.output)
        
        XCTAssertTrue(result.success)
    }
    
    func testClaudeRealImageStreaming() async throws {
        guard let apiKey = claudeKey, !apiKey.isEmpty else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let imageData = try loadDubrovnikImage()
        let image = Message.ImageContent(data: imageData, mimeType: "image/webp")
        
        let provider = ClaudeProvider(apiKey: apiKey, model: .sonnet)
        let agent = Agent(name: "Claude-StreamVision", provider: provider)
        
        var output = ""
        var completed = false
        
        print("\n[CLAUDE STREAMING VISION]")
        
        let stream = await agent.stream(
            task: "Describe this coastal city in detail.",
            images: [image]
        )
        
        for try await event in stream {
            switch event {
            case .thinking(let text):
                print(text, terminator: "")
                output += text
                
            case .completed(let result):
                print("\n")
                output = result.output
                completed = true
                
            case .error(let error):
                XCTFail("Stream error: \(error)")
                
            default:
                break
            }
        }
        
        XCTAssertTrue(completed)
        XCTAssertFalse(output.isEmpty)
        print("\n[CLAUDE FINAL OUTPUT]")
        print(output)
    }
    
    // MARK: - Gemini Vision Tests
    
    func testGeminiRealImageDubrovnik() async throws {
        guard let apiKey = geminiKey, !apiKey.isEmpty else {
            throw XCTSkip("GOOGLE_API_KEY not set")
        }
        
        let imageData = try loadDubrovnikImage()
        let image = Message.ImageContent(
            data: imageData,
            mimeType: "image/webp"
        )
        
        let provider = GeminiProvider(apiKey: apiKey, model: .defaultGeminiModel)
        let agent = Agent(name: "Gemini-VisionAgent", provider: provider)
        
        let result = try await agent.run(
            task: "Describe this image. What city is this? What are the main features?",
            images: [image]
        )
        
        print("\n[GEMINI VISION TEST] Gemini 2.0 Flash Response:")
        print(result.output)
        
        XCTAssertTrue(result.success)
        
        let output = result.output.lowercased()
        XCTAssertTrue(
            output.contains("dubrovnik") || output.contains("croatia") || output.contains("adriatic"),
            "Expected to recognize Dubrovnik or Croatia, got: \(result.output)"
        )
        
        XCTAssertTrue(
            output.contains("wall") || output.contains("fort") || output.contains("sea") || output.contains("coast"),
            "Expected to describe coastal/wall features"
        )
    }
    
    func testGeminiRealImageDetailed() async throws {
        guard let apiKey = geminiKey, !apiKey.isEmpty else {
            throw XCTSkip("GOOGLE_API_KEY not set")
        }
        
        let imageData = try loadDubrovnikImage()
        let image = Message.ImageContent(
            data: imageData,
            mimeType: "image/webp"
        )
        
        let provider = GeminiProvider(apiKey: apiKey, model: .defaultGeminiModel)
        let agent = Agent(name: "Gemini-DetailedVision", provider: provider)
        
        let result = try await agent.run(
            task: """
            Analyze this image in detail and provide:
            1. Location/city name
            2. Main architectural features
            3. Natural features (water, landscape)
            4. Colors and atmosphere
            5. Any historical significance you can identify
            """,
            images: [image]
        )
        
        print("\n[GEMINI DETAILED ANALYSIS]")
        print(result.output)
        
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.output.count, 200, "Expected detailed response")
    }
    
    func testGeminiRealImageWithTools() async throws {
        guard let apiKey = geminiKey, !apiKey.isEmpty else {
            throw XCTSkip("GOOGLE_API_KEY not set")
        }
        
        let imageData = try loadDubrovnikImage()
        let image = Message.ImageContent(data: imageData, mimeType: "image/webp")
        
        let provider = GeminiProvider(apiKey: apiKey, model: .defaultGeminiModel)
        let agent = Agent(
            name: "Gemini-VisionWithTools",
            provider: provider,
            tools: [DateTimeTool(), JSONParserTool()]
        )
        
        let result = try await agent.run(
            task: """
            1. Identify the city in this image
            2. Return the information as JSON with: city, country, features (array)
            """,
            images: [image]
        )
        
        print("\n[GEMINI VISION + TOOLS]")
        print(result.output)
        
        XCTAssertTrue(result.success)
    }
    
    func testGeminiRealImageStreaming() async throws {
        guard let apiKey = geminiKey, !apiKey.isEmpty else {
            throw XCTSkip("GOOGLE_API_KEY not set")
        }
        
        let imageData = try loadDubrovnikImage()
        let image = Message.ImageContent(data: imageData, mimeType: "image/webp")
        
        let provider = GeminiProvider(apiKey: apiKey, model: .defaultGeminiModel)
        let agent = Agent(name: "Gemini-StreamVision", provider: provider)
        
        var output = ""
        var completed = false
        
        print("\n[GEMINI STREAMING VISION]")
        
        let stream = await agent.stream(
            task: "Describe this coastal city in detail.",
            images: [image]
        )
        
        for try await event in stream {
            switch event {
            case .thinking(let text):
                print(text, terminator: "")
                output += text
                
            case .completed(let result):
                print("\n")
                output = result.output
                completed = true
                
            case .error(let error):
                XCTFail("Stream error: \(error)")
                
            default:
                break
            }
        }
        
        XCTAssertTrue(completed)
        XCTAssertFalse(output.isEmpty)
        print("\n[GEMINI FINAL OUTPUT]")
        print(output)
    }

    // MARK: - Helper

    private func loadDubrovnikImage() throws -> Data {
        #if SWIFT_PACKAGE
        guard let imageURL = Bundle.module.url(forResource: "dubrovnik", withExtension: "webp") else {
            throw NSError(
                domain: "VisionTests",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Could not find dubrovnik.webp in Resources"]
            )
        }
        #else
        let testBundle = Bundle(for: type(of: self))
        guard let imageURL = testBundle.url(forResource: "dubrovnik", withExtension: "webp") else {
            throw NSError(
                domain: "VisionTests",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Could not find dubrovnik.webp in test bundle"]
            )
        }
        #endif
        
        return try Data(contentsOf: imageURL)
    }
}
