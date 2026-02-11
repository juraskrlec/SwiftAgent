//
//  VectorSearchTool.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

/// A tool for semantic search over a vector database
public struct VectorSearchTool: Tool, Sendable {
    public let name = "search_knowledge_base"
    public let description = "Search through the knowledge base for relevant information. Use this when you need context or information to answer questions accurately."
    
    private let vectorStore: VectorStore
    private let defaultTopK: Int
    
    public var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "query": ParameterProperty(
                    type: "string",
                    description: "The search query to find relevant information in the knowledge base"
                ),
                "limit": ParameterProperty(
                    type: "integer",
                    description: "Maximum number of results to return (default: \(defaultTopK))"
                )
            ],
            required: ["query"]
        )
    }
    
    public init(vectorStore: VectorStore, defaultTopK: Int = 5) {
        self.vectorStore = vectorStore
        self.defaultTopK = defaultTopK
    }
    
    public func execute(arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String else {
            throw ToolError.invalidArguments("Missing 'query' parameter")
        }
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolError.invalidArguments("Query cannot be empty")
        }
        
        // Handle limit parameter
        let limit: Int
        if let limitArg = arguments["limit"] as? Int {
            limit = max(1, min(limitArg, 20))
        } else if let limitArg = arguments["limit"] as? Double {
            limit = max(1, min(Int(limitArg), 20))
        } else {
            limit = defaultTopK
        }
        
        // Search the vector store
        let results = try await vectorStore.search(query: query, topK: limit)
        
        guard !results.isEmpty else {
            return "No relevant information found in the knowledge base for query: '\(query)'"
        }
        
        // Format results for the LLM
        let formattedResults = results.enumerated().map { index, result in
            var output = "[Document \(index + 1)] (Relevance: \(String(format: "%.2f", result.score)))\n"
            output += result.content
            
            if !result.metadata.isEmpty {
                let metadataStr = result.metadata
                    .filter { $0.key != "chunk_index" && $0.key != "chunk_count" }
                    .map { "\($0.key): \($0.value)" }
                    .joined(separator: ", ")
                
                if !metadataStr.isEmpty {
                    output += "\nMetadata: \(metadataStr)"
                }
            }
            
            return output
        }.joined(separator: "\n\n---\n\n")
        
        return """
        Found \(results.count) relevant document(s):
        
        \(formattedResults)
        """
    }
}
