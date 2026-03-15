//
//  MLXProvider.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 15.03.2026..
//

import Foundation

#if os(macOS) && canImport(MLX)
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import Tokenizers

/// Local LLM provider using MLX for Apple Silicon optimization
@available(macOS 14.0, *)
public actor MLXProvider: LLMProvider {
    
    /// Popular MLX models available from mlx-community on Hugging Face
    public enum Model: String, Sendable {
        // Llama
        case llama3_2_3B = "mlx-community/Llama-3.2-3B-Instruct-4bit"
        case llama3_2_1B = "mlx-community/Llama-3.2-1B-Instruct-4bit"
        case llama3_1_8B = "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit"
        
        // Qwen
        case qwen3_8B = "mlx-community/Qwen3-8B-4bit"
        case qwen3_4B = "mlx-community/Qwen3-4B-4bit"
        case qwen2_5_7B = "mlx-community/Qwen2.5-7B-Instruct-4bit"
        case qwen2_5_1_5B = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
        
        // Gemma
        case gemma3_4B = "mlx-community/gemma-3-4b-it-4bit"
        case gemma2_9B = "mlx-community/gemma-2-9b-it-4bit"
        case gemma2_2B = "mlx-community/gemma-2-2b-it-4bit"
        
        // Phi
        case phi4Mini = "mlx-community/phi-4-mini-instruct-4bit"
        
        // Mistral
        case mistral7B = "mlx-community/Mistral-7B-Instruct-v0.3-4bit"
        
        // SmolLM
        case smolLM2_1_7B = "mlx-community/SmolLM2-1.7B-Instruct-4bit"
        case smolLM2_360M = "mlx-community/SmolLM2-360M-Instruct-4bit"
        
        // DeepSeek
        case deepSeekR1_8B = "mlx-community/DeepSeek-R1-Distill-Llama-8B-4bit"
        
        /// Convenience alias for default model
        public static let `default` = Model.llama3_2_3B
    }
    
    private let modelContainer: ModelContainer
    private let generateParameters: MLXGenerateParameters
    private let defaultMaxTokens: Int
    
    /// Configuration for MLX model generation
    public struct MLXGenerateParameters: Sendable {
        public let temperature: Float
        public let topP: Float
        public let repetitionPenalty: Float?
        public let repetitionContextSize: Int
        
        public init(
            temperature: Float = 0.6,
            topP: Float = 0.9,
            repetitionPenalty: Float? = 1.1,
            repetitionContextSize: Int = 20
        ) {
            self.temperature = temperature
            self.topP = topP
            self.repetitionPenalty = repetitionPenalty
            self.repetitionContextSize = repetitionContextSize
        }
        
        public static let `default` = MLXGenerateParameters()
    }
    
    /// Initialize with a predefined model
    /// - Parameters:
    ///   - model: One of the popular MLX models
    ///   - parameters: Generation parameters
    ///   - maxTokens: Maximum tokens to generate
    ///   - progressHandler: Called with download progress (0.0 to 1.0) during model download
    public init(
        model: Model = .default,
        parameters: MLXGenerateParameters = .default,
        maxTokens: Int = 2048,
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws {
        self.generateParameters = parameters
        self.defaultMaxTokens = maxTokens
        
        let configuration = ModelConfiguration(id: model.rawValue)
        self.modelContainer = try await LLMModelFactory.shared.loadModelContainer(
            configuration: configuration,
            progressHandler: progressHandler
        )
    }
    
    /// Initialize with a predefined ModelConfiguration
    /// - Parameters:
    ///   - configuration: MLX model configuration (e.g., from LLMRegistry)
    ///   - parameters: Generation parameters
    ///   - maxTokens: Maximum tokens to generate
    ///   - progressHandler: Called with download progress (0.0 to 1.0) during model download
    public init(
        configuration: ModelConfiguration,
        parameters: MLXGenerateParameters = .default,
        maxTokens: Int = 2048,
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws {
        self.generateParameters = parameters
        self.defaultMaxTokens = maxTokens
        self.modelContainer = try await LLMModelFactory.shared.loadModelContainer(
            configuration: configuration,
            progressHandler: progressHandler
        )
    }
    
    /// Initialize with a Hugging Face model ID string
    /// - Parameters:
    ///   - modelId: Hugging Face model ID (e.g., "mlx-community/Llama-3.2-3B-Instruct-4bit")
    ///   - parameters: Generation parameters
    ///   - maxTokens: Maximum tokens to generate
    ///   - progressHandler: Called with download progress (0.0 to 1.0) during model download
    public init(
        modelId: String,
        parameters: MLXGenerateParameters = .default,
        maxTokens: Int = 2048,
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws {
        self.generateParameters = parameters
        self.defaultMaxTokens = maxTokens
        
        let configuration = ModelConfiguration(id: modelId)
        self.modelContainer = try await LLMModelFactory.shared.loadModelContainer(
            configuration: configuration,
            progressHandler: progressHandler
        )
    }
    
    /// Initialize with a local model directory (no download needed)
    /// - Parameters:
    ///   - modelDirectory: URL to local MLX model directory
    ///   - parameters: Generation parameters
    ///   - maxTokens: Maximum tokens to generate
    public init(modelDirectory: URL, parameters: MLXGenerateParameters = .default, maxTokens: Int = 2048) async throws {
        self.generateParameters = parameters
        self.defaultMaxTokens = maxTokens
        
        let configuration = ModelConfiguration(directory: modelDirectory)
        self.modelContainer = try await LLMModelFactory.shared.loadModelContainer(configuration: configuration)
    }
    
    // MARK: - LLMProvider Protocol
    
    public func generate(messages: [Message], tools: [Tool]?, options: GenerationOptions) async throws -> LLMResponse {
        let chatMessages = mapToChatMessages(messages)
        let userInput = UserInput(chat: chatMessages)
        let lmInput = try await modelContainer.prepare(input: userInput)
        
        let maxTokens = options.maxTokens ?? defaultMaxTokens
        let temperature = Float(options.temperature ?? Double(generateParameters.temperature))
        let topP = Float(options.topP ?? Double(generateParameters.topP))
        
        let params = GenerateParameters(
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            repetitionPenalty: generateParameters.repetitionPenalty,
            repetitionContextSize: generateParameters.repetitionContextSize
        )
        
        var generatedText = ""
        var promptTokens = 0
        var generationTokens = 0
        
        let stream = try await modelContainer.generate(input: lmInput, parameters: params)
        
        for await generation in stream {
            switch generation {
            case .chunk(let text):
                generatedText += text
            case .info(let info):
                promptTokens = info.promptTokenCount
                generationTokens = info.generationTokenCount
            case .toolCall:
                break
            }
        }
        
        // Parse for tool calls from generated text
        let toolCalls = parseToolCalls(from: generatedText)
        
        return LLMResponse(
            content: generatedText.trimmingCharacters(in: .whitespacesAndNewlines),
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            stopReason: .endTurn,
            usage: TokenUsage(
                inputTokens: promptTokens,
                outputTokens: generationTokens
            )
        )
    }
    
    public func stream(messages: [Message], tools: [Tool]?, options: GenerationOptions) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        let chatMessages = mapToChatMessages(messages)
        let userInput = UserInput(chat: chatMessages)
        let lmInput = try await modelContainer.prepare(input: userInput)
        
        let maxTokens = options.maxTokens ?? defaultMaxTokens
        let temperature = Float(options.temperature ?? Double(generateParameters.temperature))
        let topP = Float(options.topP ?? Double(generateParameters.topP))
        
        let params = GenerateParameters(
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            repetitionPenalty: generateParameters.repetitionPenalty,
            repetitionContextSize: generateParameters.repetitionContextSize
        )
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = try await modelContainer.generate(input: lmInput, parameters: params)
                    
                    for await generation in stream {
                        switch generation {
                        case .chunk(let text):
                            continuation.yield(LLMChunk(type: .content(text)))
                        case .info(let info):
                            continuation.yield(LLMChunk(
                                type: .done(.endTurn),
                                usage: TokenUsage(
                                    inputTokens: info.promptTokenCount,
                                    outputTokens: info.generationTokenCount
                                )
                            ))
                        case .toolCall:
                            break
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
    
    private func mapToChatMessages(_ messages: [Message]) -> [Chat.Message] {
        messages.compactMap { message in
            switch message.role {
            case .system:
                return Chat.Message.system(message.textContent)
            case .user:
                return Chat.Message.user(message.textContent)
            case .assistant:
                return Chat.Message.assistant(message.textContent)
            case .tool:
                return Chat.Message.tool(message.textContent)
            }
        }
    }
    
    private func parseToolCalls(from text: String) -> [ToolCall] {
        var toolCalls: [ToolCall] = []
        
        let pattern = "TOOL_CALL:\\s*(\\w+)\\((.*)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            if match.numberOfRanges == 3 {
                let toolName = nsString.substring(with: match.range(at: 1))
                let argsString = nsString.substring(with: match.range(at: 2))
                
                if let argsData = argsString.data(using: .utf8),
                   let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                    
                    let toolCall = ToolCall(
                        id: UUID().uuidString,
                        name: toolName,
                        arguments: args.mapValues { AnyCodable($0) }
                    )
                    
                    toolCalls.append(toolCall)
                }
            }
        }
        
        return toolCalls
    }
}

#else

// Fallback for platforms that don't support MLX
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public actor MLXProvider: LLMProvider {
    public init() async throws {
        throw LLMError.apiError("MLX is not available on this platform. Requires macOS with Apple Silicon.")
    }
    
    public func generate(
        messages: [Message],
        tools: [Tool]?,
        options: GenerationOptions
    ) async throws -> LLMResponse {
        throw LLMError.apiError("MLX is not available on this platform")
    }
    
    public func stream(
        messages: [Message],
        tools: [Tool]?,
        options: GenerationOptions
    ) async throws -> AsyncThrowingStream<LLMChunk, Error> {
        throw LLMError.apiError("MLX is not available on this platform")
    }
}

#endif
