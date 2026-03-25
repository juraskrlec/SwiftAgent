//
//  Workspace.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 25.03.2026..
//

import Foundation

/// A thread-safe shared workspace for orchestrator-worker agent patterns.
///
/// Agents contribute results under namespaced sections, and all contributions
/// are logged with timestamps for auditability.
///
/// ```swift
/// let workspace = Workspace()
/// await workspace.write(namespace: "researcher", key: "findings", value: "...")
/// let summary = await workspace.summary()
/// ```
public actor Workspace {
    
    /// A single entry contributed by an agent to the workspace.
    public struct Contribution: Sendable {
        public let agentName: String
        public let key: String
        public let value: String
        public let timestamp: Date
        
        public init(agentName: String, key: String, value: String, timestamp: Date = Date()) {
            self.agentName = agentName
            self.key = key
            self.value = value
            self.timestamp = timestamp
        }
    }
    
    /// Namespaced data: [namespace: [key: value]]
    private var sections: [String: [String: String]] = [:]
    
    /// Ordered log of all contributions
    private var contributions: [Contribution] = []
    
    public init() {}
    
    /// Initialize with pre-populated data.
    public init(initialData: [String: [String: String]]) {
        self.sections = initialData
    }
    
    // MARK: - Write
    
    /// Write a value under a namespace (typically the agent's name).
    public func write(namespace: String, key: String, value: String) {
        if sections[namespace] == nil {
            sections[namespace] = [:]
        }
        sections[namespace]?[key] = value
        contributions.append(Contribution(
            agentName: namespace,
            key: key,
            value: value
        ))
    }
    
    /// Convenience: write the agent's output result under its namespace with key "result".
    public func writeResult(agentName: String, result: String) {
        write(namespace: agentName, key: "result", value: result)
    }
    
    // MARK: - Read
    
    /// Read a specific value.
    public func read(namespace: String, key: String) -> String? {
        sections[namespace]?[key]
    }
    
    /// Read all data under a namespace.
    public func readNamespace(_ namespace: String) -> [String: String] {
        sections[namespace] ?? [:]
    }
    
    /// Read all sections.
    public func readAll() -> [String: [String: String]] {
        sections
    }
    
    /// Get the full contribution log.
    public func contributionLog() -> [Contribution] {
        contributions
    }
    
    // MARK: - Summary
    
    /// Generate a text summary of all workspace contents, suitable for injection into prompts.
    public func summary() -> String {
        guard !sections.isEmpty else {
            return ""
        }
        
        var lines: [String] = ["=== Workspace Contents ==="]
        
        for (namespace, data) in sections.sorted(by: { $0.key < $1.key }) {
            lines.append("")
            lines.append("[\(namespace)]")
            for (key, value) in data.sorted(by: { $0.key < $1.key }) {
                let truncated = value.count > 2000
                    ? String(value.prefix(2000)) + "... (truncated)"
                    : value
                lines.append("  \(key): \(truncated)")
            }
        }
        
        lines.append("")
        lines.append("=== End Workspace ===")
        return lines.joined(separator: "\n")
    }
    
    /// Clear all workspace data.
    public func clear() {
        sections.removeAll()
        contributions.removeAll()
    }
}
