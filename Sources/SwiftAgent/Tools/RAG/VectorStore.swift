//
//  VectorStore.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

/// Protocol for vector database implementations
public protocol VectorStore: Sendable {
    /// Search for similar vectors
    func search(query: String, topK: Int) async throws -> [SearchResult]
    
    /// Add documents to the store
    func add(documents: [Document]) async throws
    
    /// Delete documents by ID
    func delete(ids: [String]) async throws
    
    /// Clear all documents
    func clear() async throws
    
    /// Get document count
    func count() async throws -> Int
}

public struct SearchResult: Sendable {
    public let id: String
    public let content: String
    public let score: Double  // Similarity score (0-1)
    public let metadata: [String: String]
    
    public init(id: String, content: String, score: Double, metadata: [String: String] = [:]) {
        self.id = id
        self.content = content
        self.score = score
        self.metadata = metadata
    }
}

public struct Document: Sendable {
    public let id: String
    public let content: String
    public let metadata: [String: String]
    
    public init(id: String, content: String, metadata: [String: String] = [:]) {
        self.id = id
        self.content = content
        self.metadata = metadata
    }
}
