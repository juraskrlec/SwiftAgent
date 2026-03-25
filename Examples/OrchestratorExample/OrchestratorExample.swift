//
//  OrchestratorExample.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 25.03.2026..
//

import SwiftAgent
import Foundation

@main
struct OrchestratorExample {
    static func main() async throws {
        print("Orchestrator Agent Example")
        print(String(repeating: "=", count: 40))

        // Setup - uses Claude, but swap for any provider
        let apiKey = ProcessInfo.processInfo.environment["OPENA_AI_API_KEY"] ?? {
            print("\nPlease set OPENA_AI_API_KEY: ", terminator: "")
            fflush(stdout)
            return readLine() ?? ""
        }()

        let provider = OpenAIProvider(apiKey: apiKey, model: .gpt52)

        // Create specialized worker agents
        let researcher = Agent(
            name: "Researcher",
            provider: provider,
            systemPrompt: """
            You are a web researcher. Search for information about the given topic using your tools.
            Provide detailed findings with key facts and data points.
            """,
            tools: [WebSearchTool()],
            maxIterations: 5
        )

        let analyst = Agent(
            name: "Analyst",
            provider: provider,
            systemPrompt: """
            You are a data analyst. Analyze the provided information and extract:
            - Key trends and patterns
            - Important statistics
            - Notable comparisons
            Provide clear, structured analysis.
            """,
            tools: [CalculatorTool()],
            maxIterations: 3
        )

        let writer = Agent(
            name: "Writer",
            provider: provider,
            systemPrompt: """
            You are a technical writer. Create clear, well-structured reports.
            Include an executive summary, main findings, and conclusions.
            Write professionally but accessibly.
            """,
            maxIterations: 3
        )

        // Create orchestrator with shared workspace
        let (orchestrator, workspace) = Agent.orchestrator(
            provider: provider,
            workers: [researcher, analyst, writer],
            maxIterations: 5
        )

        // Run a complex multi-agent task
        print("\nStarting orchestration...\n")

        let result = try await orchestrator.run(
            task: """
            Research the current state of on-device AI on Apple platforms,
            analyze the key capabilities and limitations,
            and write a concise report with recommendations.
            """
        )

        print("\n" + String(repeating: "=", count: 40))
        print("FINAL RESULT:")
        print(String(repeating: "=", count: 40))
        print(result.output)

        // Inspect workspace
        print("\n" + String(repeating: "-", count: 40))
        print("WORKSPACE LOG:")
        print(String(repeating: "-", count: 40))

        let log = await workspace.contributionLog()
        for contribution in log {
            let preview = contribution.value.prefix(100)
            print("  [\(contribution.agentName)] \(contribution.key): \(preview)...")
        }

        print("\nTotal tokens used: \(result.totalTokens)")
        print("Success: \(result.success)")
    }
}
