//
//  LLMResponse.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

public enum StopReason: String, Sendable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
    case toolUse = "tool_use"
}

/// Response from an LLM provider
public struct LLMResponse: Sendable {
    
    public let id: String
    public let content: String
    public let toolCalls: [ToolCall]?
    public let stopReason: StopReason
    public let usage: TokenUsage?
    
    public init(
        id: String = UUID().uuidString,
        content: String,
        toolCalls: [ToolCall]? = nil,
        stopReason: StopReason = .endTurn,
        usage: TokenUsage? = nil
    ) {
        self.id = id
        self.content = content
        self.toolCalls = toolCalls
        self.stopReason = stopReason
        self.usage = usage
    }
}

/// Token usage information
public struct TokenUsage: Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    
    public var totalTokens: Int {
        inputTokens + outputTokens
    }
    
    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

/// Streaming chunk from an LLM provider
public struct LLMChunk: Sendable {
    public enum ChunkType: Sendable {
        case content(String)
        case toolCall(ToolCall)
        case done(StopReason)
    }
    
    public let type: ChunkType
    public let usage: TokenUsage?
    
    public init(type: ChunkType, usage: TokenUsage? = nil) {
        self.type = type
        self.usage = usage
    }
}
