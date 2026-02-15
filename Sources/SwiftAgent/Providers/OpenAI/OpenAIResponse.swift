//
//  OpenAIResponse.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 15.02.2026..
//


import Foundation

// MARK: - Chat Completions Response

struct OpenAIResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Decodable {
        let index: Int
        let message: OpenAIMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - Streaming Response

struct OpenAIStreamChunk: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [StreamChoice]
    
    struct StreamChoice: Decodable {
        let index: Int
        let delta: Delta
        let finishReason: String?
        
        struct Delta: Decodable {
            let role: String?
            let content: String?
            let toolCalls: [ToolCallDelta]?
            
            struct ToolCallDelta: Decodable {
                let index: Int?
                let id: String?
                let type: String?
                let function: FunctionDelta?
                
                struct FunctionDelta: Decodable {
                    let name: String?
                    let arguments: String?
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case role, content
                case toolCalls = "tool_calls"
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }
}

// MARK: - Error Response

struct OpenAIErrorResponse: Decodable {
    let error: OpenAIError
    
    struct OpenAIError: Decodable {
        let message: String
        let type: String?
        let param: String?
        let code: String?
    }
}
