//
//  MemoryStore.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 14.02.2026..
//

import Foundation

/// Protocol for memory storage
public protocol MemoryStore: Sendable {
    // User Profile
    func saveProfile(_ profile: UserProfile) async throws
    func loadProfile(userId: String) async throws -> UserProfile?
    
    // Episodes (past conversations)
    func saveEpisode(_ episode: Episode) async throws
    func loadEpisodes(userId: String, limit: Int) async throws -> [Episode]
    func searchEpisodes(userId: String, query: String, limit: Int) async throws -> [Episode]
    
    // Semantic Memory (learned knowledge)
    func saveSemanticMemory(_ memory: SemanticMemory) async throws
    func loadSemanticMemories(userId: String, category: String?, limit: Int) async throws -> [SemanticMemory]
    func searchSemanticMemory(userId: String, query: String, limit: Int) async throws -> [SemanticMemory]
    
    // Working Memory (short-term)
    func saveWorkingMemory(_ memory: WorkingMemory, threadId: String) async throws
    func loadWorkingMemory(threadId: String) async throws -> WorkingMemory?
    func clearWorkingMemory(threadId: String) async throws
}

/// In-memory implementation
public actor InMemoryMemoryStore: MemoryStore {
    private var profiles: [String: UserProfile] = [:]
    private var episodes: [String: [Episode]] = [:]
    private var semanticMemories: [String: [SemanticMemory]] = [:]
    private var workingMemories: [String: WorkingMemory] = [:]
    
    public init() {}
    
    // MARK: - User Profile
    
    public func saveProfile(_ profile: UserProfile) async throws {
        profiles[profile.userId] = profile
    }
    
    public func loadProfile(userId: String) async throws -> UserProfile? {
        return profiles[userId]
    }
    
    // MARK: - Episodes
    
    public func saveEpisode(_ episode: Episode) async throws {
        if episodes[episode.userId] == nil {
            episodes[episode.userId] = []
        }
        episodes[episode.userId]?.append(episode)
    }
    
    public func loadEpisodes(userId: String, limit: Int) async throws -> [Episode] {
        guard let userEpisodes = episodes[userId] else { return [] }
        return Array(userEpisodes.sorted { $0.endTime > $1.endTime }.prefix(limit))
    }
    
    public func searchEpisodes(userId: String, query: String, limit: Int) async throws -> [Episode] {
        guard let userEpisodes = episodes[userId] else { return [] }
        
        let results = userEpisodes.filter { episode in
            episode.summary.localizedCaseInsensitiveContains(query) ||
            episode.keyPoints.contains { $0.localizedCaseInsensitiveContains(query) }
        }
        
        return Array(results.sorted { $0.importance > $1.importance }.prefix(limit))
    }
    
    // MARK: - Semantic Memory
    
    public func saveSemanticMemory(_ memory: SemanticMemory) async throws {
        if semanticMemories[memory.userId] == nil {
            semanticMemories[memory.userId] = []
        }
        semanticMemories[memory.userId]?.append(memory)
    }
    
    public func loadSemanticMemories(userId: String, category: String?, limit: Int) async throws -> [SemanticMemory] {
        guard var userMemories = semanticMemories[userId] else { return [] }
        
        if let category = category {
            userMemories = userMemories.filter { $0.category == category }
        }
        
        return Array(userMemories.sorted { $0.lastAccessed > $1.lastAccessed }.prefix(limit))
    }
    
    public func searchSemanticMemory(userId: String, query: String, limit: Int) async throws -> [SemanticMemory] {
        guard let userMemories = semanticMemories[userId] else { return [] }
        
        let results = userMemories.filter { memory in
            memory.content.localizedCaseInsensitiveContains(query) ||
            memory.category.localizedCaseInsensitiveContains(query)
        }
        
        return Array(results.sorted { $0.confidence > $1.confidence }.prefix(limit))
    }
    
    // MARK: - Working Memory
    
    public func saveWorkingMemory(_ memory: WorkingMemory, threadId: String) async throws {
        workingMemories[threadId] = memory
    }
    
    public func loadWorkingMemory(threadId: String) async throws -> WorkingMemory? {
        return workingMemories[threadId]
    }
    
    public func clearWorkingMemory(threadId: String) async throws {
        workingMemories.removeValue(forKey: threadId)
    }
}
