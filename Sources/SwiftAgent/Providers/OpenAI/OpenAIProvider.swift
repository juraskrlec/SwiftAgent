//
//  OpenAIProvider.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

public enum OpenAIModel: String, Sendable {
    case gpt52Pro = "gpt-5.2-pro"
    case gpt52 = "gpt-5.2"
    case gpt5Mini = "gpt-5-mini"
    case gpt5Nano = "gpt-5-nano"
    case gpt5 = "gpt-5"
}

public actor OpenAIProvider: LLMProvider, Sendable {
    public let apiKey: String
    public let model: OpenAIModel
    private let baseURL = "https://api.openai.com/v1"
    
    public init(apiKey: String, model: OpenAIModel = .gpt52) {
        self.apiKey = apiKey
        self.model = model
    }
    
    // MARK: - Generate
    
    public func generate(messages: [Message], tools: [Tool]?, options: GenerationOptions) async throws -> LLMResponse {
        let endpoint = "\(baseURL)/chat/completions"
        
        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let openAIRequest = buildRequest(messages: messages, tools: tools, options: options, stream: false)
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(openAIRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let error = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw LLMError.apiError(error.error.message)
            }
            throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return try parseResponse(openAIResponse)
    }
    
    // MARK: - Stream
    
    public func stream(messages: [Message], tools: [Tool]?, options: GenerationOptions) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        let endpoint = "\(baseURL)/chat/completions"
        
        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let openAIRequest = buildRequest(messages: messages, tools: tools, options: options, stream: true)
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(openAIRequest)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: LLMError.invalidResponse)
                        return
                    }
                    guard httpResponse.statusCode == 200 else {
                        var errorData = Data()
                        for try await byte in bytes {
                            errorData.append(byte)
                        }
                        
                        if let error = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: errorData) {
                            continuation.finish(throwing: LLMError.apiError(error.error.message))
                        } else {
                            continuation.finish(throwing: LLMError.apiError("HTTP \(httpResponse.statusCode)"))
                        }
                        return
                    }
                    
                    var buffer = ""
                    var accumulatedToolCalls: [Int: (id: String, name: String, args: String)] = [:]
                    
                    for try await byte in bytes {
                        buffer.append(Character(UnicodeScalar(byte)))
                        
                        while let newlineRange = buffer.range(of: "\n") {
                            let line = String(buffer[..<newlineRange.lowerBound])
                            buffer.removeSubrange(..<newlineRange.upperBound)
                            
                            guard !line.isEmpty, line.hasPrefix("data: ") else { continue }
                            
                            let data = String(line.dropFirst(6))
                            
                            if data == "[DONE]" {
                                // Yield any remaining complete tool calls
                                for (_, accumulated) in accumulatedToolCalls.sorted(by: { $0.key < $1.key }) {
                                    if !accumulated.id.isEmpty && !accumulated.name.isEmpty,
                                       let argsData = accumulated.args.data(using: .utf8),
                                       let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                                        
                                        let arguments = argsDict.mapValues { AnyCodable($0) }
                                        let toolCall = ToolCall(
                                            id: accumulated.id,
                                            name: accumulated.name,
                                            arguments: arguments
                                        )
                                        continuation.yield(LLMChunk(type: .toolCall(toolCall), usage: nil))
                                    }
                                }
                                continuation.finish()
                                return
                            }
                            
                            guard let jsonData = data.data(using: .utf8) else { continue }
                            
                            do {
                                let chunk = try JSONDecoder().decode(OpenAIStreamChunk.self, from: jsonData)
                                
                                guard let choice = chunk.choices.first else { continue }
                                let delta = choice.delta
                                
                                // Handle tool call deltas (ACCUMULATE)
                                if let toolCallDeltas = delta.toolCalls {
                                    for toolCallDelta in toolCallDeltas {
                                        let index = toolCallDelta.index ?? 0
                                        
                                        var accumulated = accumulatedToolCalls[index] ?? (id: "", name: "", args: "")
                                        
                                        if let id = toolCallDelta.id {
                                            accumulated.id = id
                                        }
                                        if let name = toolCallDelta.function?.name {
                                            accumulated.name = name
                                        }
                                        if let args = toolCallDelta.function?.arguments {
                                            accumulated.args += args
                                        }
                                        
                                        accumulatedToolCalls[index] = accumulated
                                    }
                                }
                                
                                // Handle content
                                if let content = delta.content, !content.isEmpty {
                                    continuation.yield(LLMChunk(type: .content(content), usage: nil))
                                }
                                
                                // Handle finish reason
                                if let finishReason = choice.finishReason {
                                    for (_, accumulated) in accumulatedToolCalls.sorted(by: { $0.key < $1.key }) {
                                        if !accumulated.id.isEmpty && !accumulated.name.isEmpty,
                                           let argsData = accumulated.args.data(using: .utf8),
                                           let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                                            
                                            let arguments = argsDict.mapValues { AnyCodable($0) }
                                            let toolCall = ToolCall(
                                                id: accumulated.id,
                                                name: accumulated.name,
                                                arguments: arguments
                                            )
                                            continuation.yield(LLMChunk(type: .toolCall(toolCall), usage: nil))
                                        }
                                    }
                                    accumulatedToolCalls.removeAll()
                                    
                                    let stopReason = mapFinishReason(finishReason)
                                    continuation.yield(LLMChunk(type: .done(stopReason), usage: nil))
                                }
                                
                            } catch {

                            }
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Build Request
    
    private func buildRequest(
        messages: [Message],
        tools: [Tool]?,
        options: GenerationOptions,
        stream: Bool
    ) -> OpenAIRequest {
        // Convert messages
        let openAIMessages = messages.map { msg -> OpenAIMessage in
            switch msg.role {
            case .system:
                return OpenAIMessage(
                    role: .system,
                    content: .text(msg.textContent),
                    toolCalls: nil,
                    toolCallId: nil
                )
                
            case .user:
                
                if msg.images.isEmpty {
                    return OpenAIMessage(
                        role: .user,
                        content: .text(msg.textContent),
                        toolCalls: nil,
                        toolCallId: nil
                    )
                } else {
                    var parts: [OpenAIContentPart] = []
                    
                    // Add text parts
                    for part in msg.content {
                        if case .text(let text) = part {
                            parts.append(OpenAIContentPart(
                                type: .text,
                                text: text,
                                imageURL: nil
                            ))
                        }
                    }
                    
                    for part in msg.content {
                        if case .image(let imageContent) = part {
                            let base64 = imageContent.data.base64EncodedString()
                            let dataURL = "data:\(imageContent.mimeType);base64,\(base64)"
                            
                            parts.append(OpenAIContentPart(
                                type: .imageURL,
                                text: nil,
                                imageURL: OpenAIContentPart.ImageURL(
                                    url: dataURL,
                                    detail: imageContent.detail?.rawValue
                                )
                            ))
                        }
                    }
                    
                    return OpenAIMessage(
                        role: .user,
                        content: .parts(parts),
                        toolCalls: nil,
                        toolCallId: nil
                    )
                }
            case .assistant:
                if let toolCalls = msg.toolCalls {
                    let openAIToolCalls = toolCalls.map { tc -> OpenAIToolCall in
                        let argsData = try? JSONEncoder().encode(tc.arguments)
                        let argsString = argsData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                        
                        return OpenAIToolCall(
                            id: tc.id,
                            type: "function",
                            function: OpenAIFunctionCall(
                                name: tc.name,
                                arguments: argsString
                            )
                        )
                    }
                    
                    return OpenAIMessage(
                        role: .assistant,
                        content: msg.textContent.isEmpty ? nil : .text(msg.textContent),
                        toolCalls: openAIToolCalls,
                        toolCallId: nil
                    )
                } else {
                    return OpenAIMessage(
                        role: .assistant,
                        content: .text(msg.textContent),
                        toolCalls: nil,
                        toolCallId: nil
                    )
                }
                
            case .tool:
                return OpenAIMessage(
                    role: .tool,
                    content: .text(msg.textContent),
                    toolCalls: nil,
                    toolCallId: msg.toolCallId
                )
            }
        }
        
        let openAITools: [OpenAITool]? = tools?.map { tool in
            let properties = tool.parameters.properties.mapValues { param -> JSONSchema.Property in
                
                let items: JSONSchema.Property? = param.items.map { itemParam in
                    JSONSchema.Property(
                        type: itemParam.type,
                        description: itemParam.description,
                        enumValues: itemParam.enumValues,
                        items: nil  // Single level of nesting
                    )
                }
                
                return JSONSchema.Property(
                    type: param.type,
                    description: param.description,
                    enumValues: param.enumValues,
                    items: items
                )
            }
            
            return OpenAITool(
                type: .function,
                function: .init(
                    name: tool.name,
                    description: tool.description,
                    parameters: JSONSchema(
                        type: "object",
                        properties: properties,
                        required: tool.parameters.required,
                        additionalProperties: false
                    )
                )
            )
        }
        
        let request = OpenAIRequest(
            model: model.rawValue,
            messages: openAIMessages,
            maxCompletionTokens: options.maxTokens,
            temperature: options.temperature,
            topP: options.topP,
            stop: options.stopSequences,
            stream: stream ? true : nil,
            tools: openAITools,
            toolChoice: openAITools != nil ? .auto : nil,
            parallelToolCalls: nil,
            responseFormat: nil,
            n: nil,
            seed: nil,
            user: nil
        )
        
        
        return request

    }
    
    // MARK: - Parse Response
    
    private func parseResponse(_ response: OpenAIResponse) throws -> LLMResponse {
        guard let choice = response.choices.first else {
            throw LLMError.invalidResponse
        }
        
        let message = choice.message
        
        // Parse tool calls
        var toolCalls: [ToolCall]? = nil
        if let openAIToolCalls = message.toolCalls {
            toolCalls = try openAIToolCalls.map { tc in
                guard let argsData = tc.function.arguments.data(using: .utf8),
                      let argsDict = try JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
                    throw LLMError.invalidResponse
                }
                
                let arguments = argsDict.mapValues { AnyCodable($0) }
                
                return ToolCall(
                    id: tc.id,
                    name: tc.function.name,
                    arguments: arguments
                )
            }
        }
        
        // Get content
        let content: String
        switch message.content {
        case .text(let text):
            content = text
        case .parts(let parts):
            content = parts.compactMap { $0.text }.joined(separator: "\n")
        case .none:
            content = ""
        }
        
        // Map finish reason to stop reason (with default)
        let stopReason = choice.finishReason.map { mapFinishReason($0) } ?? .endTurn
        
        return LLMResponse(
            id: response.id,
            content: content,
            toolCalls: toolCalls,
            stopReason: stopReason,
            usage: response.usage.map { usage in
                TokenUsage(
                    inputTokens: usage.promptTokens,
                    outputTokens: usage.completionTokens
                )
            }
        )
    }

    private func mapFinishReason(_ reason: String) -> StopReason {
        switch reason {
        case "stop":
            return .endTurn
        case "length":
            return .maxTokens
        case "tool_calls":
            return .toolUse
        case "content_filter":
            return .stopSequence
        default:
            return .endTurn
        }
    }
}
