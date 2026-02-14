//
//  SwiftDataMemoryStore.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 14.02.2026..
//

import Foundation
import SwiftData

@ModelActor
public actor SwiftDataMemoryStore: MemoryStore {
    
    // MARK: - User Profile
    
    public func saveProfile(_ profile: UserProfile) async throws {
        // Try to find existing
        let descriptor = FetchDescriptor<UserProfileModel>(
            predicate: #Predicate { $0.userId == profile.userId }
        )
        
        let existing = try modelContext.fetch(descriptor).first
        
        if let existing = existing {
            // Update existing
            let updated = try UserProfileModel.from(profile)
            existing.name = updated.name
            existing.preferencesData = updated.preferencesData
            existing.interestsData = updated.interestsData
            existing.expertiseData = updated.expertiseData
            existing.communicationStyle = updated.communicationStyle
            existing.metadataData = updated.metadataData
            existing.updatedAt = Date()
        } else {
            let model = try UserProfileModel.from(profile)
            modelContext.insert(model)
        }
        
        try modelContext.save()
    }
    
    public func loadProfile(userId: String) async throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfileModel>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        
        return try model.toUserProfile()
    }
    
    // MARK: - Episodes
    
    public func saveEpisode(_ episode: Episode) async throws {
        let model = try EpisodeModel.from(episode)
        modelContext.insert(model)
        try modelContext.save()
    }
    
    public func loadEpisodes(userId: String, limit: Int) async throws -> [Episode] {
        let descriptor = FetchDescriptor<EpisodeModel>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\EpisodeModel.endTime, order: .reverse)]
        )
        
        let models = try modelContext.fetch(descriptor)
        let limited = Array(models.prefix(limit))
        
        return try limited.map { try $0.toEpisode() }
    }
    
    public func searchEpisodes(userId: String, query: String, limit: Int) async throws -> [Episode] {
        let descriptor = FetchDescriptor<EpisodeModel>(
            predicate: #Predicate { model in
                model.userId == userId &&
                (model.summary.localizedStandardContains(query))
            },
            sortBy: [SortDescriptor(\EpisodeModel.importance, order: .reverse)]
        )
        
        let models = try modelContext.fetch(descriptor)
        let limited = Array(models.prefix(limit))
        
        return try limited.map { try $0.toEpisode() }
    }
    
    // MARK: - Semantic Memory
    
    public func saveSemanticMemory(_ memory: SemanticMemory) async throws {
        let model = try SemanticMemoryModel.from(memory)
        modelContext.insert(model)
        try modelContext.save()
    }
    
    public func loadSemanticMemories(userId: String, category: String?, limit: Int) async throws -> [SemanticMemory] {
        var descriptor: FetchDescriptor<SemanticMemoryModel>
        
        if let category = category {
            descriptor = FetchDescriptor<SemanticMemoryModel>(
                predicate: #Predicate { $0.userId == userId && $0.category == category },
                sortBy: [SortDescriptor(\SemanticMemoryModel.lastAccessed, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<SemanticMemoryModel>(
                predicate: #Predicate { $0.userId == userId },
                sortBy: [SortDescriptor(\SemanticMemoryModel.lastAccessed, order: .reverse)]
            )
        }
        
        let models = try modelContext.fetch(descriptor)
        let limited = Array(models.prefix(limit))
        
        return try limited.map { try $0.toSemanticMemory() }
    }
    
    public func searchSemanticMemory(userId: String, query: String, limit: Int) async throws -> [SemanticMemory] {
        let descriptor = FetchDescriptor<SemanticMemoryModel>(
            predicate: #Predicate { model in
                model.userId == userId &&
                (model.content.localizedStandardContains(query) ||
                 model.category.localizedStandardContains(query))
            },
            sortBy: [SortDescriptor(\SemanticMemoryModel.confidence, order: .reverse)]
        )
        
        let models = try modelContext.fetch(descriptor)
        let limited = Array(models.prefix(limit))
        
        return try limited.map { try $0.toSemanticMemory() }
    }
    
    // MARK: - Working Memory
    
    public func saveWorkingMemory(_ memory: WorkingMemory, threadId: String) async throws {
        // Try to find existing
        let descriptor = FetchDescriptor<WorkingMemoryModel>(
            predicate: #Predicate { $0.threadId == threadId }
        )
        
        let existing = try modelContext.fetch(descriptor).first
        
        if let existing = existing {
            // Update existing
            let updated = try WorkingMemoryModel.from(memory, threadId: threadId)
            existing.entitiesData = updated.entitiesData
            existing.factsData = updated.factsData
            existing.contextData = updated.contextData
            existing.recentSummary = updated.recentSummary
            existing.lastUpdated = Date()
        } else {
            // Insert new
            let model = try WorkingMemoryModel.from(memory, threadId: threadId)
            modelContext.insert(model)
        }
        
        try modelContext.save()
    }
    
    public func loadWorkingMemory(threadId: String) async throws -> WorkingMemory? {
        let descriptor = FetchDescriptor<WorkingMemoryModel>(
            predicate: #Predicate { $0.threadId == threadId }
        )
        
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        
        return try model.toWorkingMemory()
    }
    
    public func clearWorkingMemory(threadId: String) async throws {
        let descriptor = FetchDescriptor<WorkingMemoryModel>(
            predicate: #Predicate { $0.threadId == threadId }
        )
        
        let models = try modelContext.fetch(descriptor)
        
        for model in models {
            modelContext.delete(model)
        }
        
        try modelContext.save()
    }
}
