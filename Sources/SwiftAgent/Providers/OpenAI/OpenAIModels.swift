//
//  OpenAIModels.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 15.02.2026..
//

import Foundation

// MARK: - Chat Completions Request Models

struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let maxCompletionTokens: Int?
    let temperature: Double?
    let topP: Double?
    let stop: [String]?
    let stream: Bool?
    let tools: [OpenAITool]?
    let toolChoice: OpenAIToolChoice?
    let parallelToolCalls: Bool?
    let responseFormat: OpenAIResponseFormat?
    let n: Int?
    let seed: Int?
    let user: String?

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxCompletionTokens = "max_completion_tokens"
        case temperature
        case topP = "top_p"
        case stop, stream, tools
        case toolChoice = "tool_choice"
        case parallelToolCalls = "parallel_tool_calls"
        case responseFormat = "response_format"
        case n, seed, user
    }
}

// MARK: - Messages

struct OpenAIMessage: Codable {
    enum Role: String, Codable {
        case system, user, assistant, tool
    }

    let role: Role
    let content: OpenAIMessageContent?
    let toolCalls: [OpenAIToolCall]?
    let toolCallId: String?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

// MARK: - Message Content

enum OpenAIMessageContent: Codable {
    case text(String)
    case parts([OpenAIContentPart])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .text(str)
        } else if let parts = try? container.decode([OpenAIContentPart].self) {
            self = .parts(parts)
        } else {
            throw DecodingError.typeMismatch(
                OpenAIMessageContent.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected String or [OpenAIContentPart]")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let str):
            try container.encode(str)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

// MARK: - Content Parts

struct OpenAIContentPart: Codable {
    enum PartType: String, Codable {
        case text
        case imageURL = "image_url"
    }

    let type: PartType
    let text: String?
    let imageURL: ImageURL?

    struct ImageURL: Codable {
        let url: String
        let detail: String?
    }

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }
}

// MARK: - Tools

struct OpenAITool: Encodable {
    let type: ToolType
    let function: FunctionDefinition

    enum ToolType: String, Encodable {
        case function
    }

    struct FunctionDefinition: Encodable {
        let name: String
        let description: String?
        let parameters: JSONSchema?
    }
}

// MARK: - JSON Schema

struct JSONSchema: Encodable {
    let type: String
    let properties: [String: Property]?
    let required: [String]?
    let additionalProperties: Bool?

    final class Property: Encodable {
        let type: String?
        let description: String?
        let enumValues: [String]?
        let items: Property?

        enum CodingKeys: String, CodingKey {
            case type, description
            case enumValues = "enum"
            case items
        }

        init(
            type: String? = nil,
            description: String? = nil,
            enumValues: [String]? = nil,
            items: Property? = nil
        ) {
            self.type = type
            self.description = description
            self.enumValues = enumValues
            self.items = items
        }
    }

    init(
        type: String = "object",
        properties: [String: Property]? = nil,
        required: [String]? = nil,
        additionalProperties: Bool? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }
}

// MARK: - Tool Choice

enum OpenAIToolChoice: Encodable {
    case none, auto, required
    case function(name: String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .required:
            try container.encode("required")
        case .function(let name):
            try container.encode(
                ToolChoiceObject(type: "function", function: .init(name: name))
            )
        }
    }

    private struct ToolChoiceObject: Encodable {
        let type: String
        let function: FunctionName
        struct FunctionName: Encodable {
            let name: String
        }
    }
}

// MARK: - Tool Calls

struct OpenAIToolCall: Codable {
    let id: String
    let type: String
    let function: OpenAIFunctionCall
}

struct OpenAIFunctionCall: Codable {
    let name: String
    let arguments: String
}

// MARK: - Response Format

enum OpenAIResponseFormat: Encodable {
    case text
    case jsonObject
    case jsonSchema(name: String, schema: JSONSchema, strict: Bool?)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .text:
            try container.encode(TypeOnly(type: "text"))
            
        case .jsonObject:
            try container.encode(TypeOnly(type: "json_object"))
            
        case .jsonSchema(let name, let schema, let strict):
            try container.encode(
                SchemaFormat(
                    type: "json_schema",
                    jsonSchema: .init(name: name, schema: schema, strict: strict)
                )
            )
        }
    }
    
    private struct TypeOnly: Encodable {
        let type: String
    }
    
    private struct SchemaFormat: Encodable {
        let type: String
        let jsonSchema: SchemaDetails
        
        enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }
    }
    
    private struct SchemaDetails: Encodable {
        let name: String
        let schema: JSONSchema
        let strict: Bool?
    }
}

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
