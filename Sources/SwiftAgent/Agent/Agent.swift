//
//  Agent.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// An autonomous agent that can use tools to accomplish tasks
public actor Agent {
    public let name: String
    public let provider: LLMProvider
    public let systemPrompt: String?
    public let tools: [String: Tool]
    public let maxIterations: Int
    public let options: GenerationOptions
    
    // Track running task to prevent concurrent executions
    private var runningTask: Task<AgentResult, Error>?
    
    public init(name: String = "Agent",
                provider: LLMProvider,
                systemPrompt: String? = nil,
                tools: [Tool] = [],
                maxIterations: Int = 10,
                options: GenerationOptions = .default) {
        
        self.name = name
        self.provider = provider
        self.systemPrompt = systemPrompt
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
        self.maxIterations = maxIterations
        self.options = options
    }
    
    /// Initialize agent with system prompt from markdown file
    public init(name: String = "Agent",
                provider: LLMProvider,
                promptFile: String,
                promptVariables: [String: String] = [:],
                tools: [Tool] = [],
                maxIterations: Int = 10,
                options: GenerationOptions = .default
    ) throws {
        let systemPrompt = try AgentPrompt.load(
            fromFile: promptFile,
            variables: promptVariables
        )
        
        self.name = name
        self.provider = provider
        self.systemPrompt = systemPrompt
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
        self.maxIterations = maxIterations
        self.options = options
    }

    /// Initialize agent with system prompt from bundle resource
    public init(
        name: String = "Agent",
        provider: LLMProvider,
        promptResource: String,
        bundle: Bundle = .main,
        promptVariables: [String: String] = [:],
        tools: [Tool] = [],
        maxIterations: Int = 10,
        options: GenerationOptions = .default
    ) throws {
        var systemPrompt = try AgentPrompt.load(
            fromBundle: promptResource,
            bundle: bundle
        )
        
        // Apply variables
        for (key, value) in promptVariables {
            systemPrompt = systemPrompt.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        self.name = name
        self.provider = provider
        self.systemPrompt = systemPrompt
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
        self.maxIterations = maxIterations
        self.options = options
    }

    
    public func executeTool(_ toolCall: ToolCall) async throws -> String {
        guard let tool = tools[toolCall.name] else {
            throw ToolError.toolNotFound(toolCall.name)
        }
        
        let arguments = toolCall.arguments.mapValues { $0.value }
        
        do {
            return try await tool.execute(arguments: arguments)
        } catch {
            throw ToolError.executionFailed("Tool '\(toolCall.name)' failed: \(error.localizedDescription)")
        }
    }
    
    public func generateResponse(messages: [Message], tools: [Tool]? = nil) async throws -> LLMResponse {
        let toolsToUse = tools ?? Array(self.tools.values)
        return try await provider.generate(
            messages: messages,
            tools: toolsToUse.isEmpty ? nil : toolsToUse,
            options: options
        )
    }
    
    /// Run the agent synchronously with a single task
    public func run(task: String, images: [Message.ImageContent] = []) async throws -> AgentResult {
        // Check if already running
        if let existingTask = runningTask, !existingTask.isCancelled {
            throw AgentError.alreadyRunning
        }
        
        // Create new task
        let task = Task<AgentResult, Error> {
            try await self.executeTask(task, images: images)
        }
        
        // Store reference
        runningTask = task
        
        do {
            let result = try await task.value
            runningTask = nil
            return result
        } catch {
            runningTask = nil
            throw error
        }
    }
    
    /// Cancel the currently running task
    public func cancel() {
        runningTask?.cancel()
        runningTask = nil
    }
    
    /// Check if the agent is currently running
    public var isRunning: Bool {
        guard let task = runningTask else { return false }
        return !task.isCancelled
    }
    
    // MARK: - Private Execution
    
    private func executeTask(_ taskInput: String, images: [Message.ImageContent] = []) async throws -> AgentResult {
        var state = AgentState()
        
        // Add system message if provided
        if let systemPrompt = systemPrompt {
            state.addMessage(.system(systemPrompt))
        }
        
        if images.isEmpty {
            state.addMessage(.user(taskInput))
        } else {
            state.addMessage(.user(taskInput, images: images))
        }
        
        var totalTokens = 0
        
        while state.iterations < maxIterations {
            // Check for cancellation
            try Task.checkCancellation()
            
            // Capture immutable copies before await
            let currentMessages = state.messages
            let currentTools = tools.isEmpty ? nil : Array(tools.values)
            let currentOptions = options
            
            // Get response from LLM (suspension point)
            let response = try await provider.generate(
                messages: currentMessages,
                tools: currentTools,
                options: currentOptions
            )
            
            // Check for cancellation after await
            try Task.checkCancellation()
            
            // Track token usage
            if let usage = response.usage {
                totalTokens += usage.totalTokens
            }
            
            // Check if agent wants to use tools
            if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                // Add assistant message with tool calls
                state.addMessage(.assistant(
                    response.content,
                    toolCalls: toolCalls
                ))
                
                // Execute tools (each is a suspension point)
                for toolCall in toolCalls {
                    try Task.checkCancellation()
                    let result = try await executeTool(toolCall)
                    state.addMessage(.tool(result, toolCallId: toolCall.id))
                }
                
                state.incrementIteration()
                continue
            }
            
            // No tool calls - agent has final answer
            state.addMessage(.assistant(response.content))
            
            return AgentResult(
                output: response.content,
                state: state,
                totalTokens: totalTokens,
                success: true
            )
        }
        
        // Max iterations reached
        throw AgentError.maxIterationsReached(maxIterations)
    }
    
    /// Run the agent with streaming support
    public func stream(task: String, images: [Message.ImageContent] = []
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let streamTask = Task {
                do {
                    var state = AgentState()
                    
                    // Add system message if provided
                    if let systemPrompt = systemPrompt {
                        state.addMessage(.system(systemPrompt))
                    }
                    
                    if images.isEmpty {
                        state.addMessage(.user(task))
                    } else {
                        state.addMessage(.user(task, images: images))
                    }
                    
                    var totalTokens = 0
                    
                    while state.iterations < maxIterations {
                        // Check for cancellation
                        try Task.checkCancellation()
                        
                        // Capture immutable copies before await
                        let currentMessages = state.messages
                        let currentTools = tools.isEmpty ? nil : Array(tools.values)
                        let currentOptions = options
                        
                        // Stream response from LLM (suspension point)
                        let responseStream = try await provider.stream(
                            messages: currentMessages,
                            tools: currentTools,
                            options: currentOptions
                        )
                        
                        var currentText = ""
                        var currentToolCalls: [ToolCall] = []
                        
                        for try await chunk in responseStream {
                            try Task.checkCancellation()
                            
                            switch chunk.type {
                            case .content(let text):
                                currentText += text
                                continuation.yield(.thinking(text))
                                
                            case .toolCall(let toolCall):
                                currentToolCalls.append(toolCall)
                                continuation.yield(.toolCall(toolCall))
                                
                            case .done(_):
                                if let chunkUsage = chunk.usage {
                                    totalTokens += chunkUsage.totalTokens
                                }
                            }
                        }
                        
                        // Check if we have tool calls
                        if !currentToolCalls.isEmpty {
                            // Add assistant message with tool calls
                            state.addMessage(.assistant(
                                currentText,
                                toolCalls: currentToolCalls
                            ))
                            
                            // Execute tools (each is a suspension point)
                            for toolCall in currentToolCalls {
                                try Task.checkCancellation()
                                let result = try await executeTool(toolCall)
                                state.addMessage(.tool(result, toolCallId: toolCall.id))
                                continuation.yield(.toolResult(result, toolCallId: toolCall.id))
                            }
                            
                            state.incrementIteration()
                            continue
                        }
                        
                        // No tool calls - agent has final answer
                        state.addMessage(.assistant(currentText))
                        
                        let result = AgentResult(
                            output: currentText,
                            state: state,
                            totalTokens: totalTokens,
                            success: true
                        )
                        
                        continuation.yield(.completed(result))
                        continuation.finish()
                        return
                    }
                    
                    // Max iterations reached
                    throw AgentError.maxIterationsReached(maxIterations)
                    
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                streamTask.cancel()
            }
        }
    }
    
    /// Invoke the agent with a single message (non-agentic, just one turn)
    public func invoke(
        input: String,
        images: [Message.ImageContent] = []  // ✅ Add vision support
    ) async throws -> LLMResponse {
        var messages: [Message] = []
        
        if let systemPrompt = systemPrompt {
            messages.append(.system(systemPrompt))
        }
        
        if images.isEmpty {
            messages.append(.user(input))
        } else {
            messages.append(.user(input, images: images))
        }
        
        // Capture immutable copies before await
        let currentTools = tools.isEmpty ? nil : Array(tools.values)
        let currentOptions = options
        
        return try await provider.generate(
            messages: messages,
            tools: currentTools,
            options: currentOptions
        )
    }
}

/// Errors specific to agent execution
public enum AgentError: Error, LocalizedError {
    case maxIterationsReached(Int)
    case configurationError(String)
    case alreadyRunning
    
    public var errorDescription: String? {
        switch self {
        case .maxIterationsReached(let max):
            return "Agent reached maximum iterations (\(max)) without completing the task"
        case .configurationError(let message):
            return "Agent configuration error: \(message)"
        case .alreadyRunning:
            return "Agent is already running a task. Cancel the current task first or wait for it to complete."
        }
    }
}
