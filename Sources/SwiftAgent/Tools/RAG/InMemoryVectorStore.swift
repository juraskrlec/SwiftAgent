//
//  InMemoryVectorStore.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

/// In-memory vector store with embeddings
public actor InMemoryVectorStore: VectorStore {
    private var documents: [String: StoredDocument] = [:]
    private let embeddingProvider: EmbeddingProvider
    
    struct StoredDocument {
        let document: Document
        let embedding: [Float]
    }
    
    public init(embeddingProvider: EmbeddingProvider) {
        self.embeddingProvider = embeddingProvider
    }
    
    public func search(query: String, topK: Int) async throws -> [SearchResult] {
        guard !documents.isEmpty else { return [] }
        
        // Get embedding for query
        let queryEmbedding = try await embeddingProvider.embed(text: query)
        
        // Calculate cosine similarity with all documents
        var results: [(String, Document, Double)] = []
        
        for (id, stored) in documents {
            let similarity = cosineSimilarity(queryEmbedding, stored.embedding)
            results.append((id, stored.document, similarity))
        }
        
        // Return top K results sorted by similarity (highest first)
        return results
            .sorted { $0.2 > $1.2 }
            .prefix(topK)
            .map { SearchResult(id: $0.0, content: $0.1.content, score: $0.2, metadata: $0.1.metadata) }
    }
    
    public func add(documents: [Document]) async throws {
        guard !documents.isEmpty else { return }
        
        // Batch embed all documents for efficiency
        let texts = documents.map { $0.content }
        let embeddings = try await embeddingProvider.embedBatch(texts: texts)
        
        // Store documents with their embeddings
        for (index, doc) in documents.enumerated() {
            self.documents[doc.id] = StoredDocument(
                document: doc,
                embedding: embeddings[index]
            )
        }
    }
    
    public func delete(ids: [String]) async throws {
        for id in ids {
            documents.removeValue(forKey: id)
        }
    }
    
    public func clear() async throws {
        documents.removeAll()
    }
    
    public func count() async throws -> Int {
        return documents.count
    }
    
    // MARK: - Helper Methods
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        
        let dotProduct = zip(a, b).map { Double($0) * Double($1) }.reduce(0, +)
        let magnitudeA = sqrt(a.map { Double($0) * Double($0) }.reduce(0, +))
        let magnitudeB = sqrt(b.map { Double($0) * Double($0) }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
}
