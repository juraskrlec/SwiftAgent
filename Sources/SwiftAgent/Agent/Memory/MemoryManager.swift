//
//  MemoryManager.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 14.02.2026..
//

import Foundation

/// Manages both short-term and long-term memory
public actor MemoryManager {
    private let store: MemoryStore
    private let embeddingProvider: EmbeddingProvider?
    private let llmProvider: LLMProvider
    
    public init(
        store: MemoryStore,
        embeddingProvider: EmbeddingProvider? = nil,
        llmProvider: LLMProvider
    ) {
        self.store = store
        self.embeddingProvider = embeddingProvider
        self.llmProvider = llmProvider
    }
    
    // MARK: - Working Memory (Short-Term)
    
    /// Get or create working memory for a thread
    public func getWorkingMemory(threadId: String) async throws -> WorkingMemory {
        if let existing = try await store.loadWorkingMemory(threadId: threadId) {
            return existing
        }
        
        return WorkingMemory()
    }
    
    /// Update working memory from messages
    public func updateWorkingMemory(
        threadId: String,
        messages: [Message],
        userId: String
    ) async throws {
        var memory = try await getWorkingMemory(threadId: threadId)
        
        // Extract entities and facts from recent messages
        let recentMessages = Array(messages.suffix(5))
        let conversationText = recentMessages.map { $0.content }.joined(separator: "\n")
        
        // Use LLM to extract structured information
        let extractionPrompt = """
        Analyze this conversation and extract:
        1. Named entities (people, organizations, locations, projects)
        2. Key facts mentioned
        3. Important context
        
        Conversation:
        \(conversationText)
        
        Respond in JSON format:
        {
            "entities": [{"name": "...", "type": "person/organization/location/project", "attributes": {...}}],
            "facts": [{"content": "...", "confidence": 0.0-1.0}],
            "context": {"key": "value"}
        }
        """
        
        let response = try await llmProvider.generate(
            messages: [.user(extractionPrompt)],
            tools: nil,
            options: .default
        )
        
        // Parse and update memory
        if let data = response.content.data(using: .utf8),
           let extracted = try? JSONDecoder().decode(ExtractedInfo.self, from: data) {
            
            // Update entities
            for entityInfo in extracted.entities {
                let entity = Entity(
                    type: Entity.EntityType(rawValue: entityInfo.type) ?? .other,
                    name: entityInfo.name,
                    attributes: entityInfo.attributes
                )
                memory.upsertEntity(entity)
            }
            
            // Update facts
            for factInfo in extracted.facts {
                let fact = Fact(
                    content: factInfo.content,
                    confidence: factInfo.confidence,
                    source: "conversation:\(threadId)"
                )
                memory.addFact(fact)
            }
            
            // Update context
            for (key, value) in extracted.context {
                memory.setContext(key: key, value: value)
            }
        }
        
        // Create summary of recent conversation
        if recentMessages.count >= 3 {
            memory.recentSummary = try await summarizeConversation(messages: recentMessages)
        }
        
        // Save updated memory
        try await store.saveWorkingMemory(memory, threadId: threadId)
    }
    
    // MARK: - Long-Term Memory
    
    /// Save conversation as episodic memory
    public func saveEpisode(
        userId: String,
        threadId: String,
        messages: [Message],
        importance: Double = 0.5
    ) async throws {
        // Summarize the conversation
        let summary = try await summarizeConversation(messages: messages)
        
        // Extract key points
        let keyPoints = try await extractKeyPoints(messages: messages)
        
        // Get entities from working memory
        let workingMemory = try await getWorkingMemory(threadId: threadId)
        let entityIds = workingMemory.entities.keys.map { $0 }
        
        // Create episode
        let episode = Episode(
            userId: userId,
            threadId: threadId,
            summary: summary,
            keyPoints: keyPoints,
            entities: entityIds,
            importance: importance,
            startTime: messages.first?.timestamp ?? Date(),
            endTime: messages.last?.timestamp ?? Date()
        )
        
        try await store.saveEpisode(episode)
        
        // Extract and save semantic knowledge
        try await extractAndSaveKnowledge(userId: userId, messages: messages, episodeId: episode.id)
    }
    
    /// Get user profile
    public func getUserProfile(userId: String) async throws -> UserProfile {
        if let existing = try await store.loadProfile(userId: userId) {
            return existing
        }
        
        // Create new profile
        let profile = UserProfile(userId: userId)
        try await store.saveProfile(profile)
        return profile
    }
    
    /// Update user profile
    public func updateProfile(_ profile: UserProfile) async throws {
        var updated = profile
        updated.updatedAt = Date()
        try await store.saveProfile(updated)
    }
    
    /// Retrieve relevant memories for current context
    public func recallMemories(
        userId: String,
        query: String,
        includeEpisodes: Bool = true,
        includeSemanticMemory: Bool = true,
        limit: Int = 5
    ) async throws -> MemoryRecall {
        var recall = MemoryRecall()
        
        // Search episodes
        if includeEpisodes {
            recall.episodes = try await store.searchEpisodes(
                userId: userId,
                query: query,
                limit: limit
            )
        }
        
        // Search semantic memory
        if includeSemanticMemory {
            recall.semanticMemories = try await store.searchSemanticMemory(
                userId: userId,
                query: query,
                limit: limit
            )
        }
        
        // Get user profile
        recall.profile = try await getUserProfile(userId: userId)
        
        return recall
    }
    
    // MARK: - Private Helpers
    
    private func summarizeConversation(messages: [Message]) async throws -> String {
        let conversationText = messages.map { message in
            "\(message.role.rawValue): \(message.content)"
        }.joined(separator: "\n")
        
        let prompt = """
        Summarize this conversation in 2-3 sentences. Focus on key topics and outcomes.
        
        Conversation:
        \(conversationText)
        
        Summary:
        """
        
        let response = try await llmProvider.generate(
            messages: [.user(prompt)],
            tools: nil,
            options: GenerationOptions(maxTokens: 200, temperature: 0.3)
        )
        
        return response.content
    }
    
    private func extractKeyPoints(messages: [Message]) async throws -> [String] {
        let conversationText = messages.map { $0.content }.joined(separator: "\n")
        
        let prompt = """
        Extract 3-5 key points from this conversation. Return as a JSON array of strings.
        
        Conversation:
        \(conversationText)
        
        Key points:
        """
        
        let response = try await llmProvider.generate(
            messages: [.user(prompt)],
            tools: nil,
            options: GenerationOptions(maxTokens: 300, temperature: 0.3)
        )
        
        if let data = response.content.data(using: .utf8),
           let keyPoints = try? JSONDecoder().decode([String].self, from: data) {
            return keyPoints
        }
        
        return []
    }
    
    private func extractAndSaveKnowledge(
        userId: String,
        messages: [Message],
        episodeId: String
    ) async throws {
        let conversationText = messages.map { $0.content }.joined(separator: "\n")
        
        let prompt = """
        Extract general knowledge or learnings from this conversation that might be useful in future conversations.
        Return as JSON array:
        [{"category": "...", "content": "...", "confidence": 0.0-1.0}]
        
        Conversation:
        \(conversationText)
        """
        
        let response = try await llmProvider.generate(
            messages: [.user(prompt)],
            tools: nil,
            options: .default
        )
        
        if let data = response.content.data(using: .utf8),
           let knowledge = try? JSONDecoder().decode([KnowledgeExtraction].self, from: data) {
            
            for item in knowledge {
                let memory = SemanticMemory(
                    userId: userId,
                    category: item.category,
                    content: item.content,
                    confidence: item.confidence,
                    sources: [episodeId]
                )
                
                try await store.saveSemanticMemory(memory)
            }
        }
    }
}

// MARK: - Supporting Types

struct ExtractedInfo: Codable {
    let entities: [EntityInfo]
    let facts: [FactInfo]
    let context: [String: String]
    
    struct EntityInfo: Codable {
        let name: String
        let type: String
        let attributes: [String: String]
    }
    
    struct FactInfo: Codable {
        let content: String
        let confidence: Double
    }
}

struct KnowledgeExtraction: Codable {
    let category: String
    let content: String
    let confidence: Double
}

public struct MemoryRecall: Sendable {
    public var profile: UserProfile?
    public var episodes: [Episode] = []
    public var semanticMemories: [SemanticMemory] = []
}
