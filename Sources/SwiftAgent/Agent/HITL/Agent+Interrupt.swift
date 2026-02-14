//
//  Agent+Interrupt.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 14.02.2026..
//

import Foundation

public struct InterruptConfig: Sendable {
    public let checkpointStore: CheckpointStore
    public let interruptBefore: [String]
    public let interruptAfter: [String]
    
    public init(
        checkpointStore: CheckpointStore = InMemoryCheckpointStore(),
        interruptBefore: [String] = [],
        interruptAfter: [String] = []
    ) {
        self.checkpointStore = checkpointStore
        self.interruptBefore = interruptBefore
        self.interruptAfter = interruptAfter
    }
}

extension Agent {
    /// Run with interrupts (LangGraph-style)
    public func invoke(
        task: String,
        threadId: String = UUID().uuidString,
        config: InterruptConfig
    ) async throws -> InterruptibleResult {
        // Check for existing checkpoint
        if let checkpoint = try await config.checkpointStore.latest(threadId: threadId) {
            if checkpoint.pendingAction != nil {
                return InterruptibleResult(
                    agentResult: AgentResult(
                        output: "Execution paused",
                        state: checkpoint.state,
                        totalTokens: 0,
                        success: false
                    ),
                    threadId: threadId,
                    checkpoint: checkpoint,
                    pendingInterrupt: createInterruptRequest(from: checkpoint, threadId: threadId)
                )
            }
            
            return try await continueExecution(
                state: checkpoint.state,
                threadId: threadId,
                config: config
            )
        }
        
        // New execution
        var state = AgentState()
        if let systemPrompt = self.systemPrompt {
            state.addMessage(.system(systemPrompt))
        }
        state.addMessage(.user(task))
        state.metadata["thread_id"] = threadId
        
        return try await continueExecution(state: state, threadId: threadId, config: config)
    }
    
    /// Continue after interrupt response
    public func updateState(_ response: InterruptResponse, threadId: String, config: InterruptConfig) async throws -> InterruptibleResult {
        guard let checkpoint = try await config.checkpointStore.latest(threadId: threadId) else {
            throw AgentError.configurationError("No checkpoint found")
        }
        
        var state = checkpoint.state
        
        switch response.action {
        case .approve:
            if let pending = checkpoint.pendingAction {
                let result = try await self.executeTool(pending.toolCall)
                state.addMessage(.tool(result, toolCallId: pending.toolCall.id))
                try await saveCheckpoint(state: state, threadId: threadId, pendingAction: nil, config: config)
            }
            
        case .reject:
            return InterruptibleResult(
                agentResult: AgentResult(output: "❌ Rejected", state: state, totalTokens: 0, success: false),
                threadId: threadId,
                checkpoint: checkpoint,
                pendingInterrupt: nil
            )
            
        case .modify:
            if let value = response.value {
                state.addMessage(.user("Guidance: \(value)"))
                try await saveCheckpoint(state: state, threadId: threadId, pendingAction: nil, config: config)
            }
            
        case .skip:
            if let pending = checkpoint.pendingAction {
                state.addMessage(.tool("Skipped", toolCallId: pending.toolCall.id))
                try await saveCheckpoint(state: state, threadId: threadId, pendingAction: nil, config: config)
            }
            
        case .rollback:
            let all = try await config.checkpointStore.list(threadId: threadId)
            if all.count > 1 {
                return try await continueExecution(state: all[all.count - 2].state, threadId: threadId, config: config)
            }
            
        case .retry:
            try await saveCheckpoint(state: state, threadId: threadId, pendingAction: nil, config: config)
        }
        
        return try await continueExecution(state: state, threadId: threadId, config: config)
    }
    
    // MARK: - Private
    
