//
//  AgentPrompt.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 08.03.2026..
//

import Foundation

/// Loads agent system prompts and instructions from markdown files
public struct AgentPrompt {
    
    /// Load system prompt from a markdown file
    /// - Parameter path: Path to the .md file
    /// - Returns: The content of the file as a string
    public static func load(fromFile path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw AgentPromptError.fileNotFound(path)
        }
        
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    /// Load system prompt from a markdown file in the bundle
    /// - Parameters:
    ///   - filename: Name of the file (without .md extension)
    ///   - bundle: Bundle to search in (defaults to main bundle)
    /// - Returns: The content of the file as a string
    public static func load(fromBundle filename: String, bundle: Bundle = .main) throws -> String {
        guard let url = bundle.url(forResource: filename, withExtension: "md") else {
            throw AgentPromptError.fileNotFound("\(filename).md")
        }
        
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    /// Load and merge multiple prompt files
    /// - Parameter paths: Array of file paths
    /// - Returns: Merged content with separators
    public static func loadMultiple(fromFiles paths: [String], separator: String = "\n\n---\n\n") throws -> String {
        var contents: [String] = []
        
        for path in paths {
            let content = try load(fromFile: path)
            contents.append(content)
        }
        
        return contents.joined(separator: separator)
    }
    
    /// Load prompt with variable substitution
    /// - Parameters:
    ///   - path: Path to the .md file
    ///   - variables: Dictionary of variables to substitute (e.g., ["name": "Alice"])
    /// - Returns: Content with variables replaced
    public static func load(fromFile path: String, variables: [String: String]) throws -> String {
        var content = try load(fromFile: path)
        
        // Replace {{variable}} with values
        for (key, value) in variables {
            content = content.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        return content
    }
    
    /// Parse frontmatter and content from markdown file
    /// - Parameter path: Path to the .md file
    /// - Returns: Tuple of frontmatter metadata and content
    public static func loadWithFrontmatter(fromFile path: String) throws -> (metadata: [String: String], content: String) {
        let fullContent = try load(fromFile: path)
        
        // Check for YAML frontmatter (between --- delimiters)
        let lines = fullContent.components(separatedBy: .newlines)
        
        guard lines.first == "---" else {
            // No frontmatter, return empty metadata
            return ([:], fullContent)
        }
        
        // Find closing ---
        var frontmatterLines: [String] = []
        var contentLines: [String] = []
        var inFrontmatter = false
        var frontmatterClosed = false
        
        for (index, line) in lines.enumerated() {
            if index == 0 {
                inFrontmatter = true
                continue
            }
            
            if line == "---" && inFrontmatter {
                inFrontmatter = false
                frontmatterClosed = true
                continue
            }
            
            if inFrontmatter {
                frontmatterLines.append(line)
            } else if frontmatterClosed {
                contentLines.append(line)
            }
        }
        
        // Parse frontmatter (simple key: value format)
        var metadata: [String: String] = [:]
        for line in frontmatterLines {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                metadata[key] = value
            }
        }
        
        let content = contentLines.joined(separator: "\n")
        
        return (metadata, content)
    }
}

/// Errors for agent prompt loading
public enum AgentPromptError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidFormat(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Prompt file not found: \(path)"
        case .invalidFormat(let message):
            return "Invalid prompt format: \(message)"
        }
    }
}
