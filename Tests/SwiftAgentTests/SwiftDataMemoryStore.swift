//
//  SwiftDataMemoryStore.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 19.02.2026..
//


import XCTest
import SwiftData
@testable import SwiftAgent

final class SwiftDataMemoryStoreTests: XCTestCase {
    
    var memoryStore: SwiftDataMemoryStore!
    
    override func setUp() async throws {
        try await super.setUp()
        memoryStore = try SwiftDataMemoryStore(configuration: .init(isStoredInMemoryOnly: true))
    }
    
    override func tearDown() async throws {
        memoryStore = nil
        try await super.tearDown()
    }
    
    // MARK: - User Profile Tests
    
    func testSaveAndLoadProfile() async throws {
        // Create profile
        let profile = UserProfile(
            userId: "user123",
            name: "John Doe",
            preferences: ["theme": "dark", "language": "en"],
            interests: ["Swift", "AI", "iOS"],
            expertise: ["Swift": .advanced, "Python": .intermediate],
            communicationStyle: .detailed,
            metadata: ["device": "iPhone"]
        )
        
        // Save
        try await memoryStore.saveProfile(profile)
        
        // Load
        let loaded = try await memoryStore.loadProfile(userId: "user123")
        
        // Assert
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.userId, "user123")
        XCTAssertEqual(loaded?.name, "John Doe")
        XCTAssertEqual(loaded?.preferences["theme"], "dark")
        XCTAssertEqual(loaded?.interests.count, 3)
        XCTAssertTrue(loaded?.interests.contains("Swift") ?? false)
        XCTAssertEqual(loaded?.expertise["Swift"], .advanced)
        XCTAssertEqual(loaded?.communicationStyle, .detailed)
    }
    
    func testUpdateProfile() async throws {
        // Create and save initial profile
        var profile = UserProfile(
            userId: "user123",
            name: "John Doe",
            preferences: ["theme": "dark"]
        )
        
        try await memoryStore.saveProfile(profile)
        
        // Update profile
        profile.name = "Jane Doe"
        profile.preferences["theme"] = "light"
        profile.interests.append("SwiftUI")
        
        try await memoryStore.saveProfile(profile)
        
        // Load and verify
        let loaded = try await memoryStore.loadProfile(userId: "user123")
        
        XCTAssertEqual(loaded?.name, "Jane Doe")
        XCTAssertEqual(loaded?.preferences["theme"], "light")
        XCTAssertTrue(loaded?.interests.contains("SwiftUI") ?? false)
    }
    
    func testLoadNonExistentProfile() async throws {
        let loaded = try await memoryStore.loadProfile(userId: "nonexistent")
        XCTAssertNil(loaded)
    }
    
    // MARK: - Episode Tests
    
    func testSaveAndLoadEpisodes() async throws {
        let userId = "user123"
        let startTime = Date()
        
        // Create episodes
        let episode1 = Episode(
            userId: userId,
            threadId: "thread1",
            summary: "Discussed Swift programming",
            keyPoints: ["Learned about actors", "Explored concurrency"],
            entities: ["Swift", "Concurrency"],
            sentiment: .positive,
            importance: 0.8,
            startTime: startTime.addingTimeInterval(-3600),
            endTime: startTime.addingTimeInterval(-3000)
        )
        
        let episode2 = Episode(
            userId: userId,
            threadId: "thread2",
            summary: "Talked about AI models",
            keyPoints: ["Discussed GPT", "Explored embeddings"],
            entities: ["GPT", "Embeddings"],
            sentiment: .neutral,
            importance: 0.6,
            startTime: startTime.addingTimeInterval(-1800),
            endTime: startTime
        )
        
        // Save episodes
        try await memoryStore.saveEpisode(episode1)
        try await memoryStore.saveEpisode(episode2)
        
        // Load episodes
        let loaded = try await memoryStore.loadEpisodes(userId: userId, limit: 10)
        
        // Assert
        XCTAssertEqual(loaded.count, 2)
        
        // Should be sorted by endTime descending (most recent first)
        XCTAssertEqual(loaded[0].summary, "Talked about AI models")
        XCTAssertEqual(loaded[1].summary, "Discussed Swift programming")
    }
    
    func testLoadEpisodesWithLimit() async throws {
        let userId = "user123"
        
        // Create 5 episodes
        for i in 0..<5 {
            let episode = Episode(
                userId: userId,
                threadId: "thread\(i)",
                summary: "Episode \(i)",
                keyPoints: ["Point \(i)"],
                startTime: Date().addingTimeInterval(TimeInterval(-i * 100)),
                endTime: Date().addingTimeInterval(TimeInterval(-i * 100 + 50))
            )
            try await memoryStore.saveEpisode(episode)
        }
        
        // Load with limit
        let loaded = try await memoryStore.loadEpisodes(userId: userId, limit: 3)
        
        XCTAssertEqual(loaded.count, 3)
    }
    
    func testSearchEpisodes() async throws {
        let userId = "user123"
        
        // Create episodes with different content
        let episode1 = Episode(
            userId: userId,
            threadId: "thread1",
            summary: "Discussed Swift programming",
            keyPoints: ["Swift actors", "Concurrency"],
            importance: 0.9,
            startTime: Date(),
            endTime: Date()
        )
        
        let episode2 = Episode(
            userId: userId,
            threadId: "thread2",
            summary: "Talked about Python",
            keyPoints: ["Python async", "Django"],
            importance: 0.5,
            startTime: Date(),
            endTime: Date()
        )
        
        try await memoryStore.saveEpisode(episode1)
        try await memoryStore.saveEpisode(episode2)
        
        // Search for "Swift"
        let results = try await memoryStore.searchEpisodes(
            userId: userId,
            query: "Swift",
            limit: 10
        )
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].summary, "Discussed Swift programming")
    }
    
    // MARK: - Semantic Memory Tests
    
    func testSaveAndLoadSemanticMemory() async throws {
        let userId = "user123"
        
        let memory = SemanticMemory(
            userId: userId,
            category: "Programming",
            content: "Swift is a type-safe language",
            relatedConcepts: ["Type Safety", "Swift"],
            confidence: 0.95,
            sources: ["episode123"]
        )
        
        try await memoryStore.saveSemanticMemory(memory)
        
        let loaded = try await memoryStore.loadSemanticMemories(
            userId: userId,
            category: nil,
            limit: 10
        )
        
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].content, "Swift is a type-safe language")
        XCTAssertEqual(loaded[0].category, "Programming")
        XCTAssertEqual(loaded[0].confidence, 0.95)
    }
    
    func testLoadSemanticMemoriesByCategory() async throws {
        let userId = "user123"
        
        let memory1 = SemanticMemory(
            userId: userId,
            category: "Programming",
            content: "Swift is type-safe"
        )
        
        let memory2 = SemanticMemory(
            userId: userId,
            category: "AI",
            content: "Transformers use attention"
        )
        
        try await memoryStore.saveSemanticMemory(memory1)
        try await memoryStore.saveSemanticMemory(memory2)
        
        // Load only Programming category
        let loaded = try await memoryStore.loadSemanticMemories(
            userId: userId,
            category: "Programming",
            limit: 10
        )
        
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].category, "Programming")
    }
    
    func testSearchSemanticMemory() async throws {
        let userId = "user123"
        
        let memory1 = SemanticMemory(
            userId: userId,
            category: "Programming",
            content: "Swift uses value types like structs",
            confidence: 0.9
        )
        
        let memory2 = SemanticMemory(
            userId: userId,
            category: "Programming",
            content: "Python is dynamically typed",
            confidence: 0.8
        )
        
        try await memoryStore.saveSemanticMemory(memory1)
        try await memoryStore.saveSemanticMemory(memory2)
        
        // Search for "Swift"
        let results = try await memoryStore.searchSemanticMemory(
            userId: userId,
            query: "Swift",
            limit: 10
        )
        
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].content.contains("Swift"))
    }
    
    // MARK: - Working Memory Tests
    
    func testSaveAndLoadWorkingMemory() async throws {
        let threadId = "thread123"
        
        // Create working memory
        var workingMemory = WorkingMemory()
        
        let entity = Entity(
            id: "alice-id",
            type: .person,
            name: "Alice",
            attributes: ["role": "developer"]
        )
        workingMemory.upsertEntity(entity)
        
        let fact = Fact(
            content: "Alice prefers dark mode",
            confidence: 0.9,
            source: "conversation"
        )
        workingMemory.addFact(fact)
        
        workingMemory.setContext(key: "topic", value: "programming")
        workingMemory.recentSummary = "Discussing programming preferences"
        
        try await memoryStore.saveWorkingMemory(workingMemory, threadId: threadId)
        
        let loaded = try await memoryStore.loadWorkingMemory(threadId: threadId)
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.entities.count, 1)
        
        XCTAssertEqual(loaded?.entities["alice-id"]?.name, "Alice")
        XCTAssertEqual(loaded?.entities["alice-id"]?.type, .person)
        XCTAssertEqual(loaded?.entities["alice-id"]?.attributes["role"], "developer")
        
        let aliceEntity = loaded?.entities.values.first { $0.name == "Alice" }
        XCTAssertNotNil(aliceEntity)
        XCTAssertEqual(aliceEntity?.name, "Alice")
        
        XCTAssertEqual(loaded?.facts.count, 1)
        XCTAssertEqual(loaded?.facts[0].content, "Alice prefers dark mode")
        XCTAssertEqual(loaded?.context["topic"], "programming")
        XCTAssertEqual(loaded?.recentSummary, "Discussing programming preferences")
    }
    
    func testUpdateWorkingMemory() async throws {
        let threadId = "thread123"
        
        // Save initial working memory
        var workingMemory = WorkingMemory()
        workingMemory.setContext(key: "topic", value: "Swift")
        
        try await memoryStore.saveWorkingMemory(workingMemory, threadId: threadId)
        
        // Update
        workingMemory.setContext(key: "topic", value: "Python")
        workingMemory.recentSummary = "Changed topic to Python"
        
        try await memoryStore.saveWorkingMemory(workingMemory, threadId: threadId)
        
        // Load and verify
        let loaded = try await memoryStore.loadWorkingMemory(threadId: threadId)
        
        XCTAssertEqual(loaded?.context["topic"], "Python")
        XCTAssertEqual(loaded?.recentSummary, "Changed topic to Python")
    }
    
    func testClearWorkingMemory() async throws {
        let threadId = "thread123"
        
        // Save working memory
        let workingMemory = WorkingMemory()
        try await memoryStore.saveWorkingMemory(workingMemory, threadId: threadId)
        
        // Verify it exists
        var loaded = try await memoryStore.loadWorkingMemory(threadId: threadId)
        XCTAssertNotNil(loaded)
        
        // Clear
        try await memoryStore.clearWorkingMemory(threadId: threadId)
        
        // Verify it's gone
        loaded = try await memoryStore.loadWorkingMemory(threadId: threadId)
        XCTAssertNil(loaded)
    }
    
    func testLoadNonExistentWorkingMemory() async throws {
        let loaded = try await memoryStore.loadWorkingMemory(threadId: "nonexistent")
        XCTAssertNil(loaded)
    }
    
    // MARK: - Multi-User Tests
    
    func testMultipleUserIsolation() async throws {
        // Create profiles for different users
        let user1 = UserProfile(userId: "user1", name: "User One")
        let user2 = UserProfile(userId: "user2", name: "User Two")
        
        try await memoryStore.saveProfile(user1)
        try await memoryStore.saveProfile(user2)
        
        // Create episodes for different users
        let episode1 = Episode(
            userId: "user1",
            threadId: "thread1",
            summary: "User 1 conversation",
            startTime: Date(),
            endTime: Date()
        )
        
        let episode2 = Episode(
            userId: "user2",
            threadId: "thread2",
            summary: "User 2 conversation",
            startTime: Date(),
            endTime: Date()
        )
        
        try await memoryStore.saveEpisode(episode1)
        try await memoryStore.saveEpisode(episode2)
        
        // Verify isolation
        let user1Episodes = try await memoryStore.loadEpisodes(userId: "user1", limit: 10)
        let user2Episodes = try await memoryStore.loadEpisodes(userId: "user2", limit: 10)
        
        XCTAssertEqual(user1Episodes.count, 1)
        XCTAssertEqual(user2Episodes.count, 1)
        XCTAssertEqual(user1Episodes[0].summary, "User 1 conversation")
        XCTAssertEqual(user2Episodes[0].summary, "User 2 conversation")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyResults() async throws {
        let userId = "user123"
        
        let episodes = try await memoryStore.loadEpisodes(userId: userId, limit: 10)
        XCTAssertEqual(episodes.count, 0)
        
        let memories = try await memoryStore.loadSemanticMemories(
            userId: userId,
            category: nil,
            limit: 10
        )
        XCTAssertEqual(memories.count, 0)
    }
    
    func testLargeDataSet() async throws {
        let userId = "user123"
        
        // Create 100 episodes
        for i in 0..<100 {
            let episode = Episode(
                userId: userId,
                threadId: "thread\(i)",
                summary: "Episode \(i)",
                keyPoints: ["Point \(i)"],
                importance: Double(i) / 100.0,
                startTime: Date().addingTimeInterval(TimeInterval(-i * 10)),
                endTime: Date().addingTimeInterval(TimeInterval(-i * 10 + 5))
            )
            try await memoryStore.saveEpisode(episode)
        }
        
        // Load all
        let loaded = try await memoryStore.loadEpisodes(userId: userId, limit: 100)
        XCTAssertEqual(loaded.count, 100)
        
        // Verify sorting (most recent first)
        XCTAssertEqual(loaded[0].summary, "Episode 0")
        XCTAssertEqual(loaded[99].summary, "Episode 99")
    }
}
