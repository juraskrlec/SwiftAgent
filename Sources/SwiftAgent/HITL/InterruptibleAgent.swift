//
//  InterruptibleAgent.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 13.02.2026..
//


import Foundation

/// Agent that supports interrupts and checkpoints 
public actor InterruptibleAgent {
    public let name: String
    private let provider: LLMProvider
    private let systemPrompt: String?
    private let tools: [String: Tool]
    private let maxIterations: Int
    private let options: GenerationOptions
    
    private let checkpointStore: CheckpointStore
    private let interruptBefore: [String]  // Tool names to interrupt before
    private let interruptAfter: [String]   // Tool names to interrupt after
    
    // Current execution state
    private var pendingInterrupts: [String: InterruptRequest] = [:]
    
    public init(
        name: String,
        provider: LLMProvider,
        systemPrompt: String? = nil,
        tools: [Tool] = [],
        maxIterations: Int = 10,
        options: GenerationOptions = .default,
        checkpointStore: CheckpointStore = InMemoryCheckpointStore(),
        interruptBefore: [String] = [],
        interruptAfter: [String] = []
    ) {
        self.name = name
        self.provider = provider
        self.systemPrompt = systemPrompt
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
        self.maxIterations = maxIterations
        self.options = options
        self.checkpointStore = checkpointStore
        self.interruptBefore = interruptBefore
        self.interruptAfter = interruptAfter
    }
    
    /// Run agent with interrupt support
    public func invoke(
        task: String,
        threadId: String = UUID().uuidString
    ) async throws -> AgentResult {
        // Check for existing checkpoint
        if let checkpoint = try await checkpointStore.latest(threadId: threadId) {
            print("📍 Resuming from checkpoint: \(checkpoint.id)")
            
            // If there's a pending action, wait for response
            if checkpoint.pendingAction != nil {
                return AgentResult(
                    output: "Execution paused - waiting for interrupt response",
                    state: checkpoint.state,
                    totalTokens: 0,
                    success: false
                )
            }
            
            return try await continueExecution(state: checkpoint.state, threadId: threadId)
        }
        
        // New execution
        return try await executeTask(task, threadId: threadId)
    }
    
    /// Get pending interrupt for a thread
    public func getPendingInterrupt(threadId: String) async -> InterruptRequest? {
        return pendingInterrupts[threadId]
    }
    
    /// Respond to pending interrupt and continue execution
    public func updateState(_ response: InterruptResponse, threadId: String) async throws -> AgentResult {
        guard let checkpoint = try await checkpointStore.latest(threadId: threadId) else {
            throw AgentError.configurationError("No checkpoint found for thread")
        }
        
        // Remove pending interrupt
        pendingInterrupts.removeValue(forKey: threadId)
        
        // Process response and update state
        var state = checkpoint.state
        
        switch response.action {
        case .approve:
            if let pending = checkpoint.pendingAction {
                // Execute the approved tool
                let result = try await executeTool(pending.toolCall)
                state.addMessage(.tool(result, toolCallId: pending.toolCall.id))
                
                // Save checkpoint after execution
                try await saveCheckpoint(
                    state: state,
                    threadId: threadId,
                    pendingAction: nil
                )
            }
            
        case .reject:
            return AgentResult(
                output: "Rejected: \(response.feedback ?? "User rejected the action")",
                state: state,
                totalTokens: 0,
                success: false
            )
            
        case .modify:
            if let newValue = response.value {
                // Add human guidance to messages
                state.addMessage(.user("Follow this guidance: \(newValue)"))
                
                // Clear the pending action
                try await saveCheckpoint(
                    state: state,
                    threadId: threadId,
                    pendingAction: nil
                )
            }
            
        case .skip:
            if let pending = checkpoint.pendingAction {
                // Add a message indicating the action was skipped
                state.addMessage(.tool(
                    "Action '\(pending.toolCall.name)' skipped by user",
                    toolCallId: pending.toolCall.id
                ))
                
                try await saveCheckpoint(
                    state: state,
                    threadId: threadId,
                    pendingAction: nil
                )
            }
            
        case .rollback:
            // Rollback to previous checkpoint
            let allCheckpoints = try await checkpointStore.list(threadId: threadId)
            if allCheckpoints.count > 1 {
                let previous = allCheckpoints[allCheckpoints.count - 2]
                return try await continueExecution(state: previous.state, threadId: threadId)
            }
            
        case .retry:
            // Keep same state, clear pending action, and retry
            try await saveCheckpoint(
                state: state,
                threadId: threadId,
                pendingAction: nil
            )
        }
        
        // Continue execution
        return try await continueExecution(state: state, threadId: threadId)
    }
    
    /// Get all checkpoints for a thread
    public func getCheckpoints(threadId: String) async throws -> [Checkpoint] {
        return try await checkpointStore.list(threadId: threadId)
    }
    
    /// Get state at a specific checkpoint
    public func getState(checkpointId: String) async throws -> AgentState? {
        guard let checkpoint = try await checkpointStore.load(id: checkpointId) else {
            return nil
        }
        return checkpoint.state
    }
    
    // MARK: - Private Execution
    
    private func executeTask(_ taskInput: String, threadId: String ) async throws -> AgentResult {
        var state = AgentState()
        
        if let systemPrompt = systemPrompt {
            state.addMessage(.system(systemPrompt))
        }
        
        state.addMessage(.user(taskInput))
        state.metadata["thread_id"] = threadId
        state.metadata["task"] = taskInput
        
        return try await continueExecution(state: state, threadId: threadId)
    }
    
    private func continueExecution(state: AgentState,threadId: String) async throws -> AgentResult {
        var currentState = state
        var totalTokens = 0
        
        while currentState.iterations < maxIterations {
            try Task.checkCancellation()
            
            // Save checkpoint before LLM call
            try await saveCheckpoint(
                state: currentState,
                threadId: threadId,
                pendingAction: nil
            )
            
            let currentMessages = currentState.messages
            let currentTools = tools.isEmpty ? nil : Array(tools.values)
            
            let response = try await provider.generate(
                messages: currentMessages,
                tools: currentTools,
                options: options
            )
            
            if let usage = response.usage {
                totalTokens += usage.totalTokens
            }
            
            if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                currentState.addMessage(.assistant(
                    response.content,
                    toolCalls: toolCalls
                ))
                
                for toolCall in toolCalls {
                    // Check if we should interrupt BEFORE execution
                    if interruptBefore.contains(toolCall.name) {
                        // Save checkpoint with pending action
                        let pendingAction = PendingAction(
                            toolCall: toolCall,
                            severity: "high",
                            description: "About to execute: \(toolCall.name)"
                        )
                        
                        try await saveCheckpoint(
                            state: currentState,
                            threadId: threadId,
                            pendingAction: pendingAction
                        )
                        
                        // Create interrupt request
                        let interrupt = InterruptRequest(
                            type: .approval,
                            checkpointId: try await checkpointStore.latest(threadId: threadId)?.id ?? "",
                            message: "Approve execution of '\(toolCall.name)'?\n\nArguments:\n\(formatArguments(toolCall.arguments))",
                            options: [
                                InterruptOption(id: "approve", label: "Approve", value: "approve"),
                                InterruptOption(id: "reject", label: "Reject", value: "reject"),
                                InterruptOption(id: "modify", label: "Modify", value: "modify"),
                                InterruptOption(id: "skip", label: "Skip", value: "skip")
                            ],
                            metadata: ["thread_id": threadId, "tool_name": toolCall.name]
                        )
                        
                        // Store pending interrupt
                        pendingInterrupts[threadId] = interrupt
                        
                        // Return partial result - execution paused
                        return AgentResult(
                            output: "⏸️ Execution paused for approval of '\(toolCall.name)'",
                            state: currentState,
                            totalTokens: totalTokens,
                            success: false
                        )
                    }
                    
                    // Execute tool
                    let result = try await executeTool(toolCall)
                    currentState.addMessage(.tool(result, toolCallId: toolCall.id))
                    
                    // Check if we should interrupt AFTER execution
                    if interruptAfter.contains(toolCall.name) {
                        try await saveCheckpoint(
                            state: currentState,
                            threadId: threadId,
                            pendingAction: nil
                        )
                        
                        let interrupt = InterruptRequest(
                            type: .review,
                            checkpointId: try await checkpointStore.latest(threadId: threadId)?.id ?? "",
                            message: "Review result of '\(toolCall.name)':\n\n\(result)",
                            options: [
                                InterruptOption(id: "continue", label: "Continue", value: "continue"),
                                InterruptOption(id: "retry", label: "Retry", value: "retry"),
                                InterruptOption(id: "rollback", label: "Rollback", value: "rollback"),
                                InterruptOption(id: "stop", label: "Stop", value: "stop")
                            ],
                            metadata: ["thread_id": threadId, "tool_name": toolCall.name]
                        )
                        
                        pendingInterrupts[threadId] = interrupt
                        
                        return AgentResult(
                            output: "⏸️ Paused for review of '\(toolCall.name)'",
                            state: currentState,
                            totalTokens: totalTokens,
                            success: false
                        )
                    }
                }
                
                currentState.incrementIteration()
                continue
            }
            
            // No tool calls - done
            currentState.addMessage(.assistant(response.content))
            
            // Save final checkpoint
            try await saveCheckpoint(
                state: currentState,
                threadId: threadId,
                pendingAction: nil
            )
            
            return AgentResult(
                output: response.content,
                state: currentState,
                totalTokens: totalTokens,
                success: true
            )
        }
        
        throw AgentError.maxIterationsReached(maxIterations)
    }
    
    private func saveCheckpoint(state: AgentState, threadId: String, pendingAction: PendingAction?) async throws {
        var metadata = state.metadata
        metadata["thread_id"] = threadId
        
        let checkpoint = Checkpoint(
            state: state,
            pendingAction: pendingAction,
            metadata: metadata
        )
        
        try await checkpointStore.save(checkpoint)
    }
    
    private func executeTool(_ toolCall: ToolCall) async throws -> String {
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
    
    private func formatArguments(_ arguments: [String: AnyCodable]) -> String {
        arguments.map { "  • \($0.key): \($0.value.value)" }.joined(separator: "\n")
    }
}
