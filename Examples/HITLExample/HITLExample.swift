//
//  HITLExample.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 13.02.2026..
//

import Foundation
import SwiftAgent

@main
struct HITLExample {
    static func main() async throws {
        print("Interruptible Agent Demo")
        print(String(repeating: "=", count: 60))
        
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            print("Please set OPENAI_API_KEY environment variable")
            print("   export OPENAI_API_KEY='your-key'")
            return
        }
        
        // Create provider
        let provider = OpenAIProvider(apiKey: apiKey, model: .gpt51Mini)
        
        // Create file system tool with temp directory access
        let fileSystemTool = FileSystemTool(
            allowedPaths: ["/tmp", NSTemporaryDirectory()]
        )
        
        // Create interruptible agent
        let agent = InterruptibleAgent(
            name: "ResearchAssistant",
            provider: provider,
            systemPrompt: """
            You are a research assistant. You can:
            - Search the web for information
            - Work with dates and times
            - Read and write files to save research
            
            When researching, save your findings to files for later reference.
            """,
            tools: [
                WebSearchTool(),
                DateTimeTool(),
                fileSystemTool
            ],
            maxIterations: 15,
            interruptBefore: ["web_search"],  // Ask before searching
            interruptAfter: ["file_system"]   // Review after file operations
        )
        
        let threadId = "research-\(UUID().uuidString)"
        
        // Example 1: Research with interrupts
        print("\nTask: Research Swift 6 features and save to a file")
        print("Thread ID: \(threadId)\n")
        
        var result = try await agent.invoke(
            task: "Research the latest Swift 6 features and save the findings to /tmp/swift6_research.txt",
            threadId: threadId
        )
        
        // Handle interrupts in a loop
        while !result.success {
            if let interrupt = await agent.getPendingInterrupt(threadId: threadId) {
                displayInterrupt(interrupt)
                
                let response = await getHumanResponse(for: interrupt)
                
                print("\nContinuing execution...\n")
                
                // Update state and continue
                result = try await agent.updateState(response, threadId: threadId)
            } else {
                print("No pending interrupt but execution not complete")
                break
            }
        }
        
        // Display final result
        displayFinalResult(result, threadId: threadId, agent: agent)
    }
    
    static func displayInterrupt(_ interrupt: InterruptRequest) {
        print("\n" + String(repeating: "=", count: 60))
        print("INTERRUPT: \(interrupt.type.rawValue.uppercased())")
        print(String(repeating: "=", count: 60))
        print("\n\(interrupt.message)\n")
        
        if let options = interrupt.options {
            print("Options:")
            for (index, option) in options.enumerated() {
                print("  [\(index + 1)] \(option.label)")
                if let description = option.description {
                    print("      → \(description)")
                }
            }
        }
    }
    
    static func getHumanResponse(for interrupt: InterruptRequest) async -> InterruptResponse {
        print("\nYour choice (1-\(interrupt.options?.count ?? 0)): ", terminator: "")
        fflush(stdout)
        
        guard let input = readLine(),
              let choice = Int(input),
              choice > 0,
              let options = interrupt.options,
              choice <= options.count else {
            print("Invalid choice, defaulting to reject")
            return InterruptResponse(
                requestId: interrupt.id,
                action: .reject,
                feedback: "Invalid choice"
            )
        }
        
        let selectedOption = options[choice - 1]
        let action = InterruptAction(rawValue: selectedOption.value) ?? .approve
        
        var feedback: String?
        var value: String?
        
        // Handle specific actions
        switch action {
        case .modify:
            print("Enter alternative action: ", terminator: "")
            fflush(stdout)
            value = readLine()
            
        case .reject:
            print("Rejection reason (optional): ", terminator: "")
            fflush(stdout)
            feedback = readLine()
            
        default:
            break
        }
        
        return InterruptResponse(
            requestId: interrupt.id,
            action: action,
            value: value,
            feedback: feedback
        )
    }
    
    static func displayFinalResult(_ result: AgentResult, threadId: String, agent: InterruptibleAgent) {
        print("\n" + String(repeating: "=", count: 60))
        print("FINAL RESULT")
        print(String(repeating: "=", count: 60))
        print("\n\(result.output)\n")
        print("Stats:")
        print("   Success: \(result.success)")
        print("   Total tokens: \(result.totalTokens)")
        print("   Iterations: \(result.state.iterations)")
        
        // Show checkpoints
        Task {
            let checkpoints = try await agent.getCheckpoints(threadId: threadId)
            print("\nCheckpoints created: \(checkpoints.count)")
            for (index, checkpoint) in checkpoints.enumerated() {
                let time = DateFormatter.localizedString(from: checkpoint.timestamp, dateStyle: .none, timeStyle: .medium)
                print("   \(index + 1). \(time)")
                if let pending = checkpoint.pendingAction {
                    print("      Pending: \(pending.toolCall.name)")
                }
            }
        }
    }
}
