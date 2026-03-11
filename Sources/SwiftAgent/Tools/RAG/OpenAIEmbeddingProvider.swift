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

    // MARK: - Model

    public enum Model: String {
        /// 1536 dimensions. Best price/performance. Supports MRL truncation.
        case textEmbedding3Small = "text-embedding-3-small"
        /// 3072 dimensions. Highest quality. Supports MRL truncation.
        case textEmbedding3Large = "text-embedding-3-large"
        /// Legacy. 1536 dimensions. Does NOT support dimensions parameter.
        case textEmbeddingAda002 = "text-embedding-ada-002"

        /// Whether this model supports the `dimensions` parameter.
        public var supportsDimensions: Bool {
            switch self {
            case .textEmbedding3Small, .textEmbedding3Large: return true
            case .textEmbeddingAda002: return false
            }
        }

        /// Default output dimensionality for this model.
        public var defaultDimensions: Int {
            switch self {
            case .textEmbedding3Small: return 1536
            case .textEmbedding3Large: return 3072
            case .textEmbeddingAda002: return 1536
            }
        }
    }

    private let modelEnum: Model

    // MARK: - Init

    public init(
        apiKey: String,
        model: Model = .textEmbedding3Small,
        baseURL: String = "https://api.openai.com"
    ) {
        self.apiKey = apiKey
        self.modelEnum = model
        self.model = model.rawValue
        self.baseURL = baseURL
    }

    // MARK: - EmbeddingProvider (required)

    public func embed(text: String) async throws -> [Float] {
        try await embed(text: text, outputDimensionality: nil)
    }

    public func embedBatch(texts: [String]) async throws -> [[Float]] {
        try await embedBatch(texts: texts, outputDimensionality: nil)
    }

    // MARK: - Text Embedding (extended)

    /// Embed a single string.
    /// - Parameters:
    ///   - text: Input text (max 8,192 tokens).
    ///   - outputDimensionality: Truncate output vector using MRL.
    ///                           Only supported by `text-embedding-3-small` and `text-embedding-3-large`.
    public func embed(
        text: String,
        outputDimensionality: Int? = nil
    ) async throws -> [Float] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmbeddingError.emptyText
        }

        var request = makeRequest()

        var body: [String: Any] = ["input": text, "model": model]
        if let dim = outputDimensionality, modelEnum.supportsDimensions {
            body["dimensions"] = dim
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        struct EmbeddingResponse: Decodable {
            let data: [EmbeddingData]
            struct EmbeddingData: Decodable { let embedding: [Float] }
        }

        guard let embedding = try JSONDecoder()
            .decode(EmbeddingResponse.self, from: data)
            .data.first?.embedding
        else { throw EmbeddingError.invalidResponse }

        return embedding
    }

    // MARK: - Batch Text Embedding (extended)

    /// Embed multiple strings in a single request (max 2,048 inputs, 300,000 tokens total).
    /// - Parameters:
    ///   - texts: Array of input strings.
    ///   - outputDimensionality: Truncate output vectors using MRL.
    ///                           Only supported by `text-embedding-3-small` and `text-embedding-3-large`.
    public func embedBatch(
        texts: [String],
        outputDimensionality: Int? = nil
    ) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }

        var request = makeRequest()

        var body: [String: Any] = ["input": texts, "model": model]
        if let dim = outputDimensionality, modelEnum.supportsDimensions {
            body["dimensions"] = dim
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        struct EmbeddingResponse: Decodable {
            let data: [EmbeddingData]
            struct EmbeddingData: Decodable {
                let embedding: [Float]
                let index: Int
            }
        }

        let decoded = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        return decoded.data.sorted { $0.index < $1.index }.map { $0.embedding }
    }

    // MARK: - Private Helpers

    private func makeRequest() -> URLRequest {
        let url = URL(string: "\(baseURL)/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
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
