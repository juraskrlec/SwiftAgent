//
//  Tool.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// Protocol that all tools must implement
public protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: ToolParameters { get }
    
    func execute(arguments: [String: Any]) async throws -> String
}

/// Tool parameters schema
public struct ToolParameters: Codable, Sendable {
    public let type: String
    public let properties: [String: ParameterProperty]
    public let required: [String]
    
    public init(
        type: String = "object",
        properties: [String: ParameterProperty],
        required: [String] = []
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// Individual parameter property
public final class ParameterProperty: Codable, Sendable {
    public let type: String
    public let description: String
    public let enumValues: [String]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
    }
    
    public init(type: String, description: String, enumValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }
}

/// Tool execution errors
public enum ToolError: Error, LocalizedError {
    case executionFailed(String)
    case invalidArguments(String)
    case toolNotFound(String)
    case permissionDenied(String)
    
    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Tool execution failed: \(message)"
        case .invalidArguments(let message):
            return "Invalid tool arguments: \(message)"
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        }
    }
}
