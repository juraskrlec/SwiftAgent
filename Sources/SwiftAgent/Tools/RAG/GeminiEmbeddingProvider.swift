//
//  GeminiEmbeddingProvider.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

/// Google Gemini embedding provider
public actor GeminiEmbeddingProvider: EmbeddingProvider {
    private let apiKey: String
    private let model: String
    private let baseURL: String
    
    public enum Model: String {
        case embedding001 = "gemini-embedding-001"
    }
    
    public init(
        apiKey: String,
        model: Model = .embedding001,
        baseURL: String = "https://generativelanguage.googleapis.com"
    ) {
        self.apiKey = apiKey
        self.model = model.rawValue
        self.baseURL = baseURL
    }
    
    public func embed(text: String) async throws -> [Float] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmbeddingError.emptyText
        }
        
        let url = URL(string: "\(baseURL)/v1beta/models/\(model):embedContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "models/\(model)",
            "content": [
                "parts": [
                    ["text": text]
                ]
            ]
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
            let embedding: Embedding
            
            struct Embedding: Decodable {
                let values: [Float]
            }
        }
        
        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        
        return embeddingResponse.embedding.values
    }
    
    public func embedBatch(texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }
        
        let url = URL(string: "\(baseURL)/v1beta/models/\(model):batchEmbedContents")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare batch requests
        let requests = texts.map { text in
            [
                "model": "models/\(model)",
                "content": [
                    "parts": [
                        ["text": text]
                    ]
                ]
            ] as [String: Any]
        }
        
        let body: [String: Any] = [
            "requests": requests
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
        
        struct BatchEmbeddingResponse: Decodable {
            let embeddings: [Embedding]
            
            struct Embedding: Decodable {
                let values: [Float]
            }
        }
        
        let batchResponse = try JSONDecoder().decode(BatchEmbeddingResponse.self, from: data)
        
        return batchResponse.embeddings.map { $0.values }
    }
}
