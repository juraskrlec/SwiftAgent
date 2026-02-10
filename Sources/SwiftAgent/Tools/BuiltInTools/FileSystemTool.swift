//
//  FileSystemTool.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// A tool for reading and writing files
public struct FileSystemTool: Tool, Sendable {
    public let name = "file_system"
    public let description = "Read, write, list, or delete files in allowed directories. Operations: 'read', 'write', 'list', 'delete', 'exists'"
    
    private let allowedPaths: [String]
    
    public var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "operation": ParameterProperty(
                    type: "string",
                    description: "The operation to perform",
                    enumValues: ["read", "write", "list", "delete", "exists", "create_directory"]
                ),
                "path": ParameterProperty(
                    type: "string",
                    description: "File or directory path"
                ),
                "content": ParameterProperty(
                    type: "string",
                    description: "Content to write (for 'write' operation)"
                )
            ],
            required: ["operation", "path"]
        )
    }
    
    public init(allowedPaths: [String] = []) {
        self.allowedPaths = allowedPaths.isEmpty ? [FileManager.default.temporaryDirectory.path] : allowedPaths
    }
    
    public func execute(arguments: [String: Any]) async throws -> String {
        guard let operation = arguments["operation"] as? String else {
            throw ToolError.invalidArguments("Missing 'operation' parameter")
        }
        
        guard let path = arguments["path"] as? String else {
            throw ToolError.invalidArguments("Missing 'path' parameter")
        }
        
        // Get FileManager locally instead of storing it
        let fileManager = FileManager.default
        
        // Security check: ensure path is within allowed directories
        try validatePath(path)
        
        switch operation {
        case "read":
            return try readFile(at: path, fileManager: fileManager)
            
        case "write":
            guard let content = arguments["content"] as? String else {
                throw ToolError.invalidArguments("Missing 'content' parameter for write operation")
            }
            return try writeFile(at: path, content: content, fileManager: fileManager)
            
        case "list":
            return try listDirectory(at: path, fileManager: fileManager)
            
        case "delete":
            return try deleteFile(at: path, fileManager: fileManager)
            
        case "exists":
            return fileExists(at: path, fileManager: fileManager)
            
        case "create_directory":
            return try createDirectory(at: path, fileManager: fileManager)
            
        default:
            throw ToolError.invalidArguments("Unknown operation: \(operation)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func validatePath(_ path: String) throws {
        let expandedPath = (path as NSString).expandingTildeInPath
        
        // Check if path is within allowed directories
        let isAllowed = allowedPaths.contains { allowedPath in
            let expandedAllowed = (allowedPath as NSString).expandingTildeInPath
            return expandedPath.hasPrefix(expandedAllowed)
        }
        
        guard isAllowed else {
            throw ToolError.executionFailed("Access denied: path '\(path)' is not in allowed directories")
        }
    }
    
    private func readFile(at path: String, fileManager: FileManager) throws -> String {
        let expandedPath = (path as NSString).expandingTildeInPath
        
        guard fileManager.fileExists(atPath: expandedPath) else {
            throw ToolError.executionFailed("File not found: \(path)")
        }
        
        guard let content = fileManager.contents(atPath: expandedPath),
              let string = String(data: content, encoding: .utf8) else {
            throw ToolError.executionFailed("Failed to read file or file is not UTF-8 encoded")
        }
        
        return string
    }
    
    private func writeFile(at path: String, content: String, fileManager: FileManager) throws -> String {
        let expandedPath = (path as NSString).expandingTildeInPath
        
        guard let data = content.data(using: .utf8) else {
            throw ToolError.executionFailed("Failed to encode content")
        }
        
        let url = URL(fileURLWithPath: expandedPath)
        
        // Create parent directory if needed
        let parentDir = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        
        try data.write(to: url)
        
        return "Successfully wrote \(data.count) bytes to \(path)"
    }
    
    private func listDirectory(at path: String, fileManager: FileManager) throws -> String {
        let expandedPath = (path as NSString).expandingTildeInPath
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ToolError.executionFailed("Directory not found: \(path)")
        }
        
        let contents = try fileManager.contentsOfDirectory(atPath: expandedPath)
        
        if contents.isEmpty {
            return "Directory is empty"
        }
        
        return "Contents of \(path):\n" + contents.map { "- \($0)" }.joined(separator: "\n")
    }
    
    private func deleteFile(at path: String, fileManager: FileManager) throws -> String {
        let expandedPath = (path as NSString).expandingTildeInPath
        
        guard fileManager.fileExists(atPath: expandedPath) else {
            throw ToolError.executionFailed("File not found: \(path)")
        }
        
        try fileManager.removeItem(atPath: expandedPath)
        
        return "Successfully deleted: \(path)"
    }
    
    private func fileExists(at path: String, fileManager: FileManager) -> String {
        let expandedPath = (path as NSString).expandingTildeInPath
        let exists = fileManager.fileExists(atPath: expandedPath)
        return exists ? "File exists: \(path)" : "File does not exist: \(path)"
    }
    
    private func createDirectory(at path: String, fileManager: FileManager) throws -> String {
        let expandedPath = (path as NSString).expandingTildeInPath
        
        try fileManager.createDirectory(
            atPath: expandedPath,
            withIntermediateDirectories: true
        )
        
        return "Successfully created directory: \(path)"
    }
}
