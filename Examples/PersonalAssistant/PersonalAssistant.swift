//
//  PersonalAssistant.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 15.02.2026..
//

import SwiftAgent
import Foundation

@main
struct PersonalAssistant {
    static func main() async throws {
        print("Personal Assistant with Google Calendar")
        print(String(repeating: "=", count: 70))
        
        // Setup
        
        let geminiKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] ?? {
            print("\nPlease set GOOGLE_API_KEY: ", terminator: "")
            fflush(stdout)
            return readLine() ?? ""
        }()
        
        let googleToken = ProcessInfo.processInfo.environment["GOOGLE_ACCESS_TOKEN"] ?? {
            print("Please set GOOGLE_ACCESS_TOKEN environment variable")
            print("   Run the OAuth flow first to get your token")
            print("\nQuick setup:")
            print("   1. Go to https://console.cloud.google.com/")
            print("   2. Enable Google Calendar API")
            print("   3. Create OAuth credentials")
            print("   4. Run the OAuth example to get access token")
            print("\nEnter Google Token: ", terminator: "")
            fflush(stdout)
            return readLine() ?? ""
        }()
        
        // Create the personal assistant
        let assistant = PersonalAssistantGraph(
            geminiKey: geminiKey,
            googleToken: googleToken
        )
        
        // Interactive mode
        print("\n Personal Assistant Ready!")
        print(" Try commands like:")
        print("   - 'Schedule a team meeting tomorrow at 2pm'")
        print("   - 'What's on my calendar today?'")
        print("   - 'Find all my meetings about the project launch'")
        print("   - 'Cancel my 3pm meeting tomorrow'")
        print("   - 'Add a lunch meeting with Sarah next Tuesday at noon'")
        print("\nType 'quit' to exit\n")
        
        while true {
            print("You: ", terminator: "")
            fflush(stdout)
            
            guard let input = readLine(), !input.isEmpty else {
                continue
            }
            
            if input.lowercased() == "quit" || input.lowercased() == "exit" {
                print("\n Goodbye! Have a great day!")
                break
            }
            
            print("\nAssistant: ", terminator: "")
            fflush(stdout)
            
            do {
                // Process request through the assistant actor
                try await assistant.processRequest(input)
                print("\n")
                
            } catch {
                print(" Error: \(error.localizedDescription)\n")
            }
        }
    }
}

// MARK: - Personal Assistant Graph

actor PersonalAssistantGraph {
    private let geminiKey: String
    private let googleToken: String
    private let agent: Agent
    
    init(geminiKey: String, googleToken: String) {
        self.geminiKey = geminiKey
        self.googleToken = googleToken
        
//        let provider = OpenAIProvider(apiKey: geminiKey, model: .gpt5Mini)
        let provider = ClaudeProvider(apiKey: geminiKey, model: .sonnet)
        
        // Get current date/time for context
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        let currentDateTime = formatter.string(from: now)
        
        // Create the agent
        self.agent = Agent(
            name: "PersonalAssistant",
            provider: provider,
            systemPrompt: """
            You are a helpful personal assistant with access to Google Calendar.
            
            Current date and time: \(currentDateTime)
            
            Your capabilities:
            - Create calendar events with smart scheduling
            - List and search upcoming events
            - Update existing events
            - Delete events when requested
            - Understand natural language time references (tomorrow, next week, etc.)
            - Add Google Meet links to meetings when appropriate
            - Manage attendees and meeting details
            
            Guidelines:
            - Always confirm important actions before executing (deletes, major changes)
            - Use ISO 8601 format for dates: YYYY-MM-DDTHH:MM:SSZ
            - Default to 1-hour meetings unless specified
            - Add Meet links for remote meetings
            - Be proactive and helpful
            - Ask clarifying questions when needed
            
            When creating events:
            1. Parse the natural language request
            2. Use the date_time tool to calculate exact times if needed
            3. Create the event with google_calendar tool
            4. Confirm with the user
            
            Be conversational and friendly!
            Always use tools before answering.
            """,
            tools: [DateTimeTool(), GoogleCalendarTool(accessToken: googleToken)],
            maxIterations: 15
        )
    }
    
    /// Process a user request with streaming output
    func processRequest(_ input: String) async throws {
        // Use streaming for real-time output
        let stream = await agent.stream(task: input)
        
        var fullResponse = ""
        
        for try await event in stream {
            switch event {
            case .thinking(let text):
                print(text, terminator: "")
                fflush(stdout)
                fullResponse += text
                
            case .toolCall(let call):
                // Show tool usage
                print("\n    [Using \(call.name)...]", terminator: "")
                fflush(stdout)
                
            case .toolResult(_, _):
                // Tool completed
                break
                
            case .completed(let result):
                if fullResponse.isEmpty {
                    print(result.output)
                }
                
            case .error(let error):
                print("\nError: \(error.localizedDescription)")
            case .response(let text):
                print(text, terminator: "")
                fflush(stdout)
            }
        }
    }
    
    /// Run without streaming (returns result directly)
    func execute(task: String) async throws -> AssistantResponse {
        let result = try await agent.run(task: task)
        
        return AssistantResponse(
            output: result.output,
            success: result.success,
            totalTokens: result.totalTokens,
            iterations: result.state.iterations
        )
    }
}

// MARK: - Assistant Response

struct AssistantResponse {
    let output: String
    let success: Bool
    let totalTokens: Int
    let iterations: Int
}
