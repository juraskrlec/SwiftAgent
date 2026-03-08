//
//  main.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import SwiftAgent
import Foundation

@main
struct ContinuousLearner {
    
    static func main() async throws {
        print("Continuous Learning Agent")
        print("This agent learns from conversations and improves over time")
        
        let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? {
            print("\nPlease set OPENAI_API_KEY: ", terminator: "")
            fflush(stdout)
            return readLine() ?? ""
        }()
        
        // Setup RAG
        let embeddingProvider = OpenAIEmbeddingProvider(apiKey: openAIKey)
        let vectorStore = InMemoryVectorStore(embeddingProvider: embeddingProvider)
        
        // Create learning agent
        let learner = LearningAgent(
            key: openAIKey,
            vectorStore: vectorStore
        )
        
        // Simulate a learning loop
        let interactions = [
            "What is Swift?",
            "Tell me about Swift concurrency",
            "How does async/await work in Swift?",
            "Compare Swift to Python",
            "What are actors in Swift?",
        ]
        
        print("\nStarting learning loop...\n")
        
        for (index, question) in interactions.enumerated() {
            print("Interaction \(index + 1):")
            print("Q: \(question)")
            
            let response = try await learner.interact(question: question)
            
            print("A: \(response.answer)")
            print("Knowledge base size: \(response.knowledgeCount) documents")
            print("Used memory: \(response.usedMemory)")
            print("")
            
            // Simulate delay
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        print("\nLearning complete!")
        print("Final knowledge base: \(try await vectorStore.count()) documents")
    }
}

// MARK: - Learning Agent

actor LearningAgent {
    private let key: String
    private let vectorStore: VectorStore
    private let graph: AgentGraph
    
    private let conversationAgent: Agent
    private let summarizerAgent: Agent
    private let memoryAgent: Agent
    
    init(key: String, vectorStore: VectorStore) {
        self.key = key
        self.vectorStore = vectorStore
        
        let provider = OpenAIProvider(apiKey: key, model: .defaultChatGPTModel)
        
        // Agent that has conversations
        self.conversationAgent = Agent(
            name: "Conversationalist",
            provider: provider,
            systemPrompt: """
            You are a helpful assistant. Answer questions clearly and concisely.
            If you have relevant information from past conversations (via search_knowledge_base), 
            use it to give better answers.
            """,
            tools: [VectorSearchTool(vectorStore: vectorStore)],
            maxIterations: 5
        )
        
        // Agent that summarizes interactions
        self.summarizerAgent = Agent(
            name: "Summarizer",
            provider: provider,
            systemPrompt: """
            Summarize the key information from this conversation exchange.
            Extract facts, insights, and learnings that should be remembered.
            Be concise but comprehensive.
            """,
            tools: [],
            maxIterations: 2
        )
        
        // Agent that decides what to remember
        self.memoryAgent = Agent(
            name: "MemoryManager",
            provider: provider,
            systemPrompt: """
            Decide if this information is worth storing in long-term memory.
            Consider: Is it factual? Is it useful? Is it unique?
            Respond with STORE or SKIP, followed by a brief reason.
            """,
            tools: [],
            maxIterations: 2
        )
        
        self.graph = AgentGraph()
    }
    
    func interact(question: String) async throws -> InteractionResult {
        // Build a simple learning graph
        await setupLearningGraph()
        
        var state = GraphState()
        state.addMessage(.user(question))
        state.setValue(.string(question), forKey: "original_question")
        
        let result = try await graph.invoke(input: state)
        
        let answer = result.messages.first(where: {
            $0.role == .assistant && !$0.content.isEmpty
        })?.textContent ?? "No answer"
        
        let usedMemory = result.messages.contains(where: {
            $0.role == .tool
        })
        
        let knowledgeCount = try await vectorStore.count()
        
        return InteractionResult(
            answer: answer,
            usedMemory: usedMemory,
            knowledgeCount: knowledgeCount
        )
    }
    
    private func setupLearningGraph() async {
        // Node 1: Answer the question
        await graph.addNode("answer", agent: conversationAgent)
        
        // Node 2: Summarize the exchange
        await graph.addNode("summarize") { state in
            var newState = state
            
            let question = state.getValue(forKey: "original_question")?.stringValue ?? ""
            let answer = state.messages.first(where: { $0.role == .assistant })?.textContent ?? ""
            
            let result = try await self.summarizerAgent.run(task: """
            Summarize this exchange:
            Q: \(question)
            A: \(answer)
            """)
            
            newState.setValue(.string(result.output), forKey: "summary")
            
            return newState
        }
        
        // Node 3: Decide if worth storing
        await graph.addNode("decide_storage") { state in
            var newState = state
            
            let summary = state.getValue(forKey: "summary")?.stringValue ?? ""
            
            let decision = try await self.memoryAgent.run(task: """
            Should we store this in memory?
            \(summary)
            """)
            
            newState.setValue(.string(decision.output), forKey: "storage_decision")
            
            return newState
        }
        
        // Node 4: Store in RAG (conditional)
        await graph.addNode("store") { state in
            let summary = state.getValue(forKey: "summary")?.stringValue ?? ""
            let decision = state.getValue(forKey: "storage_decision")?.stringValue ?? ""
            
            if decision.uppercased().contains("STORE") {
                let doc = Document(
                    id: UUID().uuidString,
                    content: summary,
                    metadata: [
                        "timestamp": ISO8601DateFormatter().string(from: Date()),
                        "type": "learned_knowledge"
                    ]
                )
                
                try await self.vectorStore.add(documents: [doc])
                print("Stored new knowledge")
            } else {
                print("Skipped storage")
            }
            
            return state
        }
        
        // Setup edges
        await graph.addEdge(from: .START, to: "answer")
        await graph.addEdge(from: "answer", to: "summarize")
        await graph.addEdge(from: "summarize", to: "decide_storage")
        await graph.addEdge(from: "decide_storage", to: "store")
        await graph.addEdge(from: "store", to: .END)
    }
}

struct InteractionResult {
    let answer: String
    let usedMemory: Bool
    let knowledgeCount: Int
}
