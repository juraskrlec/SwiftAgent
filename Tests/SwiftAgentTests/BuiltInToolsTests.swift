//
//  BuiltInToolsTests.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import XCTest
@testable import SwiftAgent

final class BuiltInToolsTests: XCTestCase {
    
    // MARK: - DateTime Tool Tests
    
    func testDateTimeNow() async throws {
        let tool = DateTimeTool()
        let result = try await tool.execute(arguments: ["operation": "now"])
        XCTAssertFalse(result.isEmpty)
        print("Current time: \(result)")
    }
    
    func testDateTimeAdd() async throws {
        let tool = DateTimeTool()
        let result = try await tool.execute(arguments: [
            "operation": "add",
            "amount": 5,
            "unit": "days"
        ])
        XCTAssertFalse(result.isEmpty)
        print("5 days from now: \(result)")
    }
    
    // MARK: - JSON Parser Tool Tests
    
    func testJSONParse() async throws {
        let tool = JSONParserTool()
        let json = """
        {
            "name": "John",
            "age": 30,
            "city": "New York"
        }
        """
        
        let result = try await tool.execute(arguments: [
            "operation": "parse",
            "json": json
        ])
        XCTAssertTrue(result.contains("Successfully parsed"))
    }
    
    func testJSONExtract() async throws {
        let tool = JSONParserTool()
        let json = """
        {
            "user": {
                "profile": {
                    "name": "Alice"
                }
            }
        }
        """
        
        let result = try await tool.execute(arguments: [
            "operation": "extract",
            "json": json,
            "key_path": "user.profile.name"
        ])
        XCTAssertEqual(result, "Alice")
    }
    
    // MARK: - File System Tool Tests
    
    func testFileSystemWriteRead() async throws {
        let tempDir = FileManager.default.temporaryDirectory.path
        let tool = FileSystemTool(allowedPaths: [tempDir])
        let testPath = "\(tempDir)/test_file.txt"
        
        // Write
        let writeResult = try await tool.execute(arguments: [
            "operation": "write",
            "path": testPath,
            "content": "Hello, World!"
        ])
        XCTAssertTrue(writeResult.contains("Successfully wrote"))
        
        // Read
        let readResult = try await tool.execute(arguments: [
            "operation": "read",
            "path": testPath
        ])
        XCTAssertEqual(readResult, "Hello, World!")
        
        // Delete
        _ = try await tool.execute(arguments: [
            "operation": "delete",
            "path": testPath
        ])
    }
    
    // MARK: - HTTP Request Tool Tests
    
    func testHTTPGet() async throws {
        let tool = HTTPRequestTool()
        
        let result = try await tool.execute(arguments: [
            "method": "GET",
            "url": "https://api.github.com/zen"
        ])
        
        XCTAssertTrue(result.contains("Status: 200"))
        print("GitHub Zen: \(result)")
    }
    
    // MARK: - Agent with Tools Integration Test
    
    func testAgentWithMultipleTools() async throws {
        let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        guard !apiKey.isEmpty else {
            throw XCTSkip("ANTHROPIC_API_KEY not set")
        }
        
        let provider = ClaudeProvider(apiKey: apiKey, model: .haiku)
        
        let agent = Agent(
            name: "MultiToolAgent",
            provider: provider,
            systemPrompt: "You are a helpful assistant with access to various tools.",
            tools: [
                DateTimeTool(),
                JSONParserTool()
            ],
            maxIterations: 10
        )
        
        let result = try await agent.run(
            task: "What day will it be 30 days from now?"
        )
        
        print("Agent result: \(result.output)")
        print("Iterations used: \(result.state.iterations)")
        XCTAssertTrue(result.success)
    }
}
