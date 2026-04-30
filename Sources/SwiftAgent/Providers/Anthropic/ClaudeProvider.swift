//
//  ClaudeProvider.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// Claude/Anthropic LLM Provider
public actor ClaudeProvider: LLMProvider {
    public enum Model: String, Sendable {
        // Claude Opus models
        case claudeOpus47 = "claude-opus-4-7"
        case claudeOpus46 = "claude-opus-4-6"
        case claudeOpus45 = "claude-opus-4-5-20251101"
        case claudeOpus41 = "claude-opus-4-1-20250805"
        case claudeOpus4 = "claude-opus-4-20250514"
        
        // Claude Sonnet models
        case claudeSonnet45 = "claude-sonnet-4-5-20250929"
        case claudeSonnet4 = "claude-sonnet-4-20250514"
        
        // Claude Haiku models
        case claudeHaiku45 = "claude-haiku-4-5-20251001"
        case claudeHaiku3 = "claude-3-haiku-20240307"
        
        // Convenience aliases for latest versions
        public static let opus = Model.claudeOpus46
        public static let sonnet = Model.claudeSonnet45
        public static let haiku = Model.claudeHaiku45
    }
    
    private let api: AnthropicAPI
    private let model: Model
    private let defaultMaxTokens: Int
    
    public init(
        apiKey: String,
        model: Model = .sonnet,
        defaultMaxTokens: Int = 4096
    ) {
        self.api = AnthropicAPI(apiKey: apiKey)
        self.model = model
        self.defaultMaxTokens = defaultMaxTokens
    }
    
    public func generate(messages: [Message], tools: [Tool]?, options: GenerationOptions) async throws -> LLMResponse {
        let request = try buildRequest(
            messages: messages,
            tools: tools,
            options: options,
            stream: false
        )
        
        let response = try await api.sendRequest(request)
        return try convertResponse(response)
    }
    
    public func stream(messages: [Message], tools: [Tool]?, options: GenerationOptions) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        let request = try buildRequest(
            messages: messages,
            tools: tools,
            options: options,
            stream: true
        )
        
        let eventStream = try await api.streamRequest(request)
        
        return AsyncThrowingStream { continuation in
            Task {
                var currentText = ""
                var usage: TokenUsage?
                
                do {
                    for try await event in eventStream {
                        switch event.type {
                        case "content_block_start":
                            if let block = event.contentBlock, block.type == "tool_use" {
                                // Tool use starting
                            }
                            
                        case "content_block_delta":
                            if let delta = event.delta {
                                if delta.type == "text_delta", let text = delta.text {
                                    currentText += text
                                    continuation.yield(LLMChunk(type: .content(text)))
                                }
                            }
                            
                        case "content_block_stop":
                            // Block completed
                            break
                            
                        case "message_delta":
                            if let delta = event.delta, let reason = delta.stopReason {
                                let stopReason = convertStopReason(reason)
                                continuation.yield(LLMChunk(type: .done(stopReason), usage: usage))
                            }
                            
                        case "message_stop":
                            continuation.finish()
                            return
                            
                        default:
                            break
                        }
                        
                        if let eventUsage = event.usage {
                            usage = TokenUsage(
                                inputTokens: eventUsage.inputTokens,
                                outputTokens: eventUsage.outputTokens
                            )
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
    
    private func buildRequest(messages: [Message], tools: [Tool]?, options: GenerationOptions, stream: Bool) throws -> AnthropicRequest {
        // Extract system message
        let systemMessage = messages.first { $0.role == .system }?.textContent
        let conversationMessages = messages.filter { $0.role != .system }
        
        // Convert messages
        let anthropicMessages = try conversationMessages.map { message -> AnthropicMessage in
            try convertMessage(message)
        }
        
        // Convert tools
        let anthropicTools = tools?.map { tool -> AnthropicTool in
            convertTool(tool)
        }
        
        let request = AnthropicRequest(
            model: model.rawValue,
            messages: anthropicMessages,
            maxTokens: options.maxTokens ?? defaultMaxTokens,
            system: systemMessage,
            temperature: options.temperature,
            topP: options.topP,
            stopSequences: options.stopSequences,
            tools: anthropicTools,
            stream: stream
        )
        
        return request
    }

    private func convertMessage(_ message: Message) throws -> AnthropicMessage {
        let role: String
        switch message.role {
        case .user:
            role = "user"
        case .assistant:
            role = "assistant"
        case .tool:
            role = "user" // Tool results go back as user messages
        case .system:
            role = "user" // Should have been filtered out
        }
        
        // Handle tool results
        if message.role == .tool, let toolCallId = message.toolCallId {
            let block = ContentBlock(
                type: "tool_result",
                text: nil,
                id: toolCallId,
                name: nil,
                input: nil,
                content: message.textContent,
                source: nil
            )
            return AnthropicMessage(role: role, content: .blocks([block]))
        }
        
        // Handle assistant with tool calls
        if message.role == .assistant, let toolCalls = message.toolCalls {
            var blocks: [ContentBlock] = []
            
            // Add text content if present
            if !message.textContent.isEmpty {
                blocks.append(ContentBlock(
                    type: "text",
                    text: message.textContent,
                    id: nil,
                    name: nil,
                    input: nil,
                    content: nil,
                    source: nil
                ))
            }
            
            // Add tool use blocks
            for toolCall in toolCalls {
                blocks.append(ContentBlock(
                    type: "tool_use",
                    text: nil,
                    id: toolCall.id,
                    name: toolCall.name,
                    input: toolCall.arguments,
                    content: nil,
                    source: nil
                ))
            }
            
            return AnthropicMessage(role: role, content: .blocks(blocks))
        }
        
        if message.content.count > 1 || !message.images.isEmpty {
            var blocks: [ContentBlock] = []
            
            for part in message.content {
                switch part {
                case .text(let text):
                    blocks.append(ContentBlock(
                        type: "text",
                        text: text,
                        id: nil,
                        name: nil,
                        input: nil,
                        content: nil,
                        source: nil
                    ))
                    
                case .image(let imageContent):
                    blocks.append(ContentBlock(
                        type: "image",
                        text: nil,
                        id: nil,
                        name: nil,
                        input: nil,
                        content: nil,
                        source: ImageSource(
                            type: "base64",
                            mediaType: imageContent.mimeType,
                            data: imageContent.data.base64EncodedString()
                        )
                    ))
                }
            }
            
            return AnthropicMessage(role: role, content: .blocks(blocks))
        }
        
        // Regular text message
        return AnthropicMessage(role: role, content: .text(message.textContent))
    }
    
//    private func convertTool(_ tool: Tool) -> AnthropicTool {
//        let properties = tool.parameters.properties.mapValues { param in
//            AnthropicTool.PropertySchema(
//                type: param.type,
//                description: param.description,
//                enumValues: param.enumValues
//            )
//        }
//        
//        return AnthropicTool(
//            name: tool.name,
//            description: tool.description,
//            inputSchema: AnthropicTool.InputSchema(
//                type: "object",
//                properties: properties,
//                required: tool.parameters.required
//            )
//        )
//    }
    
    private func convertTool(_ tool: Tool) -> AnthropicTool {
        let properties = tool.parameters.properties.mapValues { param -> AnthropicTool.PropertySchema in
            
            var itemsSchema: AnthropicTool.PropertySchema? = nil
            if param.type == "array", let items = param.items {
                itemsSchema = AnthropicTool.PropertySchema(
                    type: items.type,
                    description: items.description,
                    enumValues: items.enumValues,
                    items: nil
                )
            }
            
            return AnthropicTool.PropertySchema(
                type: param.type,
                description: param.description,
                enumValues: param.enumValues,
                items: itemsSchema
            )
        }
        
        return AnthropicTool(
            name: tool.name,
            description: tool.description,
            inputSchema: AnthropicTool.InputSchema(
                type: "object",
                properties: properties,
                required: tool.parameters.required
            )
        )
    }
    
    private func convertResponse(_ response: AnthropicResponse) throws -> LLMResponse {
        
//        print("\n[DEBUG CLAUDE] Response:")
//        print("  Stop reason: \(response.stopReason ?? "nil")")
//        print("  Content blocks: \(response.content.count)")
//        for (i, block) in response.content.enumerated() {
//            print("    Block \(i): type=\(block.type)")
//            if block.type == "tool_use" {
//                print("      id: \(block.id ?? "nil")")
//                print("      name: \(block.name ?? "nil")")
//                print("      input keys: \(block.input?.keys.joined(separator: ", ") ?? "none")")
//            }
//        }
        
        var textContent = ""
        var toolCalls: [ToolCall] = []
        
        for block in response.content {
            switch block.type {
            case "text":
                if let text = block.text {
                    textContent += text
                }
            case "tool_use":
                if let id = block.id, let name = block.name, let input = block.input {
                    toolCalls.append(ToolCall(id: id, name: name, arguments: input))
                }
            default:
                break
            }
        }
        
        let stopReason = convertStopReason(response.stopReason ?? "end_turn")
        let usage = TokenUsage(
            inputTokens: response.usage.inputTokens,
            outputTokens: response.usage.outputTokens
        )
        
        return LLMResponse(
            id: response.id,
            content: textContent,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            stopReason: stopReason,
            usage: usage
        )
    }
    
    private func convertStopReason(_ reason: String) -> StopReason {
        switch reason {
        case "end_turn":
            return .endTurn
        case "max_tokens":
            return .maxTokens
        case "stop_sequence":
            return .stopSequence
        case "tool_use":
            return .toolUse
        default:
            return .endTurn
        }
    }
}
