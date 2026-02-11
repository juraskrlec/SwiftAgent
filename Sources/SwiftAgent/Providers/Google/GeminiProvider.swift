//
//  GeminiProvider.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

/// Google Gemini LLM Provider
public actor GeminiProvider: LLMProvider {
    public enum Model: String, Sendable {
        case gemini3Pro = "gemini-3-pro-preview"
        case gemini3Flash = "gemini-3-flash-preview"
        case gemini25Flash = "gemini-2.5-flash"
        case gemini25FlashLite = "gemini-2.5-flash-lite"
        case gemini25Pro = "gemini-2.5-pro"
    }
    
    private let api: GeminiAPI
    private let model: Model
    private let defaultMaxTokens: Int
    
    public init(
        apiKey: String,
        model: Model = .gemini25Flash,
        defaultMaxTokens: Int = 8192
    ) {
        self.api = GeminiAPI(apiKey: apiKey)
        self.model = model
        self.defaultMaxTokens = defaultMaxTokens
    }
    
    public func generate(
        messages: [Message],
        tools: [Tool]?,
        options: GenerationOptions
    ) async throws -> LLMResponse {
        let request = try buildRequest(
            messages: messages,
            tools: tools,
            options: options
        )
        
        let response = try await api.sendRequest(request, model: model.rawValue)
        return try convertResponse(response)
    }
    
    public func stream(
        messages: [Message],
        tools: [Tool]?,
        options: GenerationOptions
    ) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        let request = try buildRequest(
            messages: messages,
            tools: tools,
            options: options
        )
        
        let eventStream = try await api.streamRequest(request, model: model.rawValue)
        
        return AsyncThrowingStream { continuation in
            Task {
                var currentToolCalls: [String: ToolCallBuilder] = [:]
                
                do {
                    for try await chunk in eventStream {
                        guard let candidate = chunk.candidates?.first,
                              let content = candidate.content else {
                            continue
                        }
                        
                        for part in content.parts {
                            // Handle text content
                            if let text = part.text {
                                continuation.yield(LLMChunk(type: .content(text)))
                            }
                            
                            // Handle function calls
                            if let functionCall = part.functionCall {
                                let callId = UUID().uuidString
                                
                                if currentToolCalls[callId] == nil {
                                    currentToolCalls[callId] = ToolCallBuilder(
                                        id: callId,
                                        name: functionCall.name,
                                        arguments: [:]
                                    )
                                }
                                
                                currentToolCalls[callId]?.arguments = functionCall.args
                            }
                        }
                        
                        // Handle finish
                        if let finishReason = candidate.finishReason {
                            // Emit complete tool calls
                            for (_, builder) in currentToolCalls {
                                if let toolCall = builder.build() {
                                    continuation.yield(LLMChunk(type: .toolCall(toolCall)))
                                }
                            }
                            
                            let stopReason = convertFinishReason(finishReason)
                            continuation.yield(LLMChunk(type: .done(stopReason)))
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func buildRequest(
        messages: [Message],
        tools: [Tool]?,
        options: GenerationOptions
    ) throws -> GeminiRequest {
        // Convert messages to Gemini format
        var contents: [GeminiRequest.Content] = []
        var currentRole = "user"
        var currentParts: [GeminiRequest.Part] = []
        
        for message in messages {
            let role: String
            switch message.role {
            case .system:
                // Gemini doesn't have system role, add as first user message
                role = "user"
            case .user:
                role = "user"
            case .assistant:
                role = "model"
            case .tool:
                role = "function"
            }
            
            // If role changes, save current content and start new
            if role != currentRole && !currentParts.isEmpty {
                contents.append(GeminiRequest.Content(role: currentRole, parts: currentParts))
                currentParts = []
            }
            currentRole = role
            
            // Convert message content
            if message.role == .tool {
                // Tool result
                if let toolCallId = message.toolCallId {
                    currentParts.append(GeminiRequest.Part(
                        text: nil,
                        functionCall: nil,
                        functionResponse: GeminiRequest.FunctionResponse(
                            name: toolCallId,
                            response: ["result": AnyCodable(message.content)]
                        )
                    ))
                }
            } else if let toolCalls = message.toolCalls {
                // Tool calls
                for toolCall in toolCalls {
                    currentParts.append(GeminiRequest.Part(
                        text: nil,
                        functionCall: GeminiRequest.FunctionCall(
                            name: toolCall.name,
                            args: toolCall.arguments
                        ),
                        functionResponse: nil
                    ))
                }
            } else {
                // Regular text
                currentParts.append(GeminiRequest.Part(
                    text: message.content,
                    functionCall: nil,
                    functionResponse: nil
                ))
            }
        }
        
        // Add last content
        if !currentParts.isEmpty {
            contents.append(GeminiRequest.Content(role: currentRole, parts: currentParts))
        }
        
        // Convert tools
        var geminiTools: [GeminiRequest.Tool]?
        if let tools = tools, !tools.isEmpty {
            let functionDeclarations = tools.map { tool -> GeminiRequest.FunctionDeclaration in
                let properties = tool.parameters.properties.mapValues { param in
                    GeminiRequest.FunctionDeclaration.PropertySchema(
                        type: param.type,
                        description: param.description,
                        enumValues: param.enumValues
                    )
                }
                
                return GeminiRequest.FunctionDeclaration(
                    name: tool.name,
                    description: tool.description,
                    parameters: GeminiRequest.FunctionDeclaration.Parameters(
                        type: "object",
                        properties: properties,
                        required: tool.parameters.required
                    )
                )
            }
            
            geminiTools = [GeminiRequest.Tool(functionDeclarations: functionDeclarations)]
        }
        
        // Generation config
        let generationConfig = GeminiRequest.GenerationConfig(
            temperature: options.temperature,
            topP: options.topP,
            topK: nil,
            maxOutputTokens: options.maxTokens ?? defaultMaxTokens,
            stopSequences: options.stopSequences
        )
        
        return GeminiRequest(
            contents: contents,
            generationConfig: generationConfig,
            tools: geminiTools
        )
    }
    
    private func convertResponse(_ response: GeminiResponse) throws -> LLMResponse {
        guard let candidate = response.candidates.first else {
            throw LLMError.invalidResponse
        }
        
        var textContent = ""
        var toolCalls: [ToolCall] = []
        
        for part in candidate.content.parts {
            if let text = part.text {
                textContent += text
            }
            
            if let functionCall = part.functionCall {
                toolCalls.append(ToolCall(
                    id: UUID().uuidString,
                    name: functionCall.name,
                    arguments: functionCall.args
                ))
            }
        }
        
        let stopReason = convertFinishReason(candidate.finishReason ?? "STOP")
        
        let usage = response.usageMetadata.map { metadata in
            TokenUsage(
                inputTokens: metadata.promptTokenCount ?? 0,
                outputTokens: metadata.candidatesTokenCount ?? 0
            )
        }
        
        return LLMResponse(
            id: UUID().uuidString,
            content: textContent,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            stopReason: stopReason,
            usage: usage
        )
    }
    
    private func convertFinishReason(_ reason: String) -> StopReason {
        switch reason.uppercased() {
        case "STOP":
            return .endTurn
        case "MAX_TOKENS":
            return .maxTokens
        case "SAFETY", "RECITATION":
            return .stopSequence
        default:
            return .endTurn
        }
    }
}

// MARK: - Tool Call Builder for Streaming

private class ToolCallBuilder {
    var id: String
    var name: String
    var arguments: [String: AnyCodable]
    
    init(id: String, name: String, arguments: [String: AnyCodable]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
    
    func build() -> ToolCall? {
        guard !id.isEmpty, !name.isEmpty else { return nil }
        
        return ToolCall(
            id: id,
            name: name,
            arguments: arguments
        )
    }
}
