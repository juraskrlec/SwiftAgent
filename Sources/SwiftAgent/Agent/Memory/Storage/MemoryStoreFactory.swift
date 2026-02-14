//
//  MemoryStoreFactory.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 14.02.2026..
//

import Foundation
import SwiftData

public struct MemoryStoreFactory {
    
    /// Create SwiftData memory store
    public static func createSwiftDataStore(
        inMemory: Bool = false
    ) throws -> SwiftDataMemoryStore {
        let schema = Schema([
            UserProfileModel.self,
            EpisodeModel.self,
            SemanticMemoryModel.self,
            WorkingMemoryModel.self
        ])
        
        let configuration: ModelConfiguration
        
        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
        }
        
        let container = try ModelContainer(
            for: schema,
            configurations: configuration
        )
        
        return SwiftDataMemoryStore(modelContainer: container)
    }
    
    /// Create in-memory store (for testing)
    public static func createInMemoryStore() -> InMemoryMemoryStore {
        return InMemoryMemoryStore()
    }
}
