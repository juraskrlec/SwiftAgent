//
//  AgentState.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// Represents the current state of an agent's execution
public struct AgentState: Codable, Sendable {
    public var messages: [Message]
    public var iterations: Int
    public var metadata: [String: String]
    
    public init(
        messages: [Message] = [],
        iterations: Int = 0,
        metadata: [String: String] = [:]
    ) {
        self.messages = messages
        self.iterations = iterations
        self.metadata = metadata
    }
    
    public mutating func addMessage(_ message: Message) {
        messages.append(message)
    }
    
    public mutating func addMessages(_ newMessages: [Message]) {
        messages.append(contentsOf: newMessages)
    }
    
    public mutating func incrementIteration() {
        iterations += 1
    }
}
