//
//  ThinkingLevel.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 18.02.2026..
//


import Foundation

/// Thinking level for Gemini 3+ models
/// Controls the depth of reasoning and thought process
public enum ThinkingLevel: String, Sendable {
    /// Minimal thinking - fastest, best for simple tasks
    /// Note: minimal does not guarantee that thinking is off
    case minimal = "minimal"
    
    /// Low thinking - balanced speed and reasoning
    /// Best for simple instruction following, chat, or high-throughput applications
    case low = "low"
    
    /// Medium thinking - balanced thinking for most tasks
    case medium = "medium"
    
    /// High thinking - maximum reasoning depth (default for Gemini 3)
    /// The model may take significantly longer to reach first output token
    case high = "high"
    
    /// Automatic - let the model decide (dynamic)
    case auto = "auto"
}
