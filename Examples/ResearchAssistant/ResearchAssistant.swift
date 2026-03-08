//
//  ResearchAssistant.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import SwiftAgent
import Foundation

@main
struct ResearchAssistant {
    static func main() async throws {
        print("Research Assistant with Multi-Agent Graph")
        
        // Setup
        let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? {
            print("\nPlease set OPENAI_API_KEY: ", terminator: "")
            fflush(stdout)
            return readLine() ?? ""
        }()
        
        // Create RAG system for storing research
        let embeddingProvider = OpenAIEmbeddingProvider(apiKey: openAIKey)
        let vectorStore = InMemoryVectorStore(embeddingProvider: embeddingProvider)
        
        // Create the research assistant
        let assistant = ResearchGraph(
            key: openAIKey,
            vectorStore: vectorStore
        )
        
        // Research topics
        let topics = [
            "What are the latest developments in Swift 6 concurrency?",
            "How does Apple Intelligence compare to other on-device AI solutions?",
        ]
        
        for topic in topics {
            print("\nResearching: \(topic)")
            
            let report = try await assistant.research(topic: topic)
            
            print("\nResearch Report:")
            print(report.content)
            print("\nStats:")
            print("   - Subtopics researched: \(report.subtopicsCount)")
            print("   - Sources used: \(report.sourcesCount)")
            print("   - Iterations: \(report.iterations)")
            print("   - Saved to RAG: \(report.savedToRAG)")
        }
        
        // Now we can query the RAG system
        print("\n\nQuery the knowledge base:")
        
        let ragAgent = Agent(
            name: "QueryAgent",
            provider: OpenAIProvider(apiKey: openAIKey, model: .defaultChatGPTModel),
            systemPrompt: "Answer questions based on the knowledge base. Always cite sources.",
            tools: [VectorSearchTool(vectorStore: vectorStore)],
            maxIterations: 3
        )
        
        let queries = [
            "What did we learn about Swift 6?",
            "Compare Apple Intelligence features",
        ]
        
        for query in queries {
            print("\nQ: \(query)")
            let result = try await ragAgent.run(task: query)
            print("A: \(result.output)\n")
        }
    }
}

// MARK: - Research Graph

