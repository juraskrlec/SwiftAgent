//
//  AgentResult.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// The result of an agent's execution
public struct AgentResult: Sendable {
    public let output: String
    public let state: AgentState
    public let totalTokens: Int
    public let success: Bool
    public let error: Error?
    
    public init(output: String, state: AgentState, totalTokens: Int = 0, success: Bool = true, error: Error? = nil) {
        self.output = output
        self.state = state
        self.totalTokens = totalTokens
        self.success = success
        self.error = error
    }
}

/// Events emitted during agent streaming
public enum AgentEvent: Sendable {
    case thinking(String)
    case toolCall(ToolCall)
    case toolResult(String, toolCallId: String)
    case response(String)
    case completed(AgentResult)
    case error(Error)
}
