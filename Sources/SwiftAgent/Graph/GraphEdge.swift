//
//  GraphEdge.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// An edge connecting nodes in the graph
public struct GraphEdge: Sendable {
    public let from: String
    public let to: String
    public let condition: (@Sendable (GraphState) -> Bool)?
    
    public init(from: String, to: String, condition: (@Sendable (GraphState) -> Bool)? = nil) {
        self.from = from
        self.to = to
        self.condition = condition
    }
    
    public func shouldTraverse(state: GraphState) -> Bool {
        guard let condition = condition else { return true }
        return condition(state)
    }
}

/// Conditional edge that routes to different nodes based on state
public struct ConditionalEdge: Sendable {
    public let from: String
    public let router: @Sendable (GraphState) -> String
    
    public init(from: String, router: @escaping @Sendable (GraphState) -> String) {
        self.from = from
        self.router = router
    }
    
    public func getNextNode(state: GraphState) -> String {
        return router(state)
    }
}
