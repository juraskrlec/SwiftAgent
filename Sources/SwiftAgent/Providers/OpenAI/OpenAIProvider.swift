//
//  OpenAIProvider.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// OpenAI/ChatGPT LLM Provider
public actor OpenAIProvider: LLMProvider {
    public enum Model: String, Sendable {
        case gpt52 = "gpt-5.2"
        case gpt52Mini = "gpt-5.2-mini"
        case gpt52Nano = "gpt-5.2-nano"
        case gpt51 = "gpt-5.1"
        case gpt51Mini = "gpt-5-mini"
        case gpt51Nano = "gpt-5-nano"
        case gpt41 = "gpt-4.1"
        case gpt41Mini = "gpt-4.1-mini"
        case gpt41Nano = "gpt-4.1-nano"
    }
    
    private let api: OpenAIAPI
    private let model: Model
    private let defaultMaxTokens: Int
    
    public init(
        apiKey: String,
        model: Model = .gpt51Mini,
        defaultMaxTokens: Int = 4096
    ) {
        self.api = OpenAIAPI(apiKey: apiKey)
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
            options: options,
            stream: false
        )
        
        let response = try await api.sendRequest(request)
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
            options: options,
            stream: true
        )
        
        let eventStream = try await api.streamRequest(request)
        
        return AsyncThrowingStream { continuation in
            Task {
                var toolCallsBuffer: [Int: ToolCallBuilder] = [:]
                
                do {
                    for try await chunk in eventStream {
                        guard let choice = chunk.choices.first else { continue }
                        
                        // Handle content delta
                        if let content = choice.delta.content {
                            continuation.yield(LLMChunk(type: .content(content)))
                        }
                        
                        // Handle tool calls delta
                        if let toolCallDeltas = choice.delta.toolCalls {
                            for toolCallDelta in toolCallDeltas {
                                let index = toolCallDelta.index
                                
                                if toolCallsBuffer[index] == nil {
                                    toolCallsBuffer[index] = ToolCallBuilder(
                                        id: toolCallDelta.id ?? "",
                                        name: toolCallDelta.function?.name ?? "",
                                        arguments: ""
                                    )
                                }
                                
                                if let name = toolCallDelta.function?.name {
                                    toolCallsBuffer[index]?.name = name
                                }
                                
                                if let args = toolCallDelta.function?.arguments {
                                    toolCallsBuffer[index]?.arguments += args
                                }
                            }
                        }
                        
                        // Handle finish
                        if let finishReason = choice.finishReason {
                            // Emit complete tool calls
                            for (_, builder) in toolCallsBuffer.sorted(by: { $0.key < $1.key }) {
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
        options: GenerationOptions,
        stream: Bool
    ) throws -> OpenAIRequest {
        // Convert messages
        let openAIMessages = try messages.map { message -> OpenAIMessage in
            try convertMessage(message)
        }
        
        // Convert tools
        let openAITools = tools?.map { tool -> OpenAITool in
            convertTool(tool)
        }
                
        return OpenAIRequest(
            model: model.rawValue,
            messages: openAIMessages,
            maxCompletionTokens: options.maxTokens ?? defaultMaxTokens,
            temperature: options.temperature,
            topP: options.topP,
            stop: options.stopSequences,
            tools: openAITools,
            stream: stream
        )
    }
    
    private func convertMessage(_ message: Message) throws -> OpenAIMessage {
        let role: String
        switch message.role {
        case .system:
            role = "system"
        case .user:
            role = "user"
        case .assistant:
            role = "assistant"
        case .tool:
            role = "tool"
        }
        
        // Handle tool results
        if message.role == .tool {
            return OpenAIMessage(
                role: role,
                content: message.content,
                toolCalls: nil,
                toolCallId: message.toolCallId
            )
        }
        
        // Handle assistant with tool calls
        if message.role == .assistant, let toolCalls = message.toolCalls {
            let openAIToolCalls = toolCalls.map { toolCall -> OpenAIToolCall in
                // Convert arguments to JSON string
                let argsDict = toolCall.arguments.mapValues { $0.value }
                let argsData = try? JSONSerialization.data(withJSONObject: argsDict)
                let argsString = argsData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                
                return OpenAIToolCall(
                    id: toolCall.id,
                    type: "function",
                    function: OpenAIFunction(
                        name: toolCall.name,
                        arguments: argsString
                    )
                )
            }
            
            return OpenAIMessage(
                role: role,
                content: message.content.isEmpty ? nil : message.content,
                toolCalls: openAIToolCalls,
                toolCallId: nil
            )
        }
        
        // Regular message
        return OpenAIMessage(
            role: role,
            content: message.content,
            toolCalls: nil,
            toolCallId: nil
        )
    }
    
    private func convertTool(_ tool: Tool) -> OpenAITool {
        let properties = tool.parameters.properties.mapValues { param in
            OpenAITool.FunctionDefinition.PropertySchema(
                type: param.type,
                description: param.description,
                enumValues: param.enumValues
            )
        }
        
        return OpenAITool(
            type: "function",
            function: OpenAITool.FunctionDefinition(
                name: tool.name,
                description: tool.description,
                parameters: OpenAITool.FunctionDefinition.Parameters(
                    type: "object",
                    properties: properties,
                    required: tool.parameters.required
                )
            )
        )
    }
    
    private func convertResponse(_ response: OpenAIResponse) throws -> LLMResponse {
        guard let choice = response.choices.first else {
            throw LLMError.invalidResponse
        }
        
        let message = choice.message
        var toolCalls: [ToolCall]? = nil
        
        if let openAIToolCalls = message.toolCalls {
            toolCalls = try openAIToolCalls.map { openAIToolCall -> ToolCall in
                // Parse arguments JSON string
                guard let argsData = openAIToolCall.function.arguments.data(using: .utf8),
                      let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
                    throw LLMError.invalidResponse
                }
                
                let arguments = argsDict.mapValues { AnyCodable($0) }
                
                return ToolCall(
                    id: openAIToolCall.id,
                    name: openAIToolCall.function.name,
                    arguments: arguments
                )
            }
        }
        
        let stopReason = convertFinishReason(choice.finishReason ?? "stop")
        
        let usage = response.usage.map { u in
            TokenUsage(
                inputTokens: u.promptTokens,
                outputTokens: u.completionTokens
            )
        }
        
        return LLMResponse(
            id: response.id,
            content: message.content ?? "",
            toolCalls: toolCalls,
            stopReason: stopReason,
            usage: usage
        )
    }
    
    private func convertFinishReason(_ reason: String) -> StopReason {
        switch reason {
        case "stop":
            return .endTurn
        case "length":
            return .maxTokens
        case "tool_calls":
            return .toolUse
        default:
            return .endTurn
        }
    }
}

// MARK: - Tool Call Builder for Streaming

private class ToolCallBuilder {
    var id: String
    var name: String
    var arguments: String
    
    init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
    
    func build() -> ToolCall? {
        guard !id.isEmpty, !name.isEmpty else { return nil }
        
        // Parse arguments JSON
        guard let argsData = arguments.data(using: .utf8),
              let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            return nil
        }
        
        let convertedArgs = argsDict.mapValues { AnyCodable($0) }
        
        return ToolCall(
            id: id,
            name: name,
            arguments: convertedArgs
        )
    }
}
