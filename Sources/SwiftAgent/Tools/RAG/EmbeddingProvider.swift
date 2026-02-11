//
//  EmbeddingProvider.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

/// Protocol for embedding providers
public protocol EmbeddingProvider: Sendable {
    /// Generate embeddings for text
    func embed(text: String) async throws -> [Float]
    
    /// Generate embeddings for multiple texts (batched)
    func embedBatch(texts: [String]) async throws -> [[Float]]
}

/// Default batch implementation
public extension EmbeddingProvider {
    func embedBatch(texts: [String]) async throws -> [[Float]] {
        var embeddings: [[Float]] = []
        for text in texts {
            let embedding = try await embed(text: text)
            embeddings.append(embedding)
        }
        return embeddings
    }
}

/// Errors related to embedding generation
public enum EmbeddingError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    case emptyText
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from embedding API"
        case .apiError(let message):
            return "Embedding API error: \(message)"
        case .emptyText:
            return "Cannot generate embedding for empty text"
        }
    }
}
