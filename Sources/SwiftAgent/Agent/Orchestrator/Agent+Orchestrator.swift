//
//  Agent+Orchestrator.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 25.03.2026..
//

import Foundation

extension Agent {

    /// Create an orchestrator agent that delegates work to specialized worker agents.
    ///
    /// The orchestrator uses the existing Agent tool loop: the LLM decides which worker
    /// agents to call and in what order, using ``AgentTool`` instances as its tools.
    ///
    /// ```swift
    /// let (orchestrator, workspace) = await Agent.orchestrator(
    ///     provider: provider,
    ///     workers: [researcher, analyst, writer]
    /// )
    /// let result = try await orchestrator.run(task: "Research and write a report on Swift concurrency")
    /// ```
    ///
    /// - Parameters:
    ///   - name: Name for the orchestrator agent. Defaults to "Orchestrator".
    ///   - provider: The LLM provider for the orchestrator.
    ///   - systemPrompt: Custom system prompt. If nil, a default orchestrator prompt is generated.
    ///   - workers: The worker agents to make available.
    ///   - workspace: Optional shared workspace. If nil, one is created automatically.
    ///   - additionalTools: Extra tools the orchestrator can use directly (not agent-based).
    ///   - maxIterations: Maximum orchestration loop iterations. Defaults to 15.
    ///   - options: LLM generation options.
    /// - Returns: A tuple of (orchestrator Agent, Workspace).
    public static func orchestrator(
        name: String = "Orchestrator",
        provider: LLMProvider,
        systemPrompt: String? = nil,
        workers: [Agent],
        workspace: Workspace? = nil,
        additionalTools: [Tool] = [],
        maxIterations: Int = 15,
        options: GenerationOptions = .default
    ) -> (agent: Agent, workspace: Workspace) {
        let ws = workspace ?? Workspace()

        // Build AgentTool for each worker
        var tools: [Tool] = []
        var workerDescriptions: [String] = []

        for worker in workers {
            let tool = AgentTool(agent: worker, workspace: ws)
            tools.append(tool)
            workerDescriptions.append("- \(tool.name): \(tool.description)")
        }

        // Add any additional non-agent tools
        tools.append(contentsOf: additionalTools)

        // Generate default system prompt if none provided
        let prompt = systemPrompt ?? """
        You are an orchestrator agent that coordinates specialized worker agents to accomplish tasks.

        Available worker agents:
        \(workerDescriptions.joined(separator: "\n"))

        Instructions:
        - Break down the user's request into subtasks
        - Delegate each subtask to the most appropriate worker agent
        - Provide clear, specific task descriptions when calling agents
        - Synthesize the results from worker agents into a final answer
        - You may call the same agent multiple times if needed
        - You may call multiple agents to accomplish complex tasks
        """

        let orchestrator = Agent(
            name: name,
            provider: provider,
            systemPrompt: prompt,
            tools: tools,
            maxIterations: maxIterations,
            options: options
        )

        return (orchestrator, ws)
    }
}
