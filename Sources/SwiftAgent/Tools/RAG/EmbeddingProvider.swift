//
//  EmbeddingProvider.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

/// Protocol for embedding providers
public protocol EmbeddingProvider: Sendable {

    /// Embed a single string.
    func embed(text: String) async throws -> [Float]

    /// Embed multiple strings in one call.
    func embedBatch(texts: [String]) async throws -> [[Float]]
}

// MARK: - Extended API (optional overrides)

public extension EmbeddingProvider {

    // MARK: Task-typed variants

    /// Embed with an optional task hint and output dimensionality.
    /// Providers that support these parameters should override this method;
    /// the default falls back to the plain `embed(text:)`.
    func embed(
        text: String,
        taskType: EmbeddingTaskType? = nil,
        outputDimensionality: Int? = nil
    ) async throws -> [Float] {
        try await embed(text: text)
    }

    /// Batch-embed with an optional task hint and output dimensionality.
    /// Providers that support these parameters should override this method;
    /// the default falls back to the plain `embedBatch(texts:)`.
    func embedBatch(
        texts: [String],
        taskType: EmbeddingTaskType? = nil,
        outputDimensionality: Int? = nil
    ) async throws -> [[Float]] {
        try await embedBatch(texts: texts)
    }

    // MARK: Default sequential batch fallback

    /// Sequential fallback used when a provider does not implement native batching.
    func embedBatch(texts: [String]) async throws -> [[Float]] {
        var embeddings: [[Float]] = []
        for text in texts {
            let embedding = try await embed(text: text)
            embeddings.append(embedding)
        }
        return embeddings
    }
}

// MARK: - Task Type

/// Hints to the embedding model what the vectors will be used for,
/// allowing it to optimise the embedding space accordingly.
public enum EmbeddingTaskType: String, Sendable {
    case semanticSimilarity  = "SEMANTIC_SIMILARITY"
    case classification      = "CLASSIFICATION"
    case clustering          = "CLUSTERING"
    case retrievalDocument   = "RETRIEVAL_DOCUMENT"
    case retrievalQuery      = "RETRIEVAL_QUERY"
    case codeRetrievalQuery  = "CODE_RETRIEVAL_QUERY"
    case questionAnswering   = "QUESTION_ANSWERING"
    case factVerification    = "FACT_VERIFICATION"
}

// MARK: - Errors

/// Errors related to embedding generation.
public enum EmbeddingError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    case emptyText
    case unsupportedModality(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from embedding API"
        case .apiError(let message):
            return "Embedding API error: \(message)"
        case .emptyText:
            return "Cannot generate embedding for empty text"
        case .unsupportedModality(let modality):
            return "Modality '\(modality)' is not supported by this embedding provider"
        }
    }
}
