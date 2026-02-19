//
//  SwiftDataMemoryStore.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 19.02.2026..
//

import Foundation
import SwiftData

public struct SwiftDataMemoryStoreConfiguration: Sendable {
    public var enableCloudSync: Bool
    public var isStoredInMemoryOnly: Bool
    public var cloudKitContainerIdentifier: String?
    
    public init(enableCloudSync: Bool = false, isStoredInMemoryOnly: Bool = false, cloudKitContainerIdentifier: String? = nil) {
        self.enableCloudSync = enableCloudSync
        self.isStoredInMemoryOnly = isStoredInMemoryOnly
        self.cloudKitContainerIdentifier = cloudKitContainerIdentifier
    }
    
    public static let local = SwiftDataMemoryStoreConfiguration(enableCloudSync: false)
    public static let iCloud = SwiftDataMemoryStoreConfiguration(enableCloudSync: true)
    public static let temporary = SwiftDataMemoryStoreConfiguration(isStoredInMemoryOnly: true)
}

public actor SwiftDataMemoryStore: MemoryStore {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    public init(configuration: SwiftDataMemoryStoreConfiguration = .local) throws {
        let schema = Schema([
            UserProfileModel.self,
            EpisodeModel.self,
            SemanticMemoryModel.self,
            WorkingMemoryModel.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: configuration.isStoredInMemoryOnly,
            groupContainer: configuration.cloudKitContainerIdentifier.map { .identifier($0) } ?? .automatic,
            cloudKitDatabase: configuration.enableCloudSync ? .automatic : .none
        )
        
        self.modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        self.modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = true
    }
    
    // MARK: - User Profile
    
    public func saveProfile(_ profile: UserProfile) async throws {
        let model = try UserProfileModel.from(profile)
        
        // Check if profile exists
        let descriptor = FetchDescriptor<UserProfileModel>(
            predicate: #Predicate { $0.userId == profile.userId }
        )
        
        let existing = try modelContext.fetch(descriptor).first
        
        if let existing = existing {
            // Update existing
            existing.name = model.name
            existing.preferencesData = model.preferencesData
            existing.interests = model.interests
            existing.expertiseData = model.expertiseData
            existing.communicationStyle = model.communicationStyle
            existing.metadataData = model.metadataData
            existing.updatedAt = Date()
        } else {
            // Insert new
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
        
        // Check if episode exists
        let descriptor = FetchDescriptor<EpisodeModel>(
            predicate: #Predicate { $0.id == episode.id }
        )
        
        let existing = try modelContext.fetch(descriptor).first
        
        if existing == nil {
            modelContext.insert(model)
            try modelContext.save()
        }
    }
    
    public func loadEpisodes(userId: String, limit: Int) async throws -> [Episode] {
        var descriptor = FetchDescriptor<EpisodeModel>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.endTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        let models = try modelContext.fetch(descriptor)
        return try models.map { try $0.toEpisode() }
    }
    
    public func searchEpisodes(userId: String, query: String, limit: Int) async throws -> [Episode] {
        let descriptor = FetchDescriptor<EpisodeModel>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.importance, order: .reverse)]
        )
        
        let models = try modelContext.fetch(descriptor)
        
        let filtered = models.filter { model in
            model.summary.localizedStandardContains(query) ||
            model.keyPoints.contains(where: { $0.localizedStandardContains(query) })
        }
        
        let episodes = try filtered.map { try $0.toEpisode() }
        return Array(episodes.prefix(limit))
    }
    
    // MARK: - Semantic Memory
    
    public func saveSemanticMemory(_ memory: SemanticMemory) async throws {
        let model = SemanticMemoryModel.from(memory)
        
        let descriptor = FetchDescriptor<SemanticMemoryModel>(
            predicate: #Predicate { $0.id == memory.id }
        )
        
        let existing = try modelContext.fetch(descriptor).first
        
        if existing == nil {
            modelContext.insert(model)
            try modelContext.save()
        }
    }
    
    public func loadSemanticMemories(userId: String, category: String?, limit: Int) async throws -> [SemanticMemory] {
        let predicate: Predicate<SemanticMemoryModel>
        
        if let category = category {
            predicate = #Predicate { model in
                model.userId == userId && model.category == category
            }
        } else {
            predicate = #Predicate { $0.userId == userId }
        }
        
        var descriptor = FetchDescriptor<SemanticMemoryModel>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.lastAccessed, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toSemanticMemory() }
    }
    
    public func searchSemanticMemory(userId: String, query: String, limit: Int) async throws -> [SemanticMemory] {
        // Fetch all semantic memories for the user first
        let descriptor = FetchDescriptor<SemanticMemoryModel>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.confidence, order: .reverse)]
        )
        
        let models = try modelContext.fetch(descriptor)
        
        let filtered = models.filter { model in
            model.content.localizedStandardContains(query) ||
            model.category.localizedStandardContains(query) ||
            model.relatedConcepts.contains(where: { $0.localizedStandardContains(query) })
        }
        
        let memories = filtered.map { $0.toSemanticMemory() }
        return Array(memories.prefix(limit))
    }
    
    // MARK: - Working Memory
    
    public func saveWorkingMemory(_ memory: WorkingMemory, threadId: String) async throws {
        let model = try WorkingMemoryModel.from(memory, threadId: threadId)
        
        let descriptor = FetchDescriptor<WorkingMemoryModel>(
            predicate: #Predicate { $0.threadId == threadId }
        )
        
        let existing = try modelContext.fetch(descriptor).first
        
        if let existing = existing {
            existing.entitiesData = model.entitiesData
            existing.factsData = model.factsData
            existing.contextData = model.contextData
            existing.recentSummary = model.recentSummary
            existing.lastUpdated = model.lastUpdated
        } else {
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
        
        if let model = try modelContext.fetch(descriptor).first {
            modelContext.delete(model)
            try modelContext.save()
        }
    }
}
