//
//  OpenAIModels.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

// MARK: - Request Models

struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let maxCompletionTokens: Int?  // New parameter for newer models
    let temperature: Double?
    let topP: Double?
    let stop: [String]?
    let tools: [OpenAITool]?
    let stream: Bool?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxCompletionTokens = "max_completion_tokens"
        case temperature
        case topP = "top_p"
        case stop
        case tools
        case stream
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String?
    let toolCalls: [OpenAIToolCall]?
    let toolCallId: String?
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

struct OpenAIToolCall: Codable {
    let id: String
    let type: String
    let function: OpenAIFunction
}

struct OpenAIFunction: Codable {
    let name: String
    let arguments: String  // JSON string
}

struct OpenAITool: Encodable {
    let type: String
    let function: FunctionDefinition
    
    struct FunctionDefinition: Encodable {
        let name: String
        let description: String
        let parameters: Parameters
        
        struct Parameters: Encodable {
            let type: String
            let properties: [String: PropertySchema]
            let required: [String]
        }
        
        struct PropertySchema: Encodable {
            let type: String
            let description: String
            let enumValues: [String]?
            
            enum CodingKeys: String, CodingKey {
                case type
                case description
                case enumValues = "enum"
            }
        }
    }
}

// MARK: - Response Models

struct OpenAIResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: OpenAIUsage?
    
    struct Choice: Decodable {
        let index: Int
        let message: OpenAIMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
}

struct OpenAIUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Streaming Models

struct OpenAIStreamChunk: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [StreamChoice]
    
    struct StreamChoice: Decodable {
        let index: Int
        let delta: StreamDelta
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
    }
    
    struct StreamDelta: Decodable {
        let role: String?
        let content: String?
        let toolCalls: [OpenAIToolCallDelta]?
        
        enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
        }
    }
    
    struct OpenAIToolCallDelta: Decodable {
        let index: Int
        let id: String?
        let type: String?
        let function: FunctionDelta?
        
        struct FunctionDelta: Decodable {
            let name: String?
            let arguments: String?
        }
    }
}

// MARK: - Error Models

struct OpenAIError: Decodable, Error {
    let message: String
    let type: String
    let code: String?
}

struct OpenAIErrorResponse: Decodable {
    let error: OpenAIError
}
