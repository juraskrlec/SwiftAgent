//
//  JSONParserTool.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// A tool for parsing, validating, and extracting data from JSON
public struct JSONParserTool: Tool {
    public let name = "json_parser"
    public let description = "Parse JSON strings, extract values by key path, validate JSON structure, or pretty-print JSON"
    
    public var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "operation": ParameterProperty(
                    type: "string",
                    description: "The operation to perform",
                    enumValues: ["parse", "extract", "validate", "pretty_print"]
                ),
                "json": ParameterProperty(
                    type: "string",
                    description: "JSON string to process"
                ),
                "key_path": ParameterProperty(
                    type: "string",
                    description: "Dot-notation key path for extraction (e.g., 'user.profile.name')"
                )
            ],
            required: ["operation", "json"]
        )
    }
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> String {
        guard let operation = arguments["operation"] as? String else {
            throw ToolError.invalidArguments("Missing 'operation' parameter")
        }
        
        guard let jsonString = arguments["json"] as? String else {
            throw ToolError.invalidArguments("Missing 'json' parameter")
        }
        
        switch operation {
        case "parse":
            return try parseJSON(jsonString)
            
        case "extract":
            guard let keyPath = arguments["key_path"] as? String else {
                throw ToolError.invalidArguments("Missing 'key_path' parameter")
            }
            return try extractValue(from: jsonString, keyPath: keyPath)
            
        case "validate":
            return try validateJSON(jsonString)
            
        case "pretty_print":
            return try prettyPrint(jsonString)
            
        default:
            throw ToolError.invalidArguments("Unknown operation: \(operation)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func parseJSON(_ jsonString: String) throws -> String {
        guard let data = jsonString.data(using: .utf8) else {
            throw ToolError.executionFailed("Failed to convert string to data")
        }
        
        let json = try JSONSerialization.jsonObject(with: data)
        return "Successfully parsed JSON. Type: \(type(of: json))"
    }
    
    private func extractValue(from jsonString: String, keyPath: String) throws -> String {
        guard let data = jsonString.data(using: .utf8) else {
            throw ToolError.executionFailed("Failed to convert string to data")
        }
        
        let json = try JSONSerialization.jsonObject(with: data)
        let keys = keyPath.split(separator: ".").map(String.init)
        
        var current: Any = json
        for key in keys {
            if let dict = current as? [String: Any] {
                guard let value = dict[key] else {
                    throw ToolError.executionFailed("Key '\(key)' not found")
                }
                current = value
            } else if let array = current as? [Any], let index = Int(key) {
                guard index < array.count else {
                    throw ToolError.executionFailed("Index \(index) out of bounds")
                }
                current = array[index]
            } else {
                throw ToolError.executionFailed("Cannot navigate through \(type(of: current))")
            }
        }
        
        if let string = current as? String {
            return string
        } else if let number = current as? NSNumber {
            return number.stringValue
        } else {
            let data = try JSONSerialization.data(withJSONObject: current, options: [.prettyPrinted])
            return String(data: data, encoding: .utf8) ?? String(describing: current)
        }
    }
    
    private func validateJSON(_ jsonString: String) throws -> String {
        guard let data = jsonString.data(using: .utf8) else {
            return "Invalid: Not valid UTF-8 string"
        }
        
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return "Valid JSON"
        } catch {
            return "Invalid JSON: \(error.localizedDescription)"
        }
    }
    
    private func prettyPrint(_ jsonString: String) throws -> String {
        guard let data = jsonString.data(using: .utf8) else {
            throw ToolError.executionFailed("Failed to convert string to data")
        }
        
        let json = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        
        guard let prettyString = String(data: prettyData, encoding: .utf8) else {
            throw ToolError.executionFailed("Failed to create pretty-printed string")
        }
        
        return prettyString
    }
}
