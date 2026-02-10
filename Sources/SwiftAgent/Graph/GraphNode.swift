//
//  GraphNode.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// A node in the agent graph
public enum GraphNode: Sendable {
    case agent(Agent)
    case function(@Sendable (GraphState) async throws -> GraphState)
    
    public func execute(state: GraphState) async throws -> GraphState {
        switch self {
        case .agent(let agent):
            // Extract the last user message or use a default
            let task = state.messages.last(where: { $0.role == .user })?.content ?? "Continue the task"
            
            let result = try await agent.run(task: task)
            
            var newState = state
            newState.messages.append(contentsOf: result.state.messages)
            newState.setValue(.int(result.totalTokens), forKey: "total_tokens")
            
            return newState
            
        case .function(let fn):
            return try await fn(state)
        }
    }
}

/// Special node markers
public enum SpecialNode: String {
    case START = "__start__"
    case END = "__end__"
}
