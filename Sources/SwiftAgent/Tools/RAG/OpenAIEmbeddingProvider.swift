//
//  OpenAIEmbeddingProvider.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

/// OpenAI embedding provider
public actor OpenAIEmbeddingProvider: EmbeddingProvider {
    private let apiKey: String
    private let model: String
    private let baseURL: String
    
    public enum Model: String {
        case textEmbedding3Small = "text-embedding-3-small"  // 1536 dimensions, cheap
        case textEmbedding3Large = "text-embedding-3-large"  // 3072 dimensions, best quality
        case textEmbeddingAda002 = "text-embedding-ada-002"  // Legacy, 1536 dimensions
    }
    
    public init(
        apiKey: String,
        model: Model = .textEmbedding3Small,
        baseURL: String = "https://api.openai.com"
    ) {
        self.apiKey = apiKey
        self.model = model.rawValue
        self.baseURL = baseURL
    }
    
    public func embed(text: String) async throws -> [Float] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmbeddingError.emptyText
        }
        
        let url = URL(string: "\(baseURL)/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "input": text,
            "model": model
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EmbeddingError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        struct EmbeddingResponse: Decodable {
            let data: [EmbeddingData]
            
            struct EmbeddingData: Decodable {
                let embedding: [Float]
            }
        }
        
        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        
        guard let embedding = embeddingResponse.data.first?.embedding else {
            throw EmbeddingError.invalidResponse
        }
        
        return embedding
    }
    
    public func embedBatch(texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }
        
        let url = URL(string: "\(baseURL)/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "input": texts,
            "model": model
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EmbeddingError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        struct EmbeddingResponse: Decodable {
            let data: [EmbeddingData]
            
            struct EmbeddingData: Decodable {
                let embedding: [Float]
                let index: Int
            }
        }
        
        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        
        // Sort by index to maintain order
        let sortedData = embeddingResponse.data.sorted { $0.index < $1.index }
        
        return sortedData.map { $0.embedding }
    }
}
