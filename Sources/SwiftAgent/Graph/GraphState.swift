//
//  GraphState.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// State that flows through the graph
public struct GraphState: Codable, Sendable {
    public var messages: [Message]
    public var data: [String: AnyCodable]
    public var currentNode: String?
    public var visitedNodes: [String]
    
    public init(
        messages: [Message] = [],
        data: [String: AnyCodable] = [:],
        currentNode: String? = nil,
        visitedNodes: [String] = []
    ) {
        self.messages = messages
        self.data = data
        self.currentNode = currentNode
        self.visitedNodes = visitedNodes
    }
    
    public mutating func addMessage(_ message: Message) {
        messages.append(message)
    }
    
    public mutating func setValue(_ value: AnyCodable, forKey key: String) {
        data[key] = value
    }
    
    public func getValue(forKey key: String) -> AnyCodable? {
        return data[key]
    }
    
    public mutating func markNodeVisited(_ nodeName: String) {
        visitedNodes.append(nodeName)
        currentNode = nodeName
    }
}

/// Events emitted during graph execution
public enum GraphEvent: Sendable {
    case nodeStarted(String)
    case nodeCompleted(String, GraphState)
    case edgeTraversed(from: String, to: String)
    case graphCompleted(GraphState)
    case error(Error)
}
