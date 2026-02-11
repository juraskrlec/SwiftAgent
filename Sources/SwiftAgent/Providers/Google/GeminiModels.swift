//
//  GeminiModels.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

// MARK: - Request Models

struct GeminiRequest: Encodable {
    let contents: [Content]
    let generationConfig: GenerationConfig?
    let tools: [Tool]?
    
    struct Content: Encodable {
        let role: String
        let parts: [Part]
    }
    
    struct Part: Encodable {
        let text: String?
        let functionCall: FunctionCall?
        let functionResponse: FunctionResponse?
        
        enum CodingKeys: String, CodingKey {
            case text
            case functionCall
            case functionResponse
        }
    }
    
    struct FunctionCall: Encodable {
        let name: String
        let args: [String: AnyCodable]
    }
    
    struct FunctionResponse: Encodable {
        let name: String
        let response: [String: AnyCodable]
    }
    
    struct GenerationConfig: Encodable {
        let temperature: Double?
        let topP: Double?
        let topK: Int?
        let maxOutputTokens: Int?
        let stopSequences: [String]?
    }
    
    struct Tool: Encodable {
        let functionDeclarations: [FunctionDeclaration]
    }
    
    struct FunctionDeclaration: Encodable {
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

struct GeminiResponse: Decodable {
    let candidates: [Candidate]
    let usageMetadata: UsageMetadata?
    
    struct Candidate: Decodable {
        let content: Content
        let finishReason: String?
        
        struct Content: Decodable {
            let parts: [Part]
            let role: String
        }
        
        struct Part: Decodable {
            let text: String?
            let functionCall: FunctionCall?
            
            struct FunctionCall: Decodable {
                let name: String
                let args: [String: AnyCodable]
            }
        }
    }
    
    struct UsageMetadata: Decodable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
        let totalTokenCount: Int?
    }
}

// MARK: - Streaming Models

struct GeminiStreamChunk: Decodable {
    let candidates: [Candidate]?
    let usageMetadata: GeminiResponse.UsageMetadata?
    
    struct Candidate: Decodable {
        let content: Content?
        let finishReason: String?
        
        struct Content: Decodable {
            let parts: [Part]
            let role: String?
        }
        
        struct Part: Decodable {
            let text: String?
            let functionCall: FunctionCall?
            
            struct FunctionCall: Decodable {
                let name: String
                let args: [String: AnyCodable]
            }
        }
    }
}

// MARK: - Error Models

struct GeminiError: Decodable, Error {
    let error: ErrorDetail
    
    struct ErrorDetail: Decodable {
        let code: Int
        let message: String
        let status: String
    }
}
