//
//  MemoryTypes.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 14.02.2026..
//

import Foundation

// MARK: - Short-Term Memory

/// Working memory for current conversation
public struct WorkingMemory: Codable, Sendable {
    public var entities: [String: Entity]           // Mentioned entities
    public var facts: [Fact]                        // Current facts
    public var context: [String: String]            // Key-value context
    public var recentSummary: String?               // Summary of recent messages
    public var lastUpdated: Date
    
    public init(
        entities: [String: Entity] = [:],
        facts: [Fact] = [],
        context: [String: String] = [:],
        recentSummary: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.entities = entities
        self.facts = facts
        self.context = context
        self.recentSummary = recentSummary
        self.lastUpdated = lastUpdated
    }
    
    /// Add or update an entity
    public mutating func upsertEntity(_ entity: Entity) {
        entities[entity.id] = entity
        lastUpdated = Date()
    }
    
    /// Add a fact
    public mutating func addFact(_ fact: Fact) {
        facts.append(fact)
        lastUpdated = Date()
    }
    
    /// Update context
    public mutating func setContext(key: String, value: String) {
        context[key] = value
        lastUpdated = Date()
    }
}

/// Named entity in conversation
public struct Entity: Codable, Sendable, Identifiable {
    public let id: String
    public let type: EntityType
    public var name: String
    public var attributes: [String: String]
    public var mentions: Int
    public var firstSeen: Date
    public var lastSeen: Date
    
    public enum EntityType: String, Codable, Sendable {
        case person
        case organization
        case location
        case project
        case concept
        case other
    }
    
    public init(
        id: String = UUID().uuidString,
        type: EntityType,
        name: String,
        attributes: [String: String] = [:],
        mentions: Int = 1,
        firstSeen: Date = Date(),
        lastSeen: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.attributes = attributes
        self.mentions = mentions
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
    }
}

/// Fact from conversation
public struct Fact: Codable, Sendable, Identifiable {
    public let id: String
    public let content: String
    public let confidence: Double       // 0.0 - 1.0
    public let source: String           // Where this came from
    public let timestamp: Date
    public var verified: Bool
    
    public init(
        id: String = UUID().uuidString,
        content: String,
        confidence: Double = 1.0,
        source: String,
        timestamp: Date = Date(),
        verified: Bool = false
    ) {
        self.id = id
        self.content = content
        self.confidence = confidence
        self.source = source
        self.timestamp = timestamp
        self.verified = verified
    }
}

// MARK: - Long-Term Memory

/// User profile and preferences
public struct UserProfile: Codable, Sendable {
    public let userId: String
    public var name: String?
    public var preferences: [String: String]
    public var interests: [String]
    public var expertise: [String: ExpertiseLevel]
    public var communicationStyle: CommunicationStyle
    public var metadata: [String: String]
    public var createdAt: Date
    public var updatedAt: Date
    
    public enum ExpertiseLevel: String, Codable, Sendable {
        case beginner
        case intermediate
        case advanced
        case expert
    }
    
    public enum CommunicationStyle: String, Codable, Sendable {
        case concise
        case detailed
        case casual
        case professional
    }
    
    public init(
        userId: String,
        name: String? = nil,
        preferences: [String: String] = [:],
        interests: [String] = [],
        expertise: [String: ExpertiseLevel] = [:],
        communicationStyle: CommunicationStyle = .detailed,
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.name = name
        self.preferences = preferences
        self.interests = interests
        self.expertise = expertise
        self.communicationStyle = communicationStyle
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Episodic memory - past conversations
public struct Episode: Codable, Sendable, Identifiable {
    public let id: String
    public let userId: String
    public let threadId: String
    public var summary: String
    public var keyPoints: [String]
    public var entities: [String]           // Entity IDs mentioned
    public var sentiment: Sentiment
    public var importance: Double           // 0.0 - 1.0
    public var startTime: Date
    public var endTime: Date
    public var metadata: [String: String]
    
    public enum Sentiment: String, Codable, Sendable {
        case positive
        case neutral
        case negative
        case mixed
    }
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        threadId: String,
        summary: String,
        keyPoints: [String] = [],
        entities: [String] = [],
        sentiment: Sentiment = .neutral,
        importance: Double = 0.5,
        startTime: Date,
        endTime: Date = Date(),
        metadata: [String: String] = [:]
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
        self.metadata = metadata
    }
}

/// Semantic memory - learned knowledge
public struct SemanticMemory: Codable, Sendable, Identifiable {
    public let id: String
    public let userId: String
    public var category: String
    public var content: String
    public var relatedConcepts: [String]
    public var confidence: Double
    public var sources: [String]            // Episode IDs or external sources
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
}
