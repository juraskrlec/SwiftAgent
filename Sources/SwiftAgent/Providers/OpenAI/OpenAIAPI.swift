//
//  OpenAIAPI.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

actor OpenAIAPI {
    private let apiKey: String
    private let baseURL: String
    private let session: URLSession
    
    init(apiKey: String, baseURL: String = "https://api.openai.com") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }
    
    func sendRequest(_ request: OpenAIRequest) async throws -> OpenAIResponse {
        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        
        // Check for errors
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
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
        return try decoder.decode(OpenAIResponse.self, from: data)
    }
    
    func streamRequest(_ request: OpenAIRequest) async throws -> AsyncThrowingStream<OpenAIStreamChunk, Error> {
        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var streamRequest = request
        streamRequest = OpenAIRequest(
            model: request.model,
            messages: request.messages,
            maxCompletionTokens: request.maxCompletionTokens,
            temperature: request.temperature,
            topP: request.topP,
            stop: request.stop,
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
                                let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: data)
                                continuation.yield(chunk)
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
