//
//  AnthropicModels.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

// MARK: - Request Models

struct AnthropicRequest: Encodable {
    let model: String
    let messages: [AnthropicMessage]
    let maxTokens: Int
    let system: String?
    let temperature: Double?
    let topP: Double?
    let stopSequences: [String]?
    let tools: [AnthropicTool]?
    let stream: Bool?
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case system
        case temperature
        case topP = "top_p"
        case stopSequences = "stop_sequences"
        case tools
        case stream
    }
}

struct AnthropicMessage: Codable {
    let role: String
    let content: AnthropicContent
}

enum AnthropicContent: Codable {
    case text(String)
    case blocks([ContentBlock])
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string):
            try container.encode(string)
        case .blocks(let blocks):
            try container.encode(blocks)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .text(string)
        } else if let blocks = try? container.decode([ContentBlock].self) {
            self = .blocks(blocks)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid content format"
            )
        }
    }
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: [String: AnyCodable]?
    let content: String?  // For tool_result blocks
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case id
        case name
        case input
        case content
        case toolUseId = "tool_use_id"
    }
    
    init(type: String, text: String?, id: String?, name: String?, input: [String: AnyCodable]?, content: String? = nil) {
        self.type = type
        self.text = text
        self.id = id
        self.name = name
        self.input = input
        self.content = content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        
        // Try both id and tool_use_id
        if let toolUseId = try container.decodeIfPresent(String.self, forKey: .toolUseId) {
            id = toolUseId
        } else {
            id = try container.decodeIfPresent(String.self, forKey: .id)
        }
        
        name = try container.decodeIfPresent(String.self, forKey: .name)
        input = try container.decodeIfPresent([String: AnyCodable].self, forKey: .input)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        // For tool_result, use content and tool_use_id
        if type == "tool_result" {
            try container.encodeIfPresent(content ?? text, forKey: .content)
            try container.encodeIfPresent(id, forKey: .toolUseId)
        } else {
            // For other types (text, tool_use), use text/id/name/input
            try container.encodeIfPresent(text, forKey: .text)
            try container.encodeIfPresent(id, forKey: .id)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(input, forKey: .input)
        }
    }
}

struct AnthropicTool: Encodable {
    let name: String
    let description: String
    let inputSchema: InputSchema
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }
    
    struct InputSchema: Encodable {
        let type: String
        let properties: [String: PropertySchema]
        let required: [String]
    }
    
    final class PropertySchema: Encodable, Sendable {
        let type: String
        let description: String
        let enumValues: [String]?
        let items: PropertySchema?
        
        init(type: String, description: String, enumValues: [String]?, items: PropertySchema?) {
            self.type = type
            self.description = description
            self.enumValues = enumValues
            self.items = items
        }
        
        enum CodingKeys: String, CodingKey {
            case type
            case description
            case enumValues = "enum"
            case items
        }
    }
}

// MARK: - Response Models

struct AnthropicResponse: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stopReason: String?
    let usage: AnthropicUsage
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }
}

struct AnthropicUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Streaming Models

struct AnthropicStreamEvent: Decodable {
    let type: String
    let message: AnthropicResponse?
    let index: Int?
    let contentBlock: ContentBlock?
    let delta: StreamDelta?
    let usage: AnthropicUsage?
    
    enum CodingKeys: String, CodingKey {
        case type, message, index, delta, usage
        case contentBlock = "content_block"
    }
}

struct StreamDelta: Decodable {
    let type: String? 
    let text: String?
    let stopReason: String?
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case stopReason = "stop_reason"
    }
    
    // Custom decoder to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        stopReason = try container.decodeIfPresent(String.self, forKey: .stopReason)
    }
}

// MARK: - Error Models

struct AnthropicError: Decodable, Error {
    let type: String
    let message: String
}

struct AnthropicErrorResponse: Decodable {
    let error: AnthropicError
}
