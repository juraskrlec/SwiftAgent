//
//  AnthropicAPI.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

actor AnthropicAPI {
    private let apiKey: String
    private let baseURL: String
    private let session: URLSession
    
    init(apiKey: String, baseURL: String = "https://api.anthropic.com") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }
    
    func sendRequest(_ request: AnthropicRequest) async throws -> AnthropicResponse {
        let url = URL(string: "\(baseURL)/v1/messages")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        
        // Check for errors
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data) {
                switch httpResponse.statusCode {
                case 401:
                    throw LLMError.authenticationFailed
                case 429:
                    throw LLMError.rateLimitExceeded
                default:
                    throw LLMError.apiError(errorResponse.error.message)
                }
            }
            throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(AnthropicResponse.self, from: data)
    }
    
    func streamRequest(_ request: AnthropicRequest) async throws -> AsyncThrowingStream<AnthropicStreamEvent, Error> {
        let url = URL(string: "\(baseURL)/v1/messages")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        var streamRequest = request
        streamRequest = AnthropicRequest(
            model: request.model,
            messages: request.messages,
            maxTokens: request.maxTokens,
            system: request.system,
            temperature: request.temperature,
            topP: request.topP,
            stopSequences: request.stopSequences,
            tools: request.tools,
            stream: true
        )
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(streamRequest)
        
        let (bytes, response) = try await session.bytes(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        // SSE format: "data: {...}"
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            
                            if let data = jsonString.data(using: .utf8) {
                                let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: data)
                                continuation.yield(event)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
