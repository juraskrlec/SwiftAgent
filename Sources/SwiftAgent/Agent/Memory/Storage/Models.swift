//
//  Models.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 14.02.2026..
//

import Foundation
import SwiftData

// MARK: - User Profile Model

@Model
final class UserProfileModel {
    @Attribute(.unique) var userId: String
    var name: String?
    var preferencesData: Data
    var interestsData: Data
    var expertiseData: Data
    var communicationStyle: String
    var metadataData: Data
    var createdAt: Date
    var updatedAt: Date
    
    init(
        userId: String,
        name: String? = nil,
        preferencesData: Data = Data(),
        interestsData: Data = Data(),
        expertiseData: Data = Data(),
        communicationStyle: String = "detailed",
        metadataData: Data = Data(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.name = name
        self.preferencesData = preferencesData
        self.interestsData = interestsData
        self.expertiseData = expertiseData
        self.communicationStyle = communicationStyle
        self.metadataData = metadataData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Convert to UserProfile
    func toUserProfile() throws -> UserProfile {
        let decoder = JSONDecoder()
        
        let preferences = try decoder.decode([String: String].self, from: preferencesData)
        let interests = try decoder.decode([String].self, from: interestsData)
        let expertiseDict = try decoder.decode([String: String].self, from: expertiseData)
        let expertise = expertiseDict.compactMapValues { UserProfile.ExpertiseLevel(rawValue: $0) }
        let metadata = try decoder.decode([String: String].self, from: metadataData)
        
        return UserProfile(
            userId: userId,
            name: name,
            preferences: preferences,
            interests: interests,
            expertise: expertise,
            communicationStyle: UserProfile.CommunicationStyle(rawValue: communicationStyle) ?? .detailed,
            metadata: metadata,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    // Create from UserProfile
    static func from(_ profile: UserProfile) throws -> UserProfileModel {
        let encoder = JSONEncoder()
        
        let preferencesData = try encoder.encode(profile.preferences)
        let interestsData = try encoder.encode(profile.interests)
        let expertiseDict = profile.expertise.mapValues { $0.rawValue }
        let expertiseData = try encoder.encode(expertiseDict)
        let metadataData = try encoder.encode(profile.metadata)
        
        return UserProfileModel(
            userId: profile.userId,
            name: profile.name,
            preferencesData: preferencesData,
            interestsData: interestsData,
            expertiseData: expertiseData,
            communicationStyle: profile.communicationStyle.rawValue,
            metadataData: metadataData,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt
        )
    }
}

// MARK: - Episode Model

@Model
final class EpisodeModel {
    @Attribute(.unique) var id: String
    var userId: String
    var threadId: String
    var summary: String
    var keyPointsData: Data
    var entitiesData: Data
    var sentiment: String
    var importance: Double
    var startTime: Date
    var endTime: Date
    var metadataData: Data
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        threadId: String,
        summary: String,
        keyPointsData: Data = Data(),
        entitiesData: Data = Data(),
        sentiment: String = "neutral",
        importance: Double = 0.5,
        startTime: Date,
        endTime: Date = Date(),
        metadataData: Data = Data()
    ) {
        self.id = id
        self.userId = userId
        self.threadId = threadId
        self.summary = summary
        self.keyPointsData = keyPointsData
        self.entitiesData = entitiesData
        self.sentiment = sentiment
        self.importance = importance
        self.startTime = startTime
        self.endTime = endTime
        self.metadataData = metadataData
    }
    
    func toEpisode() throws -> Episode {
        let decoder = JSONDecoder()
        
        let keyPoints = try decoder.decode([String].self, from: keyPointsData)
        let entities = try decoder.decode([String].self, from: entitiesData)
        let metadata = try decoder.decode([String: String].self, from: metadataData)
        
        return Episode(
            id: id,
            userId: userId,
            threadId: threadId,
            summary: summary,
            keyPoints: keyPoints,
            entities: entities,
            sentiment: Episode.Sentiment(rawValue: sentiment) ?? .neutral,
            importance: importance,
            startTime: startTime,
            endTime: endTime,
            metadata: metadata
        )
    }
    
    static func from(_ episode: Episode) throws -> EpisodeModel {
        let encoder = JSONEncoder()
        
        let keyPointsData = try encoder.encode(episode.keyPoints)
        let entitiesData = try encoder.encode(episode.entities)
        let metadataData = try encoder.encode(episode.metadata)
        
        return EpisodeModel(
            id: episode.id,
            userId: episode.userId,
            threadId: episode.threadId,
            summary: episode.summary,
            keyPointsData: keyPointsData,
            entitiesData: entitiesData,
            sentiment: episode.sentiment.rawValue,
            importance: episode.importance,
            startTime: episode.startTime,
            endTime: episode.endTime,
            metadataData: metadataData
        )
    }
}

// MARK: - Semantic Memory Model

@Model
final class SemanticMemoryModel {
    @Attribute(.unique) var id: String
    var userId: String
    var category: String
    var content: String
    var relatedConceptsData: Data
    var confidence: Double
    var sourcesData: Data
    var createdAt: Date
    var lastAccessed: Date
    var accessCount: Int
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        category: String,
        content: String,
        relatedConceptsData: Data = Data(),
        confidence: Double = 1.0,
        sourcesData: Data = Data(),
        createdAt: Date = Date(),
        lastAccessed: Date = Date(),
        accessCount: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.category = category
        self.content = content
        self.relatedConceptsData = relatedConceptsData
        self.confidence = confidence
        self.sourcesData = sourcesData
        self.createdAt = createdAt
        self.lastAccessed = lastAccessed
        self.accessCount = accessCount
    }
    
    func toSemanticMemory() throws -> SemanticMemory {
        let decoder = JSONDecoder()
        
        let relatedConcepts = try decoder.decode([String].self, from: relatedConceptsData)
        let sources = try decoder.decode([String].self, from: sourcesData)
        
        return SemanticMemory(
            id: id,
            userId: userId,
            category: category,
            content: content,
            relatedConcepts: relatedConcepts,
            confidence: confidence,
            sources: sources,
            createdAt: createdAt,
            lastAccessed: lastAccessed,
            accessCount: accessCount
        )
    }
    
    static func from(_ memory: SemanticMemory) throws -> SemanticMemoryModel {
        let encoder = JSONEncoder()
        
        let relatedConceptsData = try encoder.encode(memory.relatedConcepts)
        let sourcesData = try encoder.encode(memory.sources)
        
        return SemanticMemoryModel(
            id: memory.id,
            userId: memory.userId,
            category: memory.category,
            content: memory.content,
            relatedConceptsData: relatedConceptsData,
            confidence: memory.confidence,
            sourcesData: sourcesData,
            createdAt: memory.createdAt,
            lastAccessed: memory.lastAccessed,
            accessCount: memory.accessCount
        )
    }
}

// MARK: - Working Memory Model

@Model
final class WorkingMemoryModel {
    @Attribute(.unique) var threadId: String
    var entitiesData: Data
    var factsData: Data
    var contextData: Data
    var recentSummary: String?
    var lastUpdated: Date
    
    init(
        threadId: String,
        entitiesData: Data = Data(),
        factsData: Data = Data(),
        contextData: Data = Data(),
        recentSummary: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.threadId = threadId
        self.entitiesData = entitiesData
        self.factsData = factsData
        self.contextData = contextData
        self.recentSummary = recentSummary
        self.lastUpdated = lastUpdated
    }
    
    func toWorkingMemory() throws -> WorkingMemory {
        let decoder = JSONDecoder()
        
        let entities = try decoder.decode([String: Entity].self, from: entitiesData)
        let facts = try decoder.decode([Fact].self, from: factsData)
        let context = try decoder.decode([String: String].self, from: contextData)
        
        return WorkingMemory(
            entities: entities,
            facts: facts,
            context: context,
            recentSummary: recentSummary,
            lastUpdated: lastUpdated
        )
    }
    
    static func from(_ memory: WorkingMemory, threadId: String) throws -> WorkingMemoryModel {
        let encoder = JSONEncoder()
        
        let entitiesData = try encoder.encode(memory.entities)
        let factsData = try encoder.encode(memory.facts)
        let contextData = try encoder.encode(memory.context)
        
        return WorkingMemoryModel(
            threadId: threadId,
            entitiesData: entitiesData,
            factsData: factsData,
            contextData: contextData,
            recentSummary: memory.recentSummary,
            lastUpdated: memory.lastUpdated
        )
    }
}
