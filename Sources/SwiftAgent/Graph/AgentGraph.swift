//
//  AgentGraph.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// A graph-based workflow for coordinating multiple agents
public actor AgentGraph {
    private var nodes: [String: GraphNode] = [:]
    private var edges: [GraphEdge] = []
    private var conditionalEdges: [ConditionalEdge] = []
    private let maxIterations: Int
    
    public init(maxIterations: Int = 50) {
        self.maxIterations = maxIterations
    }
    
    // MARK: - Building the Graph
    
    /// Add a node with an agent
    @discardableResult
    public func addNode(_ name: String, agent: Agent) -> Self {
        nodes[name] = .agent(agent)
        return self
    }
    
    /// Add a node with a custom function
    @discardableResult
    public func addNode(_ name: String, function: @escaping @Sendable (GraphState) async throws -> GraphState) -> Self {
        nodes[name] = .function(function)
        return self
    }
    
    /// Add a simple edge from one node to another
    @discardableResult
    public func addEdge(from: String, to: String) -> Self {
        edges.append(GraphEdge(from: from, to: to))
        return self
    }
    
    /// Add an edge from START to a node
    @discardableResult
    public func addEdge(from: SpecialNode, to: String) -> Self {
        edges.append(GraphEdge(from: from.rawValue, to: to))
        return self
    }
    
    /// Add an edge from a node to END
    @discardableResult
    public func addEdge(from: String, to: SpecialNode) -> Self {
        edges.append(GraphEdge(from: from, to: to.rawValue))
        return self
    }
    
    /// Add a conditional edge
    @discardableResult
    public func addConditionalEdge(
        from: String,
        condition: @escaping @Sendable (GraphState) -> String
    ) -> Self {
        conditionalEdges.append(ConditionalEdge(from: from, router: condition))
        return self
    }
    
    /// Add parallel edges (from START to multiple nodes)
    @discardableResult
    public func addParallelEdges(from: SpecialNode, to nodes: [String]) -> Self {
        for node in nodes {
            edges.append(GraphEdge(from: from.rawValue, to: node))
        }
        return self
    }
    
    /// Add edges from multiple nodes to a single node (convergence)
    @discardableResult
    public func addEdge(from nodes: [String], to: String) -> Self {
        for node in nodes {
            edges.append(GraphEdge(from: node, to: to))
        }
        return self
    }
    
    // MARK: - Execution
    
    /// Execute the graph with an initial state
    public func invoke(input: GraphState) async throws -> GraphState {
        var state = input
        var currentNodes = findNextNodes(from: SpecialNode.START.rawValue, state: state)
        var iterations = 0
        
        while !currentNodes.isEmpty && iterations < maxIterations {
            guard !currentNodes.contains(SpecialNode.END.rawValue) else {
                break
            }
            
            // Execute all current nodes (parallel execution)
            var nextStates: [GraphState] = []
            
            for nodeName in currentNodes {
                guard let node = nodes[nodeName] else {
                    throw GraphError.nodeNotFound(nodeName)
                }
                
                state.markNodeVisited(nodeName)
                let nodeState = try await node.execute(state: state)
                nextStates.append(nodeState)
            }
            
            // Merge states (last one wins for conflicts, messages are accumulated)
            state = mergeStates(nextStates)
            
            // Find next nodes
            var allNextNodes: Set<String> = []
            for nodeName in currentNodes {
                let next = findNextNodes(from: nodeName, state: state)
                allNextNodes.formUnion(next)
            }
            
            currentNodes = Array(allNextNodes)
            iterations += 1
        }
        
        if iterations >= maxIterations {
            throw GraphError.maxIterationsReached(maxIterations)
        }
        
        return state
    }
    
    /// Stream graph execution with events
    public func stream(input: GraphState) -> AsyncThrowingStream<GraphEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var state = input
                    var currentNodes = findNextNodes(from: SpecialNode.START.rawValue, state: state)
                    var iterations = 0
                    
                    while !currentNodes.isEmpty && iterations < maxIterations {
                        guard !currentNodes.contains(SpecialNode.END.rawValue) else {
                            break
                        }
                        
                        // Execute all current nodes
                        var nextStates: [GraphState] = []
                        
                        for nodeName in currentNodes {
                            guard let node = nodes[nodeName] else {
                                throw GraphError.nodeNotFound(nodeName)
                            }
                            
                            continuation.yield(.nodeStarted(nodeName))
                            state.markNodeVisited(nodeName)
                            
                            let nodeState = try await node.execute(state: state)
                            nextStates.append(nodeState)
                            
                            continuation.yield(.nodeCompleted(nodeName, nodeState))
                        }
                        
                        // Merge states
                        state = mergeStates(nextStates)
                        
                        // Find next nodes
                        var allNextNodes: Set<String> = []
                        for nodeName in currentNodes {
                            let next = findNextNodes(from: nodeName, state: state)
                            for nextNode in next {
                                continuation.yield(.edgeTraversed(from: nodeName, to: nextNode))
                            }
                            allNextNodes.formUnion(next)
                        }
                        
                        currentNodes = Array(allNextNodes)
                        iterations += 1
                    }
                    
                    if iterations >= maxIterations {
                        throw GraphError.maxIterationsReached(maxIterations)
                    }
                    
                    continuation.yield(.graphCompleted(state))
                    continuation.finish()
                    
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func findNextNodes(from nodeName: String, state: GraphState) -> [String] {
        var nextNodes: [String] = []
        
        // Check conditional edges first
        for conditionalEdge in conditionalEdges where conditionalEdge.from == nodeName {
            let nextNode = conditionalEdge.getNextNode(state: state)
            nextNodes.append(nextNode)
        }
        
        // If no conditional edges, check regular edges
        if nextNodes.isEmpty {
            for edge in edges where edge.from == nodeName {
                if edge.shouldTraverse(state: state) {
                    nextNodes.append(edge.to)
                }
            }
        }
        
        return nextNodes
    }
    
    private func mergeStates(_ states: [GraphState]) -> GraphState {
        guard !states.isEmpty else { return GraphState() }
        
        var merged = states[0]
        
        for state in states.dropFirst() {
            // Accumulate messages
            for message in state.messages {
                if !merged.messages.contains(where: { $0.id == message.id }) {
                    merged.messages.append(message)
                }
            }
            
            // Merge data (later states override)
            for (key, value) in state.data {
                merged.data[key] = value
            }
            
            // Accumulate visited nodes
            for node in state.visitedNodes {
                if !merged.visitedNodes.contains(node) {
                    merged.visitedNodes.append(node)
                }
            }
        }
        
        return merged
    }
}

/// Errors specific to graph execution
public enum GraphError: Error, LocalizedError {
    case nodeNotFound(String)
    case maxIterationsReached(Int)
    case invalidGraph(String)
    
    public var errorDescription: String? {
        switch self {
        case .nodeNotFound(let name):
            return "Node not found: \(name)"
        case .maxIterationsReached(let max):
            return "Graph exceeded maximum iterations: \(max)"
        case .invalidGraph(let reason):
            return "Invalid graph: \(reason)"
        }
    }
}