actor ResearchGraph {
    private let key: String
    private let vectorStore: VectorStore
    private let graph: AgentGraph
    
    // Specialized agents
    private let planner: Agent
    private let researcher: Agent
    private let extractor: Agent
    private let verifier: Agent
    private let synthesizer: Agent
    
    init(key: String, vectorStore: VectorStore) {
        self.key = key
        self.vectorStore = vectorStore
        
        let provider = OpenAIProvider(apiKey: key, model: .defaultChatGPTModel)
        
        // 1. Planner - Breaks down research into subtopics
        self.planner = Agent(
            name: "ResearchPlanner",
            provider: provider,
            systemPrompt: """
            You are a research planner. Given a research topic, break it down into 3-5 specific subtopics 
            that need to be researched to provide a comprehensive answer.
            
            Return ONLY a JSON array of subtopics like:
            ["subtopic 1", "subtopic 2", "subtopic 3"]
            
            Make subtopics specific and searchable.
            """,
            tools: [],
            maxIterations: 10
        )
        
        // 2. Researcher - Searches for information
        self.researcher = Agent(
            name: "WebResearcher",
            provider: provider,
            systemPrompt: """
            You are a web researcher. Search for information about the given subtopic.
            Use the web search tool to find current, accurate information.
            Summarize the key findings from multiple sources.
            """,
            tools: [WebSearchTool()],
            maxIterations: 10
        )
        
        // 3. Extractor - Pulls out key facts
        self.extractor = Agent(
            name: "FactExtractor",
            provider: provider,
            systemPrompt: """
            You are a fact extractor. From the research findings, extract:
            - Key facts (with sources)
            - Important dates
            - Technical details
            - Expert opinions
            
            Format as bullet points with [Source: ...] citations.
            """,
            tools: [],
            maxIterations: 10
        )
        
        // 4. Verifier - Cross-checks information
        self.verifier = Agent(
            name: "FactVerifier",
            provider: provider,
            systemPrompt: """
            You are a fact verifier. Review the extracted facts and:
            - Identify any contradictions
            - Flag unverified claims
            - Note consensus vs. disputed information
            - Assess source reliability
            
            Return a verification report.
            """,
            tools: [],
            maxIterations: 10
        )
        
        // 5. Synthesizer - Creates final report
        self.synthesizer = Agent(
            name: "ReportSynthesizer",
            provider: provider,
            systemPrompt: """
            You are a report writer. Synthesize all research into a comprehensive, well-structured report.
            
            Include:
            - Executive summary
            - Main findings (organized by theme)
            - Supporting details
            - Sources cited
            
            Write clearly and professionally.
            """,
            tools: [],
            maxIterations: 10
        )
        
        self.graph = AgentGraph(maxIterations: 20)
    }
    
    func research(topic: String) async throws -> ResearchReport {
        // Build the research graph
        await setupGraph()
        
        // Create initial state
        var state = GraphState()
        state.addMessage(.user(topic))
        state.setValue(.string(topic), forKey: "original_topic")
        state.setValue(.string("[]"), forKey: "subtopics")
        state.setValue(.string(""), forKey: "research_findings")
        state.setValue(.string(""), forKey: "extracted_facts")
        state.setValue(.string(""), forKey: "verification_report")
        state.setValue(.int(0), forKey: "sources_count")
        
        // Execute the graph
        print("Starting research pipeline...")
        let result = try await graph.invoke(input: state)
        
        // Extract final report
        let finalReport = result.messages.last(where: { $0.role == .assistant })?.textContent ?? "No report generated"
        let subtopicsJSON = result.getValue(forKey: "subtopics")?.stringValue ?? "[]"
        let sourcesCount = result.getValue(forKey: "sources_count")?.intValue ?? 0
        
        // Parse subtopics count
        let subtopics = try? JSONDecoder().decode([String].self, from: subtopicsJSON.data(using: .utf8)!)
        let subtopicsCount = subtopics?.count ?? 0
        
        // Save to RAG
        let documents = DocumentChunker.createDocuments(
            from: finalReport,
            chunkSize: 300,
            overlap: 50,
            sourceMetadata: [
                "source_id": UUID().uuidString,
                "source": "research_report",
                "topic": topic,
                "date": ISO8601DateFormatter().string(from: Date())
            ]
        )
        
        try await vectorStore.add(documents: documents)
        
        return ResearchReport(
            topic: topic,
            content: finalReport,
            subtopicsCount: subtopicsCount,
            sourcesCount: sourcesCount,
            iterations: result.visitedNodes.count,
            savedToRAG: true
        )
    }
    
    private func setupGraph() async {        
        // Node 1: Planning
        await graph.addNode("plan", agent: planner)
        
        // Node 2: Research (we'll handle parallelization via function node)
        await graph.addNode("research") { state in
            var newState = state
            
            // Parse subtopics from planner
            guard let subtopicsJSON = state.getValue(forKey: "subtopics")?.stringValue,
                  let data = subtopicsJSON.data(using: .utf8),
                  let subtopics = try? JSONDecoder().decode([String].self, from: data) else {
                return newState
            }
            
            print("    Researching \(subtopics.count) subtopics...")
            
            // Research each subtopic
            var allFindings: [String] = []
            var sourcesCount = 0
            
            for (index, subtopic) in subtopics.enumerated() {
                print("      \(index + 1). \(subtopic)")
                
                let result = try await self.researcher.run(task: "Research: \(subtopic)")
                allFindings.append("## \(subtopic)\n\n\(result.output)")
                
                // Count sources mentioned
                sourcesCount += result.output.components(separatedBy: "http").count - 1
            }
            
            newState.setValue(.string(allFindings.joined(separator: "\n\n")), forKey: "research_findings")
            newState.setValue(.int(sourcesCount), forKey: "sources_count")
            
            return newState
        }
        
        // Node 3: Extract facts
        await graph.addNode("extract", agent: extractor)
        
        // Node 4: Verify facts
        await graph.addNode("verify", agent: verifier)
        
        // Node 5: Synthesize report
        await graph.addNode("synthesize", agent: synthesizer)
        
        // Define edges (linear pipeline)
        await graph.addEdge(from: .START, to: "plan")
        
        // After planning, extract subtopics and trigger research
        await graph.addNode("extract_subtopics") { state in
            var newState = state
            
            // Get planner's output
            let plannerOutput = state.messages.last(where: { $0.role == .assistant })?.textContent ?? "[]"
            
            // Extract JSON array from output (might be wrapped in text)
            if let jsonStart = plannerOutput.range(of: "["),
               let jsonEnd = plannerOutput.range(of: "]", options: .backwards) {
                let jsonString = String(plannerOutput[jsonStart.lowerBound..<jsonEnd.upperBound])
                newState.setValue(.string(jsonString), forKey: "subtopics")
                
                if let data = jsonString.data(using: .utf8),
                   let subtopics = try? JSONDecoder().decode([String].self, from: data) {
                    print("Identified \(subtopics.count) subtopics")
                }
            }
            
            return newState
        }
        
        await graph.addEdge(from: "plan", to: "extract_subtopics")
        await graph.addEdge(from: "extract_subtopics", to: "research")
        await graph.addEdge(from: "research", to: "extract")
        
        // After extracting, create context for verifier
        await graph.addNode("prepare_verification") { state in
            var newState = state
            
            let findings = state.getValue(forKey: "research_findings")?.stringValue ?? ""
            let facts = state.messages.last(where: { $0.role == .assistant })?.textContent ?? ""
            
            newState.setValue(.string(facts), forKey: "extracted_facts")
            
            // Add verification prompt
            newState.addMessage(.user("""
            Verify these facts:
            
            \(facts)
            
            Against these research findings:
            
            \(findings)
            """))
            
            return newState
        }
        
        await graph.addEdge(from: "extract", to: "prepare_verification")
        await graph.addEdge(from: "prepare_verification", to: "verify")
        
        // After verification, prepare synthesis
        await graph.addNode("prepare_synthesis") { state in
            var newState = state
            
            let topic = state.getValue(forKey: "original_topic")?.stringValue ?? "Unknown"
            let facts = state.getValue(forKey: "extracted_facts")?.stringValue ?? ""
            let verification = state.messages.last(where: { $0.role == .assistant })?.textContent ?? ""
            
            newState.setValue(.string(verification), forKey: "verification_report")
            
            // Create comprehensive synthesis prompt
            newState.addMessage(.user("""
            Create a comprehensive research report on: \(topic)
            
            Key Facts:
            \(facts)
            
            Verification:
            \(verification)
            
            Write a clear, well-structured report with sources cited.
            """))
            
            return newState
        }
        
        await graph.addEdge(from: "verify", to: "prepare_synthesis")
        await graph.addEdge(from: "prepare_synthesis", to: "synthesize")
        await graph.addEdge(from: "synthesize", to: .END)
    }
}

// MARK: - Research Report

struct ResearchReport {
    let topic: String
    let content: String
    let subtopicsCount: Int
    let sourcesCount: Int
    let iterations: Int
    let savedToRAG: Bool
}

// MARK: - String Extension

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
