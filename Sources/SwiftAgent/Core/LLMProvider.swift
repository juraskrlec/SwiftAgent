//
//  LLMProvider.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// Protocol that all LLM providers must implement
public protocol LLMProvider: Sendable {
    /// Generate a response from the LLM
    func generate(messages: [Message], tools: [Tool]?, options: GenerationOptions) async throws -> LLMResponse
    
    /// Stream a response from the LLM
    func stream(messages: [Message], tools: [Tool]?, options: GenerationOptions) async throws -> AsyncThrowingStream<LLMChunk, Error>
}

/// Options for generation
public struct GenerationOptions: Sendable {
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let stopSequences: [String]?
    
    public init(maxTokens: Int? = nil, temperature: Double? = nil, topP: Double? = nil, stopSequences: [String]? = nil) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.stopSequences = stopSequences
    }
    
    public static let `default` = GenerationOptions()
}

/// Errors that can occur during LLM operations
public enum LLMError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    case networkError(Error)
    case rateLimitExceeded
    case authenticationFailed
    case invalidAPIKey
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from LLM provider"
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .authenticationFailed:
            return "Authentication failed"
        case .invalidAPIKey:
            return "Invalid API key"
        }
    }
}
