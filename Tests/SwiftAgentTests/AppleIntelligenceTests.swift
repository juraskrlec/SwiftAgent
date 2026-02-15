//
//  AppleIntelligenceTests.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import XCTest
@testable import SwiftAgent

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
final class AppleIntelligenceTests: XCTestCase {
    
    // MARK: - Basic Generation Tests
    
    func testAppleIntelligenceBasicGeneration() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let messages = [
            Message.user("What is 2 + 2? Answer in one short sentence.")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: nil,
            options: .default
        )
        
        XCTAssertFalse(response.content.isEmpty, "Response should not be empty")
        print("Basic response: \(response.content)")
    }
    
    func testAppleIntelligenceWithSystemPrompt() async throws {
        let provider = try await AppleIntelligenceProvider(
            instructions: "You are a helpful assistant. Always be concise and clear."
        )
        
        let messages = [
            Message.user("Tell me a short fact about Swift programming.")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: nil,
            options: .default
        )
        
        XCTAssertFalse(response.content.isEmpty)
        print("System prompt response: \(response.content)")
    }
    
    func testAppleIntelligenceMultiTurnConversation() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let messages = [
            Message.user("Hi, what's your name?"),
            Message.assistant("I'm an AI assistant."),
            Message.user("Can you help me with dates?")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: nil,
            options: .default
        )
        
        XCTAssertFalse(response.content.isEmpty)
        print("Multi-turn response: \(response.content)")
    }
    
    // MARK: - DateTime Tool Tests
    
    func testAppleIntelligenceWithDateTimeTool() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let messages = [
            Message.user("What day will it be 30 days from now?")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: [DateTimeTool()],
            options: .default
        )
        
        XCTAssertFalse(response.content.isEmpty)
        print("DateTime tool response: \(response.content)")
    }
    
    func testAppleIntelligenceCurrentDate() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let messages = [
            Message.user("What is today's date?")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: [DateTimeTool()],
            options: .default
        )
        
        XCTAssertFalse(response.content.isEmpty)
        print("Current date response: \(response.content)")
    }
    
    func testAppleIntelligenceMultipleDateCalculations() async throws {
        let provider = try await AppleIntelligenceProvider(
            instructions: "You are a helpful assistant. Use tools when needed to provide accurate answers."
        )
        
        let messages = [
            Message.user("What date is it 7 days from now? And what about 30 days from now?")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: [DateTimeTool()],
            options: .default
        )
        
        print("Multiple date calculations response: \(response.content)")
        XCTAssertFalse(response.content.isEmpty)
    }
    
    func testAppleIntelligenceSubtractDays() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let messages = [
            Message.user("What was the date 10 days ago?")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: [DateTimeTool()],
            options: .default
        )
        
        XCTAssertFalse(response.content.isEmpty)
        print("Subtract days response: \(response.content)")
    }
    
    func testAppleIntelligenceWithJSONTool() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let jsonString = """
        {
            "user": {
                "name": "Alice",
                "age": 30,
                "city": "New York"
            }
        }
        """
        
        let messages = [
            Message.user("Parse this JSON and tell me the user's name: \(jsonString)")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: [JSONParserTool()],
            options: .default
        )
        
        XCTAssertFalse(response.content.isEmpty)
        print("JSON parser tool response: \(response.content)")
        
        XCTAssertTrue(
            response.content.lowercased().contains("alice"),
            "Response should contain the parsed name"
        )
    }
    
    func testAppleIntelligenceWithFileSystemTool() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let tempDir = FileManager.default.temporaryDirectory.path
        
        let messages = [
            Message.user("List the files in the directory: \(tempDir)")
        ]
        
        let response = try await provider.generate(
            messages: messages,
            tools: [FileSystemTool(allowedPaths: [tempDir])],
            options: .default
        )
        
        XCTAssertFalse(response.content.isEmpty)
        print("FileSystem tool response: \(response.content)")
    }
    
    // MARK: - Streaming Tests
    
    func testAppleIntelligenceStreaming() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let messages = [
            Message.user("Tell me a short fact about Swift programming language.")
        ]
        
        let stream = try await provider.stream(
            messages: messages,
            tools: nil,
            options: .default
        )
        
        var fullText = ""
        var chunkCount = 0
        
        for try await chunk in stream {
            switch chunk.type {
            case .content(let text):
                fullText += text
                chunkCount += 1
                print(text, terminator: "")
            case .done:
                print("\nStream complete")
            default:
                break
            }
        }
        
        XCTAssertFalse(fullText.isEmpty, "Streamed text should not be empty")
        XCTAssertGreaterThan(chunkCount, 0, "Should receive at least one chunk")
        print("Received \(chunkCount) chunks, total length: \(fullText.count)")
    }
    
    func testAppleIntelligenceStreamingWithTools() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let messages = [
            Message.user("What's the date 14 days from now? Explain.")
        ]
        
        let stream = try await provider.stream(
            messages: messages,
            tools: [DateTimeTool()],
            options: .default
        )
        
        var fullText = ""
        
        for try await chunk in stream {
            switch chunk.type {
            case .content(let text):
                fullText += text
                print(text, terminator: "")
            case .done:
                print("\nStream with tools complete")
            default:
                break
            }
        }
        
        XCTAssertFalse(fullText.isEmpty)
        print("Streamed response with tools: \(fullText)")
    }
    
    // MARK: - Agent Integration Tests
    
    func testAppleIntelligenceAgent() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let agent = Agent(
            name: "DateAgent",
            provider: provider,
            systemPrompt: "You are a helpful date assistant. Use the datetime tool when needed.",
            tools: [DateTimeTool()],
            maxIterations: 5
        )
        
        let result = try await agent.run(task: "What's the date 45 days from now?")
        
        print("Agent result: \(result.output)")
        print("   Iterations: \(result.state.iterations)")
        
        XCTAssertTrue(result.success)
        XCTAssertFalse(result.output.isEmpty)
    }
    
    func testAppleIntelligenceAgentMultipleTools() async throws {
        let provider = try await AppleIntelligenceProvider(
            instructions: "You are a helpful assistant with access to various tools."
        )
        
        let agent = Agent(
            name: "MultiToolAgent",
            provider: provider,
            tools: [
                DateTimeTool(),
                JSONParserTool()
            ],
            maxIterations: 10
        )
        
        let result = try await agent.run(
            task: "What day will it be 30 days from now?"
        )
        
        print("Multi-tool agent result: \(result.output)")
        print("   Iterations: \(result.state.iterations)")
        
        XCTAssertTrue(result.success)
        XCTAssertFalse(result.output.isEmpty)
    }
    
    func testAppleIntelligenceAgentStreaming() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let agent = Agent(
            name: "StreamingAgent",
            provider: provider,
            systemPrompt: "You are a helpful assistant.",
            tools: [DateTimeTool()]
        )
        
        let stream = await agent.stream(task: "What's the date 7 days from now and explain what day of the week it will be?")
        
        var eventCount = 0
        
        for try await event in stream {
            eventCount += 1
            switch event {
            case .thinking(let text):
                print("💭 ", terminator: "")
                print(text, terminator: "")
            case .toolCall(let call):
                print("\n🔧 Tool call: \(call.name)")
            case .toolResult(let result, _):
                print("Tool result: \(result)")
            case .response(let text):
                print("📝 Response: \(text)")
            case .completed(let result):
                print("\n🎉 Completed! Output: \(result.output)")
            case .error(let error):
                print("❌ Error: \(error)")
            }
        }
        
        print("Received \(eventCount) events")
        XCTAssertGreaterThan(eventCount, 0)
    }
    
    // MARK: - Graph Integration Tests
    
    func testAppleIntelligenceGraph() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let researcher = Agent(
            name: "Researcher",
            provider: provider,
            systemPrompt: "You are a researcher. Research the given topic briefly.",
            tools: [],
            maxIterations: 3
        )
        
        let writer = Agent(
            name: "Writer",
            provider: provider,
            systemPrompt: "You are a writer. Take research and write a brief summary.",
            tools: [],
            maxIterations: 3
        )
        
        let graph = AgentGraph()
        await graph.addNode("research", agent: researcher)
        await graph.addNode("write", agent: writer)
        await graph.addEdge(from: .START, to: "research")
        await graph.addEdge(from: "research", to: "write")
        await graph.addEdge(from: "write", to: .END)
        
        var initialState = GraphState()
        initialState.addMessage(.user("Research and write about Swift concurrency"))
        
        let result = try await graph.invoke(input: initialState)
        
        print("Graph result:")
        print("   Messages: \(result.messages.count)")
        print("   Visited nodes: \(result.visitedNodes)")
        
        XCTAssertTrue(result.visitedNodes.contains("research"))
        XCTAssertTrue(result.visitedNodes.contains("write"))
        XCTAssertGreaterThan(result.messages.count, 1)
    }
    
    func testAppleIntelligenceGraphWithTools() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let dateChecker = Agent(
            name: "DateChecker",
            provider: provider,
            systemPrompt: "You check dates using the datetime tool.",
            tools: [DateTimeTool()],
            maxIterations: 3
        )
        
        let reporter = Agent(
            name: "Reporter",
            provider: provider,
            systemPrompt: "You create reports from date information.",
            tools: [],
            maxIterations: 3
        )
        
        let graph = AgentGraph()
        await graph.addNode("checkDate", agent: dateChecker)
        await graph.addNode("report", agent: reporter)
        await graph.addEdge(from: .START, to: "checkDate")
        await graph.addEdge(from: "checkDate", to: "report")
        await graph.addEdge(from: "report", to: .END)
        
        var initialState = GraphState()
        initialState.addMessage(.user("What's the date 60 days from now and create a brief report"))
        
        let result = try await graph.invoke(input: initialState)
        
        print("Graph with tools result:")
        print("   Visited: \(result.visitedNodes)")
        
        XCTAssertEqual(result.visitedNodes, ["checkDate", "report"])
    }
    
    func testAppleIntelligenceConditionalGraph() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let classifier = Agent(
            name: "Classifier",
            provider: provider,
            systemPrompt: "Classify if the user wants date calculation or current date. Reply with just 'calculate' or 'current'.",
            tools: [],
            maxIterations: 2
        )
        
        let graph = AgentGraph()
        await graph.addNode("classify", agent: classifier)
        
        await graph.addNode("handle_calculate") { state in
            var newState = state
            newState.setValue(.string("User wants date calculation"), forKey: "result")
            return newState
        }
        
        await graph.addNode("handle_current") { state in
            var newState = state
            newState.setValue(.string("User wants current date"), forKey: "result")
            return newState
        }
        
        await graph.addEdge(from: .START, to: "classify")
        
        await graph.addConditionalEdge(from: "classify") { state in
            if let lastMessage = state.messages.last(where: { $0.role == .assistant }) {
                return lastMessage.content.lowercased().contains("calculate") ? "handle_calculate" : "handle_current"
            }
            return "handle_current"
        }
        
        await graph.addEdge(from: "handle_calculate", to: .END)
        await graph.addEdge(from: "handle_current", to: .END)
        
        var state = GraphState()
        state.addMessage(.user("What date is it 30 days from now?"))
        
        let result = try await graph.invoke(input: state)
        
        print("Conditional graph result: \(result.getValue(forKey: "result")?.stringValue ?? "none")")
        print("   Visited: \(result.visitedNodes)")
    }
    
    // MARK: - Error Handling Tests
    
    func testAppleIntelligenceEmptyMessage() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let messages = [
            Message.user("")
        ]
        
        // Should handle empty messages gracefully
        let response = try await provider.generate(
            messages: messages,
            tools: nil,
            options: .default
        )
        
        // Should still return something (even if it's a polite refusal)
        XCTAssertNotNil(response.content)
        print("Empty message handled: \(response.content)")
    }
    
    func testAppleIntelligenceWithInvalidToolArguments() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let agent = Agent(
            name: "TestAgent",
            provider: provider,
            tools: [DateTimeTool()],
            maxIterations: 5
        )
        
        // Ask for something that might cause invalid tool arguments
        let result = try await agent.run(task: "Add banana days to the date")
        
        // Should handle gracefully without crashing
        XCTAssertNotNil(result.output)
        print("Invalid tool args handled: \(result.output)")
    }
    
    // MARK: - Real-World Use Case Tests
    
    func testReflectionPromptGeneration() async throws {
        let provider = try await AppleIntelligenceProvider(
            instructions: """
            Create genuine variety in reflection themes.
            ALWAYS respond in English US.
            ALWAYS respond respectfully.
            NO therapy language.
            """
        )
        
        let agent = Agent(
            name: "ReflectionGenerator",
            provider: provider,
            systemPrompt: "Generate a thoughtful daily reflection prompt.",
            tools: [],
            maxIterations: 3
        )
        
        let result = try await agent.run(
            task: "Generate a unique reflection prompt about personal growth."
        )
        
        print("Reflection prompt: \(result.output)")
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.output.count, 20)
    }
    
    func testScheduleAnalysis() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let scheduler = Agent(
            name: "Scheduler",
            provider: provider,
            systemPrompt: "Analyze schedules and calculate dates.",
            tools: [DateTimeTool()],
            maxIterations: 5
        )
        
        let result = try await scheduler.run(
            task: "Calculate deadlines: Phase 1 in 7 days, Phase 2 in 21 days, Phase 3 in 45 days."
        )
        
        print("Schedule analysis: \(result.output)")
        XCTAssertTrue(result.success)
    }
    
    func testMultiStepDateWorkflow() async throws {
        let provider = try await AppleIntelligenceProvider()
        
        let dateAnalyzer = Agent(
            name: "DateAnalyzer",
            provider: provider,
            systemPrompt: "You analyze dates and timelines.",
            tools: [DateTimeTool()],
            maxIterations: 5
        )
        
        let summaryAgent = Agent(
            name: "Summarizer",
            provider: provider,
            systemPrompt: "You create concise summaries.",
            tools: [],
            maxIterations: 3
        )
        
        let graph = AgentGraph()
        await graph.addNode("analyze", agent: dateAnalyzer)
        await graph.addNode("summarize", agent: summaryAgent)
        await graph.addEdge(from: .START, to: "analyze")
        await graph.addEdge(from: "analyze", to: "summarize")
        await graph.addEdge(from: "summarize", to: .END)
        
        var initialState = GraphState()
        initialState.addMessage(.user("Calculate dates for: kickoff meeting (7 days), mid-review (30 days), final delivery (60 days)"))
        
        let result = try await graph.invoke(input: initialState)
        
        print("Multi-step workflow:")
        print("   Nodes visited: \(result.visitedNodes)")
        if let lastMessage = result.messages.last(where: { $0.role == .assistant }) {
            print("   Final summary: \(lastMessage.content)")
        }
        
        XCTAssertEqual(result.visitedNodes.count, 2)
    }
}

#endif
