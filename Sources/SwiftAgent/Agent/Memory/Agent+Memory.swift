//
//  Agent+Memory.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 14.02.2026..
//

import Foundation

public struct MemoryConfig: Sendable {
    public let manager: MemoryManager
    public let userId: String
    public let autoSave: Bool
    
    public init(manager: MemoryManager, userId: String, autoSave: Bool = true) {
        self.manager = manager
        self.userId = userId
        self.autoSave = autoSave
    }
}

extension Agent {
    /// Run with memory
    public func runWithMemory(
        task: String,
        config: MemoryConfig,
        threadId: String = UUID().uuidString
    ) async throws -> AgentResult {
        // Load memories
        let profile = try await config.manager.getUserProfile(userId: config.userId)
        let memories = try await config.manager.recallMemories(userId: config.userId, query: task, limit: 3)
        let workingMemory = try await config.manager.getWorkingMemory(threadId: threadId)
        
        // Build context
        let context = buildMemoryContext(profile: profile, memories: memories, workingMemory: workingMemory)
        
        // Run with context
        let enhancedTask = "\(context)\n\n---\n\n\(task)"
        let result = try await self.run(task: enhancedTask)
        
        // Update memory
        if config.autoSave {
            try await config.manager.updateWorkingMemory(threadId: threadId, messages: result.state.messages, userId: config.userId)
            
            if result.success {
                try await config.manager.saveEpisode(userId: config.userId, threadId: threadId, messages: result.state.messages, importance: 0.5)
            }
        }
        
        return result
    }
    
    private func buildMemoryContext(profile: UserProfile, memories: MemoryRecall, workingMemory: WorkingMemory) -> String {
        var context = "# Context\n"
        
        if let name = profile.name {
            context += "User: \(name)\n"
        }
        
        if !memories.episodes.isEmpty {
            context += "Past: \(memories.episodes.first!.summary)\n"
        }
        
        if let summary = workingMemory.recentSummary {
            context += "Recent: \(summary)\n"
        }
        
        return context
    }
}
