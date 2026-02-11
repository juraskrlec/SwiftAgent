//
//  GeminiEmbeddingsTest.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import XCTest
@testable import SwiftAgent

final class GeminiEmbeddingTests: XCTestCase {
    
    var provider: GeminiEmbeddingProvider!
    
    override func setUp() async throws {
        try await super.setUp()
        
        guard let apiKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"],
              !apiKey.isEmpty else {
            throw XCTSkip("GOOGLE_API_KEY not set")
        }
            
        provider = GeminiEmbeddingProvider(apiKey: apiKey)
    }
    
    override func tearDown() async throws {
        provider = nil
        try await super.tearDown()
    }
    
    func testSingleEmbedding() async throws {
        let embedding = try await provider.embed(text: "Swift is a programming language")
        
        XCTAssertEqual(embedding.count, 3072)  // Flexible, supports: 128 - 3072, Recommended: 768, 1536, 3072
        print("Generated embedding with \(embedding.count) dimensions")
    }
    
    func testBatchEmbedding() async throws {
        let texts = [
            "Swift is fast",
            "Python is popular",
            "JavaScript runs everywhere"
        ]
        
        let embeddings = try await provider.embedBatch(texts: texts)
        
        XCTAssertEqual(embeddings.count, 3)
        XCTAssertEqual(embeddings[0].count, 3072)
        
        print("Generated \(embeddings.count) embeddings")
    }
    
    func testWithVectorStore() async throws {
        let vectorStore = InMemoryVectorStore(embeddingProvider: provider)
        
        let documents = [
            Document(id: "1", content: "Swift is a programming language", metadata: [:]),
            Document(id: "2", content: "Python is used in AI", metadata: [:]),
            Document(id: "3", content: "SwiftUI is a UI framework", metadata: [:])
        ]
        
        try await vectorStore.add(documents: documents)
        
        let results = try await vectorStore.search(query: "Swift programming", topK: 2)
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0].content.contains("Swift"))
        
        print("Top result: \(results[0].content)")
        print("Score: \(results[0].score)")
    }
    
    func testEmptyText() async throws {
        do {
            _ = try await provider.embed(text: "")
            XCTFail("Should throw error for empty text")
        } catch EmbeddingError.emptyText {
            print("Correctly rejected empty text")
        }
    }
    
    func testSemanticSimilarity() async throws {
        let vectorStore = InMemoryVectorStore(embeddingProvider: provider)
        
        let documents = [
            Document(id: "1", content: "The cat sleeps on the mat", metadata: [:]),
            Document(id: "2", content: "The dog plays in the yard", metadata: [:]),
            Document(id: "3", content: "A feline rests on the rug", metadata: [:])
        ]
        
        try await vectorStore.add(documents: documents)
        
        let results = try await vectorStore.search(query: "cat on mat", topK: 3)
        
        print("Query: 'cat on mat'")
        for (index, result) in results.enumerated() {
            print("\(index + 1). Score: \(String(format: "%.4f", result.score)) - \(result.content)")
        }
        
        // Most similar should be doc1 or doc3
        XCTAssertTrue(results[0].content.contains("cat") || results[0].content.contains("feline"))
    }
}
