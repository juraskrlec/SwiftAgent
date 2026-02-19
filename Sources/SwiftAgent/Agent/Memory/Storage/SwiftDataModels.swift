//
//  SwiftDataModels.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 19.02.2026..
//

import Foundation
import SwiftData

// MARK: - User Profile Model

@Model
public final class UserProfileModel {
    public var userId: String
    public var name: String?
    public var preferencesData: Data // JSON encoded [String: String]
    public var interests: [String]
    public var expertiseData: Data // JSON encoded [String: String]
    public var communicationStyle: String
    public var metadataData: Data // JSON encoded [String: String]
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        userId: String,
        name: String? = nil,
        preferencesData: Data = Data(),
        interests: [String] = [],
        expertiseData: Data = Data(),
        communicationStyle: String = "detailed",
        metadataData: Data = Data(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.name = name
        self.preferencesData = preferencesData
        self.interests = interests
        self.expertiseData = expertiseData
        self.communicationStyle = communicationStyle
        self.metadataData = metadataData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public func toUserProfile() throws -> UserProfile {
        let preferences = try JSONDecoder().decode([String: String].self, from: preferencesData)
        let expertise = try JSONDecoder().decode([String: String].self, from: expertiseData)
        let metadata = try JSONDecoder().decode([String: String].self, from: metadataData)
        
        return UserProfile(
            userId: userId,
            name: name,
            preferences: preferences,
            interests: interests,
            expertise: expertise.mapValues { UserProfile.ExpertiseLevel(rawValue: $0) ?? .beginner },
            communicationStyle: UserProfile.CommunicationStyle(rawValue: communicationStyle) ?? .detailed,
            metadata: metadata,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    public static func from(_ profile: UserProfile) throws -> UserProfileModel {
        let preferencesData = try JSONEncoder().encode(profile.preferences)
        let expertiseData = try JSONEncoder().encode(profile.expertise.mapValues { $0.rawValue })
        let metadataData = try JSONEncoder().encode(profile.metadata)
        
        return UserProfileModel(
            userId: profile.userId,
            name: profile.name,
            preferencesData: preferencesData,
            interests: profile.interests,
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
public final class EpisodeModel {
    public var id: String
    public var userId: String
    public var threadId: String
    public var summary: String
    public var keyPoints: [String]
    public var entities: [String]
    public var sentiment: String
    public var importance: Double
    public var startTime: Date
    public var endTime: Date
    public var metadataData: Data
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        threadId: String,
        summary: String,
        keyPoints: [String] = [],
        entities: [String] = [],
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
        self.keyPoints = keyPoints
        self.entities = entities
        self.sentiment = sentiment
        self.importance = importance
        self.startTime = startTime
        self.endTime = endTime
        self.metadataData = metadataData
    }
    
    public func toEpisode() throws -> Episode {
        let metadata = try JSONDecoder().decode([String: String].self, from: metadataData)
        
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
    
    public static func from(_ episode: Episode) throws -> EpisodeModel {
        let metadataData = try JSONEncoder().encode(episode.metadata)
        
        return EpisodeModel(
            id: episode.id,
            userId: episode.userId,
            threadId: episode.threadId,
            summary: episode.summary,
            keyPoints: episode.keyPoints,
            entities: episode.entities,
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
public final class SemanticMemoryModel {
    public var id: String
    public var userId: String
    public var category: String
    public var content: String
    public var relatedConcepts: [String]
    public var confidence: Double
    public var sources: [String]
    public var createdAt: Date
    public var lastAccessed: Date
    public var accessCount: Int
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        category: String,
        content: String,
        relatedConcepts: [String] = [],
        confidence: Double = 1.0,
        sources: [String] = [],
        createdAt: Date = Date(),
        lastAccessed: Date = Date(),
        accessCount: Int = 0
    ) {
        self.id = id
        self.userId = userId
        self.category = category
        self.content = content
        self.relatedConcepts = relatedConcepts
        self.confidence = confidence
        self.sources = sources
        self.createdAt = createdAt
        self.lastAccessed = lastAccessed
        self.accessCount = accessCount
    }
    
    public func toSemanticMemory() -> SemanticMemory {
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
    
    public static func from(_ memory: SemanticMemory) -> SemanticMemoryModel {
        return SemanticMemoryModel(
            id: memory.id,
            userId: memory.userId,
            category: memory.category,
            content: memory.content,
            relatedConcepts: memory.relatedConcepts,
            confidence: memory.confidence,
            sources: memory.sources,
            createdAt: memory.createdAt,
            lastAccessed: memory.lastAccessed,
            accessCount: memory.accessCount
        )
    }
}

// MARK: - Working Memory Model

@Model
public final class WorkingMemoryModel {
    public var threadId: String
    public var entitiesData: Data // JSON encoded [String: Entity]
    public var factsData: Data // JSON encoded [Fact]
    public var contextData: Data // JSON encoded [String: String]
    public var recentSummary: String?
    public var lastUpdated: Date
    
    public init(
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
    
    public func toWorkingMemory() throws -> WorkingMemory {
        let entities = try JSONDecoder().decode([String: Entity].self, from: entitiesData)
        let facts = try JSONDecoder().decode([Fact].self, from: factsData)
        let context = try JSONDecoder().decode([String: String].self, from: contextData)
        
        return WorkingMemory(
            entities: entities,
            facts: facts,
            context: context,
            recentSummary: recentSummary,
            lastUpdated: lastUpdated
        )
    }
    
    public static func from(_ memory: WorkingMemory, threadId: String) throws -> WorkingMemoryModel {
        let entitiesData = try JSONEncoder().encode(memory.entities)
        let factsData = try JSONEncoder().encode(memory.facts)
        let contextData = try JSONEncoder().encode(memory.context)
        
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
