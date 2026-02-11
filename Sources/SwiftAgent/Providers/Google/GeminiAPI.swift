//
//  GeminiAPI.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

actor GeminiAPI {
    private let apiKey: String
    private let baseURL: String
    private let session: URLSession
    
    init(apiKey: String, baseURL: String = "https://generativelanguage.googleapis.com") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }
    
    func sendRequest(_ request: GeminiRequest, model: String) async throws -> GeminiResponse {
        let url = URL(string: "\(baseURL)/v1beta/models/\(model):generateContent")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        
        // Check for errors
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(GeminiError.self, from: data) {
                switch errorResponse.error.code {
                case 401, 403:
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
        return try decoder.decode(GeminiResponse.self, from: data)
    }
    
    func streamRequest(_ request: GeminiRequest, model: String) async throws -> AsyncThrowingStream<GeminiStreamChunk, Error> {
        let url = URL(string: "\(baseURL)/v1beta/models/\(model):streamGenerateContent?alt=sse")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
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
                            
                            if let data = jsonString.data(using: .utf8) {
                                let chunk = try JSONDecoder().decode(GeminiStreamChunk.self, from: data)
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
