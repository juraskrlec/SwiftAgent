//
//  Message.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// Represents a message in a conversation
public struct Message: Codable, Sendable, Equatable {
    public enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
        case tool
    }
    
    public enum ContentPart: Sendable, Codable, Equatable {
        case text(String)
        case image(ImageContent)
        
        enum CodingKeys: CodingKey {
            case type
            case text
            case image
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
                
            case .image(let imageContent):
                try container.encode("image", forKey: .type)
                try container.encode(imageContent, forKey: .image)
            }
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "text":
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
                
            case "image":
                let image = try container.decode(ImageContent.self, forKey: .image)
                self = .image(image)
                
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown content type: \(type)"
                )
            }
        }
    }
    
    public struct ImageContent: Sendable, Codable, Equatable {
        public let data: Data
        public let mimeType: String  // "image/jpeg", "image/png", "image/webp"
        public let detail: ImageDetail?  // Optional: high/low quality for OpenAI
        
        public enum ImageDetail: String, Sendable, Codable {
            case low
            case high
            case auto
        }
        
        public init(data: Data, mimeType: String = "image/jpeg", detail: ImageDetail? = nil) {
            self.data = data
            self.mimeType = mimeType
            self.detail = detail
        }
    }
    
    public let id: String
    public let role: Role
    public let content: [ContentPart]
    public let toolCallId: String?
    public let toolCalls: [ToolCall]?
    public let timestamp: Date
    public let thoughtSignature: String? // Gemini 3
    
    public init(id: String = UUID().uuidString,
                role: Role,
                content: [ContentPart],
                toolCalls: [ToolCall]? = nil,
                toolCallId: String? = nil,
                timestamp: Date = Date(),
                thoughtSignature: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.thoughtSignature = thoughtSignature
        self.timestamp = timestamp
    }
    
    public init(id: String = UUID().uuidString,
                role: Role,
                content: String,
                toolCallId: String? = nil,
                toolCalls: [ToolCall]? = nil,
                timestamp: Date = Date(),
                thoughtSignature: String? = nil) {
        self.id = id
        self.role = role
        self.content = [.text(content)]
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
        self.timestamp = timestamp
        self.thoughtSignature = thoughtSignature
    }
    
    // Convenience constructors
    public static func system(_ content: String) -> Message {
        Message(role: .system, content: content)
    }
    
    public static func user(_ content: String) -> Message {
        Message(role: .user, content: content)
    }
    
    public static func user(_ text: String, images: [ImageContent]) -> Message {
        var parts: [ContentPart] = [.text(text)]
        parts.append(contentsOf: images.map { .image($0) })
        return Message(role: .user, content: parts)
    }
    
    public static func user(_ text: String, image: ImageContent) -> Message {
        return user(text, images: [image])
    }
    
    public static func assistant(_ content: String, toolCalls: [ToolCall]? = nil, thoughtSignature: String? = nil) -> Message {
        Message(role: .assistant, content: content, toolCalls: toolCalls, thoughtSignature: thoughtSignature)
    }
    
    public static func tool(_ content: String, toolCallId: String) -> Message {
        Message(role: .tool, content: content, toolCallId: toolCallId)
    }
    
    public var textContent: String {
        content.compactMap {
            if case .text(let text) = $0 { return text }
            return nil
        }.joined(separator: "\n")
    }
        
    public var images: [ImageContent] {
        content.compactMap {
            if case .image(let img) = $0 { return img }
            return nil
        }
    }
}

/// Represents a tool call made by the assistant
public struct ToolCall: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let arguments: [String: AnyCodable]
    public let thoughtSignature: String? // Gemini 3
    
    public init(id: String, name: String, arguments: [String: AnyCodable], thoughtSignature: String? = nil) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.thoughtSignature = thoughtSignature
    }
}

/// Helper to handle dynamic values in Codable contexts
public enum AnyCodable: Codable, Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])
    case null
    
    public init(_ value: Any?) {
        guard let value = value else {
            self = .null
            return
        }
        
        switch value {
        case let bool as Bool:
            self = .bool(bool)
        case let int as Int:
            self = .int(int)
        case let double as Double:
            self = .double(double)
        case let string as String:
            self = .string(string)
        case let array as [Any]:
            self = .array(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            self = .dictionary(dictionary.mapValues { AnyCodable($0) })
        default:
            // Fallback to string representation
            self = .string(String(describing: value))
        }
    }
    
    public var value: Any {
        switch self {
        case .bool(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .string(let value):
            return value
        case .array(let value):
            return value.map { $0.value }
        case .dictionary(let value):
            return value.mapValues { $0.value }
        case .null:
            return NSNull()
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// Helper extensions for easier value extraction
extension AnyCodable {
    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
    
    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }
    
    public var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }
    
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    public var arrayValue: [AnyCodable]? {
        if case .array(let value) = self { return value }
        return nil
    }
    
    public var dictionaryValue: [String: AnyCodable]? {
        if case .dictionary(let value) = self { return value }
        return nil
    }
}
