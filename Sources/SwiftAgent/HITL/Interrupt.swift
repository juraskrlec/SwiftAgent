//
//  Interrupt.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 13.02.2026..
//

import Foundation

/// Types of interrupts
public enum InterruptType: String, Codable, Sendable {
    case approval      // Requires human approval
    case input         // Requires human input
    case decision      // Requires human decision between options
    case review        // Requires human review/feedback
    case error         // Error occurred, needs human intervention
}

/// Interrupt request
public struct InterruptRequest: Codable, Sendable, Identifiable {
    public let id: String
    public let type: InterruptType
    public let checkpointId: String
    public let message: String
    public let options: [InterruptOption]?
    public let defaultOption: String?
    public let metadata: [String: String]
    public let timestamp: Date
    
    public init(
        id: String = UUID().uuidString,
        type: InterruptType,
        checkpointId: String,
        message: String,
        options: [InterruptOption]? = nil,
        defaultOption: String? = nil,
        metadata: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.checkpointId = checkpointId
        self.message = message
        self.options = options
        self.defaultOption = defaultOption
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

/// Option for interrupt decision
public struct InterruptOption: Codable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let description: String?
    public let value: String
    
    public init(
        id: String,
        label: String,
        description: String? = nil,
        value: String
    ) {
        self.id = id
        self.label = label
        self.description = description
        self.value = value
    }
}

/// Response to interrupt
public struct InterruptResponse: Codable, Sendable {
    public let requestId: String
    public let action: InterruptAction
    public let value: String?
    public let feedback: String?
    public let timestamp: Date
    
    public init(
        requestId: String,
        action: InterruptAction,
        value: String? = nil,
        feedback: String? = nil,
        timestamp: Date = Date()
    ) {
        self.requestId = requestId
        self.action = action
        self.value = value
        self.feedback = feedback
        self.timestamp = timestamp
    }
}

/// Actions for interrupt response
public enum InterruptAction: String, Codable, Sendable {
    case approve     // Approve and continue
    case reject      // Reject and stop
    case modify      // Modify and continue
    case retry       // Retry the action
    case skip        // Skip this action
    case rollback    // Rollback to previous checkpoint
}