    private func continueExecution(
        state: AgentState,
        threadId: String,
        config: InterruptConfig
    ) async throws -> InterruptibleResult {
        var currentState = state
        var totalTokens = 0
        
        while currentState.iterations < maxIterations {
            try Task.checkCancellation()
            
            try await saveCheckpoint(state: currentState, threadId: threadId, pendingAction: nil, config: config)
            
            let response = try await self.generateResponse(messages: currentState.messages)
            
            if let usage = response.usage {
                totalTokens += usage.totalTokens
            }
            
            if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                currentState.addMessage(.assistant(response.content, toolCalls: toolCalls))
                
                for toolCall in toolCalls {
                    // Check interrupt BEFORE
                    if config.interruptBefore.contains(toolCall.name) {
                        let pending = PendingAction(toolCall: toolCall, severity: "high", description: "About to execute: \(toolCall.name)")
                        try await saveCheckpoint(state: currentState, threadId: threadId, pendingAction: pending, config: config)
                        
                        let checkpoint = try await config.checkpointStore.latest(threadId: threadId)!
                        
                        return InterruptibleResult(
                            agentResult: AgentResult(output: "Paused for '\(toolCall.name)'", state: currentState, totalTokens: totalTokens, success: false),
                            threadId: threadId,
                            checkpoint: checkpoint,
                            pendingInterrupt: createInterruptRequest(from: checkpoint, threadId: threadId)
                        )
                    }
                    
                    // Execute
                    let result = try await self.executeTool(toolCall)
                    currentState.addMessage(.tool(result, toolCallId: toolCall.id))
                    
                    // Check interrupt AFTER
                    if config.interruptAfter.contains(toolCall.name) {
                        try await saveCheckpoint(state: currentState, threadId: threadId, pendingAction: nil, config: config)
                        let checkpoint = try await config.checkpointStore.latest(threadId: threadId)!
                        
                        let interrupt = InterruptRequest(
                            type: .review,
                            checkpointId: checkpoint.id,
                            message: "Review '\(toolCall.name)':\n\(result)",
                            options: [
                                InterruptOption(id: "continue", label: "Continue", value: "approve"),
                                InterruptOption(id: "retry", label: "Retry", value: "retry")
                            ],
                            metadata: ["thread_id": threadId]
                        )
                        
                        return InterruptibleResult(
                            agentResult: AgentResult(output: "⏸️ Review '\(toolCall.name)'", state: currentState, totalTokens: totalTokens, success: false),
                            threadId: threadId,
                            checkpoint: checkpoint,
                            pendingInterrupt: interrupt
                        )
                    }
                }
                
                currentState.incrementIteration()
                continue
            }
            
            // Done
            currentState.addMessage(.assistant(response.content))
            try await saveCheckpoint(state: currentState, threadId: threadId, pendingAction: nil, config: config)
            
            let checkpoint = try await config.checkpointStore.latest(threadId: threadId)!
            
            return InterruptibleResult(
                agentResult: AgentResult(output: response.content, state: currentState, totalTokens: totalTokens, success: true),
                threadId: threadId,
                checkpoint: checkpoint,
                pendingInterrupt: nil
            )
        }
        
        throw AgentError.maxIterationsReached(maxIterations)
    }
    
    private func saveCheckpoint(state: AgentState, threadId: String, pendingAction: PendingAction?, config: InterruptConfig) async throws {
        var metadata = state.metadata
        metadata["thread_id"] = threadId
        let checkpoint = Checkpoint(state: state, pendingAction: pendingAction, metadata: metadata)
        try await config.checkpointStore.save(checkpoint)
    }
    
    private func createInterruptRequest(from checkpoint: Checkpoint, threadId: String) -> InterruptRequest? {
        guard let pending = checkpoint.pendingAction else { return nil }
        
        return InterruptRequest(
            type: .approval,
            checkpointId: checkpoint.id,
            message: "Approve '\(pending.toolCall.name)'?\n\n\(formatArgs(pending.toolCall.arguments))",
            options: [
                InterruptOption(id: "approve", label: "Approve", value: "approve"),
                InterruptOption(id: "reject", label: "Reject", value: "reject"),
                InterruptOption(id: "skip", label: "Skip", value: "skip")
            ],
            metadata: ["thread_id": threadId]
        )
    }
    
    private func formatArgs(_ args: [String: AnyCodable]) -> String {
        args.map { "\($0.key): \($0.value.value)" }.joined(separator: ", ")
    }
}

public struct InterruptibleResult: Sendable {
    public let agentResult: AgentResult
    public let threadId: String
    public let checkpoint: Checkpoint
    public let pendingInterrupt: InterruptRequest?
    
    public var success: Bool { agentResult.success }
    public var output: String { agentResult.output }
}
