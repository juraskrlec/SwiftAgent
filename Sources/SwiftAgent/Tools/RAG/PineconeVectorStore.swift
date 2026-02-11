//
//  PineconeVectorStore.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

/// Pinecone vector database implementation
public actor PineconeVectorStore: VectorStore {
    private let apiKey: String
    private let environment: String
    private let indexName: String
    private let embeddingProvider: EmbeddingProvider
    private let baseURL: String
    private let dimension: Int
    
    public init(
        apiKey: String,
        environment: String = "us-east-1",
        indexName: String,
        embeddingProvider: EmbeddingProvider,
        dimension: Int = 1536  // Default for OpenAI text-embedding-3-small
    ) {
        self.apiKey = apiKey
        self.environment = environment
        self.indexName = indexName
        self.embeddingProvider = embeddingProvider
        self.dimension = dimension
        self.baseURL = "https://\(indexName)-\(environment).svc.pinecone.io"
    }
    
    // MARK: - VectorStore Protocol
    
    public func search(query: String, topK: Int) async throws -> [SearchResult] {
        // Generate query embedding
        let queryEmbedding = try await embeddingProvider.embed(text: query)
        
        // Query Pinecone
        let url = URL(string: "\(baseURL)/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "vector": queryEmbedding,
            "topK": topK,
            "includeMetadata": true,
            "includeValues": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VectorStoreError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VectorStoreError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // Parse response
        struct PineconeQueryResponse: Decodable {
            let matches: [Match]
            
            struct Match: Decodable {
                let id: String
                let score: Double
                let metadata: [String: MetadataValue]?
                
                enum MetadataValue: Decodable {
                    case string(String)
                    case int(Int)
                    case double(Double)
                    case bool(Bool)
                    
                    init(from decoder: Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        if let string = try? container.decode(String.self) {
                            self = .string(string)
                        } else if let int = try? container.decode(Int.self) {
                            self = .int(int)
                        } else if let double = try? container.decode(Double.self) {
                            self = .double(double)
                        } else if let bool = try? container.decode(Bool.self) {
                            self = .bool(bool)
                        } else {
                            throw DecodingError.dataCorruptedError(
                                in: container,
                                debugDescription: "Invalid metadata value"
                            )
                        }
                    }
                    
                    var stringValue: String {
                        switch self {
                        case .string(let s): return s
                        case .int(let i): return "\(i)"
                        case .double(let d): return "\(d)"
                        case .bool(let b): return "\(b)"
                        }
                    }
                }
            }
        }
        
        let queryResponse = try JSONDecoder().decode(PineconeQueryResponse.self, from: data)
        
        return queryResponse.matches.map { match in
            let content = match.metadata?["content"]?.stringValue ?? ""
            
            // Convert metadata to [String: String]
            var metadata: [String: String] = [:]
            if let rawMetadata = match.metadata {
                for (key, value) in rawMetadata where key != "content" {
                    metadata[key] = value.stringValue
                }
            }
            
            return SearchResult(
                id: match.id,
                content: content,
                score: match.score,
                metadata: metadata
            )
        }
    }
    
    public func add(documents: [Document]) async throws {
        guard !documents.isEmpty else { return }
        
        // Generate embeddings in batch
        let texts = documents.map { $0.content }
        let embeddings = try await embeddingProvider.embedBatch(texts: texts)
        
        // Prepare vectors for Pinecone
        var vectors: [[String: Any]] = []
        
        for (index, doc) in documents.enumerated() {
            var metadata = doc.metadata
            metadata["content"] = doc.content  // Store content in metadata
            
            vectors.append([
                "id": doc.id,
                "values": embeddings[index],
                "metadata": metadata
            ])
        }
        
        // Upsert to Pinecone (batch size of 100)
        let batchSize = 100
        for batch in vectors.chunked(into: batchSize) {
            try await upsertBatch(batch)
        }
    }
    
    public func delete(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        
        let url = URL(string: "\(baseURL)/vectors/delete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["ids": ids]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VectorStoreError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VectorStoreError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
    }
    
    public func clear() async throws {
        // Delete all vectors in the namespace
        let url = URL(string: "\(baseURL)/vectors/delete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["deleteAll": true]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VectorStoreError.apiError("Failed to clear index")
        }
    }
    
    public func count() async throws -> Int {
        let url = URL(string: "\(baseURL)/describe_index_stats")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VectorStoreError.apiError("Failed to get index stats")
        }
        
        struct StatsResponse: Decodable {
            let totalVectorCount: Int
        }
        
        let stats = try JSONDecoder().decode(StatsResponse.self, from: data)
        return stats.totalVectorCount
    }
    
    // MARK: - Private Helpers
    
    private func upsertBatch(_ vectors: [[String: Any]]) async throws {
        let url = URL(string: "\(baseURL)/vectors/upsert")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["vectors": vectors]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VectorStoreError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VectorStoreError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
    }
}

// MARK: - Vector Store Errors

public enum VectorStoreError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from vector store"
        case .apiError(let message):
            return "Vector store API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Array Extension for Batching

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
