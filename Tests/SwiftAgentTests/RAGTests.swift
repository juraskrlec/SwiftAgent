//
//  RAGTests.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import XCTest
@testable import SwiftAgent

final class RAGTests: XCTestCase {
    
    var embeddingProvider: OpenAIEmbeddingProvider!
    var vectorStore: InMemoryVectorStore!
    
    override func setUp() async throws {
        try await super.setUp()
        
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
              !apiKey.isEmpty else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        embeddingProvider = OpenAIEmbeddingProvider(apiKey: apiKey)
        vectorStore = InMemoryVectorStore(embeddingProvider: embeddingProvider)
    }
    
    override func tearDown() async throws {
        try await vectorStore?.clear()
        embeddingProvider = nil
        vectorStore = nil
        try await super.tearDown()
    }
    
    func testDocumentChunking() {
        let text = String(repeating: "word ", count: 1000)
        let chunks = DocumentChunker.chunk(text: text, chunkSize: 100, overlap: 10)
        
        print("Created \(chunks.count) chunks from 1000 words")
        XCTAssertGreaterThan(chunks.count, 1)
    }
    
    func testVectorStoreAddAndSearch() async throws {
        let documents = [
            Document(id: "1", content: "Swift is a programming language", metadata: ["topic": "swift"]),
            Document(id: "2", content: "Python is great for data science", metadata: ["topic": "python"]),
            Document(id: "3", content: "Swift has great performance", metadata: ["topic": "swift"])
        ]
        
        try await vectorStore.add(documents: documents)
        
        let count = try await vectorStore.count()
        XCTAssertEqual(count, 3)
        
        let results = try await vectorStore.search(query: "Swift programming performance", topK: 2)
        
        XCTAssertEqual(results.count, 2)
        print("Top result: \(results[0].content) (score: \(results[0].score))")
        
        // Should find Swift documents
        XCTAssertTrue(results[0].content.contains("Swift"))
    }
    
    func testRAGWithAgent() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
              !apiKey.isEmpty else {
            throw XCTSkip("OPENAI_API_KEY not set")
        }
        
        let knowledge = """
        SwiftAgents is a framework for building AI agents in Swift.
        It supports multiple LLM providers including Claude, OpenAI, and Apple Intelligence.
        The framework includes tools for RAG (Retrieval-Augmented Generation).
        """
        
        let documents = DocumentChunker.createDocuments(
            from: knowledge,
            chunkSize: 50,
            overlap: 10,
            sourceMetadata: ["source": "documentation"]
        )
        
        try await vectorStore.add(documents: documents)
        
        let provider = OpenAIProvider(apiKey: apiKey, model: .gpt51Mini)
        
        let agent = Agent(
            name: "TestRAG",
            provider: provider,
            systemPrompt: "You are a helpful assistant. Use the search_knowledge_base tool to find information.",
            tools: [VectorSearchTool(vectorStore: vectorStore)],
            maxIterations: 5
        )
        
        // Ask question
        let result = try await agent.run(task: "What LLM providers does SwiftAgents support?")
        
        print("Agent response: \(result.output)")
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Claude") || result.output.contains("OpenAI"))
    }
}
