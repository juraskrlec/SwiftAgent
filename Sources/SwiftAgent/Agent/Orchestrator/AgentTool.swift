//
//  AgentTool.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 25.03.2026..
//

import Foundation

/// A tool that wraps an Agent, allowing an orchestrator agent to delegate tasks
/// to specialized worker agents via the standard tool-calling mechanism.
///
/// When the orchestrator LLM calls this tool, it:
/// 1. Reads current workspace context
/// 2. Prepends workspace summary to the task
/// 3. Runs the worker agent with the enriched task
/// 4. Writes the worker's output to the workspace
/// 5. Returns the worker's output as the tool result
///
/// ```swift
/// let tool = AgentTool(agent: researchAgent, workspace: workspace)
/// // The orchestrator LLM can now call this tool with a task
/// ```
public struct AgentTool: Tool, Sendable {
    public let name: String
    public let description: String

    public var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "task": ParameterProperty(
                    type: "string",
                    description: "The task to delegate to the \(agentDisplayName) agent. Be specific about what you need."
                ),
                "context": ParameterProperty(
                    type: "string",
                    description: "Optional additional context relevant to the task"
                )
            ],
            required: ["task"]
        )
    }

    private let agent: Agent
    private let workspace: Workspace?
    private let agentDisplayName: String

    /// Create an AgentTool wrapping a worker agent.
    ///
    /// - Parameters:
    ///   - agent: The worker agent to invoke.
    ///   - toolName: The tool name the orchestrator will use to call this agent.
    ///     Defaults to the agent's name in snake_case with "_agent" suffix.
    ///   - toolDescription: Description of what this agent does, shown to the orchestrator LLM.
    ///   - workspace: Optional shared workspace. If provided, workspace context is injected
    ///     into the worker's task and the worker's output is written back to the workspace.
    public init(
        agent: Agent,
        toolName: String? = nil,
        toolDescription: String? = nil,
        workspace: Workspace? = nil
    ) {
        self.agent = agent
        self.workspace = workspace
        self.agentDisplayName = agent.name

        self.name = toolName ?? Self.snakeCase(agent.name) + "_agent"

        self.description = toolDescription
            ?? "Delegate a task to the \(agent.name) agent. Provide a clear task description."
    }

    public func execute(arguments: [String: Any]) async throws -> String {
        guard let task = arguments["task"] as? String else {
            throw ToolError.invalidArguments("Missing 'task' parameter")
        }

        let additionalContext = arguments["context"] as? String

        // Build the enriched task with workspace context
        var enrichedTask = task

        if let workspace = workspace {
            let workspaceSummary = await workspace.summary()
            if !workspaceSummary.isEmpty {
                enrichedTask = """
                \(task)\
                \(additionalContext.map { "\n\nAdditional context: \($0)" } ?? "")

                The following is shared context from other agents working on this project:

                \(workspaceSummary)
                """
            } else if let ctx = additionalContext {
                enrichedTask = "\(task)\n\nAdditional context: \(ctx)"
            }
        } else if let ctx = additionalContext {
            enrichedTask = "\(task)\n\nAdditional context: \(ctx)"
        }

        // Run the worker agent
        let result = try await agent.run(task: enrichedTask)

        // Write result to workspace
        if let workspace = workspace {
            await workspace.writeResult(agentName: agentDisplayName, result: result.output)
        }

        return result.output
    }

    // MARK: - Private

    /// Convert "PascalCase" or "camelCase" to "snake_case"
    private static func snakeCase(_ input: String) -> String {
        var result = ""
        for (index, character) in input.enumerated() {
            if character.isUppercase && index > 0 {
                result += "_"
            }
            result += character.lowercased()
        }
        return result
    }
}
