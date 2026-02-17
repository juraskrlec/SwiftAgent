//
//  AppleIntelligenceProvider.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Apple Intelligence (on-device) LLM Provider using Foundation Models
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public actor AppleIntelligenceProvider: LLMProvider {
    
    private let instructions: Instructions?
    private let maxContextTokens: Int
    
    /// Maximum context window for Apple Intelligence is 4096
    /// Set maxContextTokens and make buffer for reponse
    ///
    /// See: https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window
    public init(instructions: String? = nil, maxContextTokens: Int = 2000) async throws {
        if let instructions = instructions {
            self.instructions = Instructions { instructions }
        } else {
            self.instructions = nil
        }
        self.maxContextTokens = maxContextTokens
    }
    
    public func generate(messages: [Message], tools: [Tool]?, options: GenerationOptions) async throws -> LLMResponse {
        
        let trimmedMessages = trimMessages(messages)
        
        // Build prompt from messages
        let prompt = buildPrompt(from: trimmedMessages)
        
        let nativeTools: [any FMTool]? = tools.flatMap { mapToFMTool($0) }
        
        // Create session (tools will be handled by the agent layer)
        let session = createSession(with: nativeTools)
                
        // Prewarm for better performance
        session.prewarm()
        
        // Generate response
        let response = try await session.respond(to: prompt, options: .init(maximumResponseTokens: options.maxTokens))
        
        // Return response
        return LLMResponse(
            id: UUID().uuidString,
            content: response.content,
            toolCalls: nil,
            stopReason: .endTurn,
            usage: nil
        )
    }
    
    public func stream(messages: [Message], tools: [Tool]?, options: GenerationOptions) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        let prompt = buildPrompt(from: messages)
        
        let nativeTools: [any FMTool]? = tools.flatMap { mapToFMTool($0) }
        
        let session = createSession(with: nativeTools)
        
        session.prewarm()
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in session.streamResponse(to: prompt, options: .init(maximumResponseTokens: options.maxTokens)) {
                        continuation.yield(LLMChunk(type: .content(chunk.content)))
                    }
                    continuation.yield(LLMChunk(type: .done(.endTurn)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Context Management
    
    private func mapToFMTool(_ tools: [Tool]?) -> [any FMTool]? {
        return tools.map { FoundationModelToolFactory.wrap($0) }
    }
    
    private func trimMessages(_ messages: [Message]) -> [Message] {
        // Estimate tokens (rough approximation: 1 token ≈ 4 characters)
        var totalChars = 0
        var trimmedMessages: [Message] = []
        
        // Keep system message always
        if let systemMsg = messages.first(where: { $0.role == .system }) {
            trimmedMessages.append(systemMsg)
            totalChars += systemMsg.content.count
        }
        
        // Keep the most recent messages that fit
        let maxChars = maxContextTokens * 4 // Rough estimate
        let nonSystemMessages = messages.filter { $0.role != .system }
        
        // Iterate from most recent to oldest
        for message in nonSystemMessages.reversed() {
            let messageChars = message.content.count
            
            if totalChars + messageChars <= maxChars {
                trimmedMessages.insert(message, at: trimmedMessages.count)
                totalChars += messageChars
            } else {
                // Stop adding messages if we exceed the limit
                break
            }
        }
        
        return trimmedMessages
    }
    
    // MARK: - Private Helpers
    
    private func createSession(with tools: [any FMTool]?) -> LanguageModelSession {
        if let tools = tools, !tools.isEmpty, let instructions = instructions {
            return LanguageModelSession(
                tools: tools, instructions: instructions
            )
        } else if let tools = tools, !tools.isEmpty {
            return LanguageModelSession(tools: tools)
        } else if let instructions = instructions {
            return LanguageModelSession(instructions: instructions)
        } else {
            return LanguageModelSession()
        }
    }
    
    private func buildPrompt(from messages: [Message]) -> Prompt {
        var promptText = ""
        
        for message in messages {
            switch message.role {
            case .system:
                promptText += "System: \(message.content)\n\n"
            case .user:
                promptText += "User: \(message.content)\n\n"
            case .assistant:
                promptText += "Assistant: \(message.content)\n\n"
            case .tool:
                promptText += "Tool Result: \(message.content)\n\n"
            }
        }
        
        return Prompt { promptText }
    }
}

#else

// Fallback for platforms that don't support Foundation Models
public actor AppleIntelligenceProvider: LLMProvider {
    public init(instructions: String? = nil) async throws {
        throw LLMError.apiError("Apple Intelligence (Foundation Models) is not available on this platform. Requires iOS 26.0+, macOS 26.0+")
    }
    
    public func generate(
        messages: [Message],
        tools: [Tool]?,
        options: GenerationOptions
    ) async throws -> LLMResponse {
        throw LLMError.apiError("Apple Intelligence is not available on this platform")
    }
    
    public func stream(
        messages: [Message],
        tools: [Tool]?,
        options: GenerationOptions
    ) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        throw LLMError.apiError("Apple Intelligence is not available on this platform")
    }
}

#endif
