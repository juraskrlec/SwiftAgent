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

    // MARK: - Model

    public enum Model: String {
        /// Multimodal embeddings (text, image, audio, video, PDF). No MRL truncation.
        case embedding2 = "gemini-embedding-2-preview"
        /// Text-only. Supports MRL output_dimensionality (128–3072). Default: 3072.
        case embedding001 = "gemini-embedding-001"
    }

    // MARK: - Multimodal Part

    /// Represents a single part in a multimodal embedding request.
    /// Only supported by `gemini-embedding-2-preview`.
    public enum Part {
        case text(String)
        /// Raw inline data (e.g. image, audio, video, PDF).
        case inlineData(mimeType: String, base64Data: String)
    }

    // MARK: - Init

    public init(
        apiKey: String,
        model: Model = .embedding001,
        baseURL: String = "https://generativelanguage.googleapis.com"
    ) {
        self.apiKey = apiKey
        self.model = model.rawValue
        self.baseURL = baseURL
    }

    // MARK: - EmbeddingProvider (required)

    /// Bare protocol requirement — forwards to the full implementation with no hints.
    public func embed(text: String) async throws -> [Float] {
        try await embed(text: text, taskType: nil, outputDimensionality: nil)
    }

    /// Bare protocol requirement — forwards to the full implementation with no hints.
    public func embedBatch(texts: [String]) async throws -> [[Float]] {
        try await embedBatch(texts: texts, taskType: nil, outputDimensionality: nil)
    }

    // MARK: - Text Embedding (extended)

    /// Embed a single string.
    /// - Parameters:
    ///   - text: Input text.
    ///   - taskType: Optional task hint (gemini-embedding-001 only).
    ///   - outputDimensionality: Truncate output vector (128–3072, gemini-embedding-001 only).
    ///                           Recommended values: 768, 1536, 3072.
    public func embed(
        text: String,
        taskType: EmbeddingTaskType? = nil,
        outputDimensionality: Int? = nil
    ) async throws -> [Float] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmbeddingError.emptyText
        }
        return try await embedParts(
            [.text(text)],
            taskType: taskType,
            outputDimensionality: outputDimensionality
        )
    }

    // MARK: - Multimodal Embedding

    /// Embed a mixed list of parts (text, image, audio, video, PDF) into a single aggregated vector.
    /// Only `gemini-embedding-2-preview` supports non-text modalities.
    /// - Parameters:
    ///   - parts: One or more parts to embed together.
    ///   - taskType: Optional task hint (text models only).
    ///   - outputDimensionality: Truncate output vector (gemini-embedding-001 only).
    public func embedParts(
        _ parts: [Part],
        taskType: EmbeddingTaskType? = nil,
        outputDimensionality: Int? = nil
    ) async throws -> [Float] {
        guard !parts.isEmpty else { throw EmbeddingError.emptyText }

        let url = URL(string: "\(baseURL)/v1beta/models/\(model):embedContent")!
        var request = makeRequest(url: url)

        var body: [String: Any] = [
            "model": "models/\(model)",
            "content": ["parts": parts.map(encodePart)]
        ]
        if let taskType { body["taskType"] = taskType.rawValue }
        if let dim = outputDimensionality { body["output_dimensionality"] = dim }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await fetchEmbedding(request: request)
    }

    // MARK: - Batch Text Embedding (extended)

    /// Embed multiple strings in a single batch request.
    /// - Parameters:
    ///   - texts: Array of input strings.
    ///   - taskType: Optional task hint (gemini-embedding-001 only).
    ///   - outputDimensionality: Truncate output vectors (gemini-embedding-001 only).
    public func embedBatch(
        texts: [String],
        taskType: EmbeddingTaskType? = nil,
        outputDimensionality: Int? = nil
    ) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }

        let url = URL(string: "\(baseURL)/v1beta/models/\(model):batchEmbedContents")!
        var request = makeRequest(url: url)

        let requests: [[String: Any]] = texts.map { text in
            var req: [String: Any] = [
                "model": "models/\(model)",
                "content": ["parts": [["text": text]]]
            ]
            if let taskType { req["taskType"] = taskType.rawValue }
            if let dim = outputDimensionality { req["output_dimensionality"] = dim }
            return req
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: ["requests": requests])

        return try await fetchBatchEmbeddings(request: request)
    }

    // MARK: - Private Helpers

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func encodePart(_ part: Part) -> [String: Any] {
        switch part {
        case .text(let str):
            return ["text": str]
        case .inlineData(let mimeType, let base64Data):
            return ["inline_data": ["mime_type": mimeType, "data": base64Data]]
        }
    }

    private func fetchEmbedding(request: URLRequest) async throws -> [Float] {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        struct EmbeddingResponse: Decodable {
            let embedding: Embedding
            struct Embedding: Decodable { let values: [Float] }
        }

        return try JSONDecoder().decode(EmbeddingResponse.self, from: data).embedding.values
    }

    private func fetchBatchEmbeddings(request: URLRequest) async throws -> [[Float]] {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        struct BatchEmbeddingResponse: Decodable {
            let embeddings: [Embedding]
            struct Embedding: Decodable { let values: [Float] }
        }

        return try JSONDecoder().decode(BatchEmbeddingResponse.self, from: data).embeddings.map { $0.values }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw EmbeddingError.invalidResponse
        }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EmbeddingError.apiError("HTTP \(http.statusCode): \(msg)")
        }
    }
}
