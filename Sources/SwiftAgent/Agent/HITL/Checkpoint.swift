//
//  Checkpoint.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 13.02.2026..
//

import Foundation

/// Represents a saved state at a specific point in execution
public struct Checkpoint: Codable, Sendable {
    public let id: String
    public let timestamp: Date
    public let state: AgentState
    public let pendingAction: PendingAction?
    public let metadata: [String: String]
    
    public init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        state: AgentState,
        pendingAction: PendingAction? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.state = state
        self.pendingAction = pendingAction
        self.metadata = metadata
    }
}

/// Action waiting for approval or modification
public struct PendingAction: Codable, Sendable {
    public let toolCall: ToolCall
    public let severity: String
    public let description: String
    public let alternatives: [String]
    
    public init(
        toolCall: ToolCall,
        severity: String = "high",
        description: String,
        alternatives: [String] = []
    ) {
        self.toolCall = toolCall
        self.severity = severity
        self.description = description
        self.alternatives = alternatives
    }
}

/// Protocol for checkpoint storage
public protocol CheckpointStore: Sendable {
    /// Save a checkpoint
    func save(_ checkpoint: Checkpoint) async throws
    
    /// Load a checkpoint by ID
    func load(id: String) async throws -> Checkpoint?
    
    /// List all checkpoints for a thread
    func list(threadId: String) async throws -> [Checkpoint]
    
    /// Delete a checkpoint
    func delete(id: String) async throws
    
    /// Get latest checkpoint for a thread
    func latest(threadId: String) async throws -> Checkpoint?
}

/// In-memory checkpoint store
public actor InMemoryCheckpointStore: CheckpointStore {
    private var checkpoints: [String: Checkpoint] = [:]
    private var threadCheckpoints: [String: [String]] = [:]
    
    public init() {}
    
    public func save(_ checkpoint: Checkpoint) async throws {
        checkpoints[checkpoint.id] = checkpoint
        
        // Track by thread
        let threadId = checkpoint.metadata["thread_id"] ?? "default"
        if threadCheckpoints[threadId] == nil {
            threadCheckpoints[threadId] = []
        }
        threadCheckpoints[threadId]?.append(checkpoint.id)
    }
    
    public func load(id: String) async throws -> Checkpoint? {
        return checkpoints[id]
    }
    
    public func list(threadId: String) async throws -> [Checkpoint] {
        guard let ids = threadCheckpoints[threadId] else {
            return []
        }
        
        return ids.compactMap { checkpoints[$0] }
    }
    
    public func delete(id: String) async throws {
        checkpoints.removeValue(forKey: id)
        
        // Remove from thread tracking
        for (threadId, ids) in threadCheckpoints {
            if let index = ids.firstIndex(of: id) {
                threadCheckpoints[threadId]?.remove(at: index)
            }
        }
    }
    
    public func latest(threadId: String) async throws -> Checkpoint? {
        guard let ids = threadCheckpoints[threadId], let lastId = ids.last else {
            return nil
        }
        
        return checkpoints[lastId]
    }
}
