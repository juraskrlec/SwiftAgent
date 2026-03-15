# Advanced Features

This document covers multi-agent graphs, the memory system, and human-in-the-loop (HITL) capabilities.

---

## Multi-Agent Graphs

`AgentGraph` coordinates multiple agents and functions in a directed graph workflow, inspired by LangGraph.

### AgentGraph

```swift
public actor AgentGraph {
    public init(maxIterations: Int = 50)
}
```

### Adding Nodes

Nodes can be agents or functions:

```swift
// Agent node
await graph.addNode("researcher", agent: researchAgent)

// Function node
await graph.addNode("transform") { state in
    var s = state
    s.setValue(.string("processed"), forKey: "status")
    return s
}
```

### Adding Edges

```swift
// Simple edge
await graph.addEdge(from: "nodeA", to: "nodeB")

// From START
await graph.addEdge(from: .START, to: "firstNode")

// To END
await graph.addEdge(from: "lastNode", to: .END)

// Conditional edge (routes based on state)
await graph.addConditionalEdge(from: "classifier") { state in
    let category = state.getValue(forKey: "category")?.stringValue ?? "default"
    return category  // Returns the name of the next node
}

// Parallel edges (fan-out from START)
await graph.addParallelEdges(from: .START, to: ["agentA", "agentB", "agentC"])

// Convergence (fan-in: multiple nodes to one)
await graph.addEdge(from: ["agentA", "agentB", "agentC"], to: "aggregator")
```

### GraphState

State that flows through the graph:

```swift
public struct GraphState: Codable, Sendable {
    public var messages: [Message]
    public var data: [String: AnyCodable]
    public var currentNode: String?
    public var visitedNodes: [String]

    public init(
        messages: [Message] = [],
        data: [String: AnyCodable] = [:],
        currentNode: String? = nil,
        visitedNodes: [String] = []
    )

    public mutating func addMessage(_ message: Message)
    public mutating func setValue(_ value: AnyCodable, forKey key: String)
    public func getValue(forKey key: String) -> AnyCodable?
    public mutating func markNodeVisited(_ nodeName: String)
}
```

### Execution

#### Synchronous

```swift
var state = GraphState()
state.addMessage(.user("Research quantum computing"))

let result = try await graph.invoke(input: state)
let output = result.messages.last(where: { $0.role == .assistant })?.textContent ?? ""
```

#### Streaming

```swift
let events = await graph.stream(input: state)
for try await event in events {
    switch event {
    case .nodeStarted(let name):
        print("Starting: \(name)")
    case .nodeCompleted(let name, let state):
        print("Completed: \(name)")
    case .edgeTraversed(let from, let to):
        print("\(from) -> \(to)")
    case .graphCompleted(let finalState):
        print("Done")
    case .error(let error):
        print("Error: \(error)")
    }
}
```

### GraphEvent

```swift
public enum GraphEvent: Sendable {
    case nodeStarted(String)
    case nodeCompleted(String, GraphState)
    case edgeTraversed(String, String)
    case graphCompleted(GraphState)
    case error(Error)
}
```

### GraphError

```swift
public enum GraphError: Error, LocalizedError {
    case nodeNotFound(String)
    case maxIterationsReached(Int)
    case invalidGraph(String)
}
```

### Complete Graph Example

```swift
import SwiftAgent

let provider = OpenAIProvider(apiKey: key)

// Create specialized agents
let planner = Agent(
    name: "Planner",
    provider: provider,
    systemPrompt: "Break down tasks into subtopics. Return a JSON array.",
    tools: []
)

let researcher = Agent(
    name: "Researcher",
    provider: provider,
    systemPrompt: "Research the given topic thoroughly.",
    tools: [WebSearchTool()]
)

let writer = Agent(
    name: "Writer",
    provider: provider,
    systemPrompt: "Write a comprehensive report from the research.",
    tools: []
)

// Build the graph
let graph = AgentGraph(maxIterations: 30)
await graph.addNode("plan", agent: planner)
await graph.addNode("research", agent: researcher)
await graph.addNode("write", agent: writer)

await graph.addEdge(from: .START, to: "plan")
await graph.addEdge(from: "plan", to: "research")
await graph.addEdge(from: "research", to: "write")
await graph.addEdge(from: "write", to: .END)

// Execute
var state = GraphState()
state.addMessage(.user("Research the impact of AI on healthcare"))
let result = try await graph.invoke(input: state)
```

### Conditional Routing Example

```swift
let classifier = Agent(
    provider: provider,
    systemPrompt: "Classify the request. Set 'category' in your response to: technical, creative, or general."
)

let graph = AgentGraph()
await graph.addNode("classify", agent: classifier)
await graph.addNode("technical", agent: technicalAgent)
await graph.addNode("creative", agent: creativeAgent)
await graph.addNode("general", agent: generalAgent)

await graph.addEdge(from: .START, to: "classify")

// Route based on classification
await graph.addConditionalEdge(from: "classify") { state in
    let lastMessage = state.messages.last(where: { $0.role == .assistant })?.textContent ?? ""
    if lastMessage.contains("technical") { return "technical" }
    if lastMessage.contains("creative") { return "creative" }
    return "general"
}

await graph.addEdge(from: "technical", to: .END)
await graph.addEdge(from: "creative", to: .END)
await graph.addEdge(from: "general", to: .END)
```

---

## Memory System

SwiftAgent provides a three-tier memory system: working memory (short-term), episodic memory (conversation episodes), and semantic memory (long-term knowledge).

### MemoryManager

```swift
public actor MemoryManager {
    public init(
        store: MemoryStore,
        embeddingProvider: EmbeddingProvider? = nil,  // For semantic search
        llmProvider: LLMProvider                       // For memory extraction
    )
}
```

#### Methods

```swift
// Working memory (current session)
func getWorkingMemory(threadId: String) async throws -> WorkingMemory
func updateWorkingMemory(threadId: String, messages: [Message], userId: String) async throws

// Episodes (conversation summaries)
func saveEpisode(userId: String, threadId: String, messages: [Message], importance: Double = 0.5) async throws

// User profile
func getUserProfile(userId: String) async throws -> UserProfile
func updateProfile(_ profile: UserProfile) async throws

// Memory recall (search across all memory types)
func recallMemories(
    userId: String,
    query: String,
    includeEpisodes: Bool = true,
    includeSemanticMemory: Bool = true,
    limit: Int = 5
) async throws -> MemoryRecall
```

### MemoryRecall

```swift
public struct MemoryRecall: Sendable {
    public var profile: UserProfile?
    public var episodes: [Episode]
    public var semanticMemories: [SemanticMemory]
}
```

### Memory Types

#### WorkingMemory

Short-term memory for the current session:

```swift
public struct WorkingMemory: Codable, Sendable {
    public var entities: [String: Entity]       // Named entities discovered
    public var facts: [Fact]                    // Facts extracted
    public var context: [String: String]        // Key-value context
    public var recentSummary: String?           // Summary of recent conversation
    public var lastUpdated: Date

    public mutating func upsertEntity(_ entity: Entity)
    public mutating func addFact(_ fact: Fact)
    public mutating func setContext(key: String, value: String)
}
```

#### Entity

```swift
public struct Entity: Codable, Sendable, Identifiable {
    public let id: String
    public let type: EntityType                 // .person, .organization, .location, .project, .concept, .other
    public var name: String
    public var attributes: [String: String]
    public var mentions: Int
    public var firstSeen: Date
    public var lastSeen: Date
}
```

#### Fact

```swift
public struct Fact: Codable, Sendable, Identifiable {
    public let id: String
    public let content: String
    public let confidence: Double
    public let source: String
    public let timestamp: Date
    public var verified: Bool
}
```

#### UserProfile

```swift
public struct UserProfile: Codable, Sendable {
    public let userId: String
    public var name: String?
    public var preferences: [String: String]
    public var interests: [String]
    public var expertise: [String: ExpertiseLevel]     // .beginner, .intermediate, .advanced, .expert
    public var communicationStyle: CommunicationStyle   // .concise, .detailed, .casual, .professional
    public var metadata: [String: String]
    public var createdAt: Date
    public var updatedAt: Date
}
```

#### Episode

```swift
public struct Episode: Codable, Sendable, Identifiable {
    public let id: String
    public let userId: String
    public let threadId: String
    public var summary: String
    public var keyPoints: [String]
    public var entities: [String]
    public var sentiment: Sentiment                     // .positive, .neutral, .negative, .mixed
    public var importance: Double
    public var startTime: Date
    public var endTime: Date
    public var metadata: [String: String]
}
```

#### SemanticMemory

```swift
public struct SemanticMemory: Codable, Sendable, Identifiable {
    public let id: String
    public let userId: String
    public var category: String
    public var content: String
    public var relatedConcepts: [String]
    public var confidence: Double
    public var sources: [String]
    public var createdAt: Date
    public var lastAccessed: Date
    public var accessCount: Int
}
```

### MemoryStore Protocol

```swift
public protocol MemoryStore: Sendable {
    // User Profile
    func saveProfile(_ profile: UserProfile) async throws
    func loadProfile(userId: String) async throws -> UserProfile?

    // Episodes
    func saveEpisode(_ episode: Episode) async throws
    func loadEpisodes(userId: String, limit: Int) async throws -> [Episode]
    func searchEpisodes(userId: String, query: String, limit: Int) async throws -> [Episode]

    // Semantic Memory
    func saveSemanticMemory(_ memory: SemanticMemory) async throws
    func loadSemanticMemories(userId: String, limit: Int) async throws -> [SemanticMemory]
    func searchSemanticMemory(userId: String, query: String, limit: Int) async throws -> [SemanticMemory]

    // Working Memory
    func saveWorkingMemory(_ memory: WorkingMemory, threadId: String) async throws
    func loadWorkingMemory(threadId: String) async throws -> WorkingMemory?
    func clearWorkingMemory(threadId: String) async throws
}
```

### Store Implementations

#### InMemoryMemoryStore

```swift
public actor InMemoryMemoryStore: MemoryStore {
    public init()
}
```

#### SwiftDataMemoryStore

Persistent storage using SwiftData:

```swift
public actor SwiftDataMemoryStore: MemoryStore {
    public init(configuration: SwiftDataMemoryStoreConfiguration = .local) throws
}

public struct SwiftDataMemoryStoreConfiguration: Sendable {
    public var enableCloudSync: Bool
    public var isStoredInMemoryOnly: Bool
    public var cloudKitContainerIdentifier: String?

    public static let local: SwiftDataMemoryStoreConfiguration       // Local persistence
    public static let iCloud: SwiftDataMemoryStoreConfiguration      // iCloud sync
    public static let temporary: SwiftDataMemoryStoreConfiguration   // In-memory only
}
```

### Agent + Memory Integration

```swift
public struct MemoryConfig: Sendable {
    public let manager: MemoryManager
    public let userId: String
    public let autoSave: Bool

    public init(manager: MemoryManager, userId: String, autoSave: Bool = true)
}

// Agent extension
extension Agent {
    public func runWithMemory(
        task: String,
        config: MemoryConfig,
        threadId: String = UUID().uuidString
    ) async throws -> AgentResult
}
```

### Complete Memory Example

```swift
import SwiftAgent

let provider = ClaudeProvider(apiKey: claudeKey, model: .sonnet)
let embeddings = OpenAIEmbeddingProvider(apiKey: openaiKey)

// Persistent memory store
let memoryStore = try SwiftDataMemoryStore(configuration: .local)

let memoryManager = MemoryManager(
    store: memoryStore,
    embeddingProvider: embeddings,
    llmProvider: provider
)

let agent = Agent(
    provider: provider,
    systemPrompt: "You are a personal assistant with memory.",
    tools: [DateTimeTool()]
)

let config = MemoryConfig(
    manager: memoryManager,
    userId: "user_123",
    autoSave: true
)

// First conversation
let result1 = try await agent.runWithMemory(
    task: "My name is Alice. I prefer dark mode and use Swift.",
    config: config,
    threadId: "thread_1"
)

// Later conversation (agent remembers)
let result2 = try await agent.runWithMemory(
    task: "What do you remember about me?",
    config: config,
    threadId: "thread_2"
)

// Recall memories programmatically
let memories = try await memoryManager.recallMemories(userId: "user_123", query: "preferences")
print(memories.profile?.name)           // "Alice"
print(memories.profile?.preferences)    // ["theme": "dark"]
print(memories.episodes.count)          // Previous conversations
```

---

## Human-in-the-Loop (HITL)

Pause agent execution for human approval before or after specific tool calls.

### InterruptConfig

```swift
public struct InterruptConfig: Sendable {
    public let checkpointStore: CheckpointStore
    public let interruptBefore: [String]        // Tool names to pause BEFORE executing
    public let interruptAfter: [String]         // Tool names to pause AFTER executing

    public init(
        checkpointStore: CheckpointStore = InMemoryCheckpointStore(),
        interruptBefore: [String] = [],
        interruptAfter: [String] = []
    )
}
```

### InterruptRequest

When the agent hits an interrupt point:

```swift
public struct InterruptRequest: Codable, Sendable, Identifiable {
    public let id: String
    public let type: InterruptType              // .approval, .input, .decision, .review, .error
    public let checkpointId: String
    public let message: String
    public let options: [InterruptOption]?
    public let defaultOption: String?
    public let metadata: [String: String]
    public let timestamp: Date
}
```

### InterruptOption

```swift
public struct InterruptOption: Codable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let description: String?
    public let value: String
}
```

### InterruptResponse

```swift
public struct InterruptResponse: Codable, Sendable {
    public let requestId: String
    public let action: InterruptAction          // .approve, .reject, .modify, .retry, .skip, .rollback
    public let value: String?
    public let feedback: String?
    public let timestamp: Date
}
```

### InterruptibleResult

```swift
public struct InterruptibleResult: Sendable {
    public let agentResult: AgentResult
    public let threadId: String
    public let checkpoint: Checkpoint
    public let pendingInterrupt: InterruptRequest?
    public var success: Bool
    public var output: String
}
```

### Checkpoint

```swift
public struct Checkpoint: Codable, Sendable {
    public let id: String
    public let timestamp: Date
    public let state: AgentState
    public let pendingAction: PendingAction?
    public let metadata: [String: String]
}

public struct PendingAction: Codable, Sendable {
    public let toolCall: ToolCall
    public let severity: String
    public let description: String
    public let alternatives: [String]
}
```

### CheckpointStore Protocol

```swift
public protocol CheckpointStore: Sendable {
    func save(_ checkpoint: Checkpoint) async throws
    func load(id: String) async throws -> Checkpoint?
    func list(threadId: String) async throws -> [Checkpoint]
    func delete(id: String) async throws
    func latest(threadId: String) async throws -> Checkpoint?
}

// Built-in implementation
public actor InMemoryCheckpointStore: CheckpointStore {
    public init()
}
```

### Agent HITL Extension

```swift
extension Agent {
    // Start interruptible execution
    public func invoke(
        task: String,
        threadId: String = UUID().uuidString,
        config: InterruptConfig
    ) async throws -> InterruptibleResult

    // Resume after interrupt response
    public func updateState(
        _ response: InterruptResponse,
        threadId: String,
        config: InterruptConfig
    ) async throws -> InterruptibleResult
}
```

### Complete HITL Example

```swift
import SwiftAgent

let agent = Agent(
    provider: provider,
    systemPrompt: "You can manage files. Always explain what you're about to do.",
    tools: [FileSystemTool()],
    maxIterations: 10
)

let config = InterruptConfig(
    checkpointStore: InMemoryCheckpointStore(),
    interruptBefore: ["file_system_tool"],    // Pause before any file operation
    interruptAfter: []
)

// Start the task
let result = try await agent.invoke(
    task: "Delete the file at /tmp/test.txt",
    threadId: "session_1",
    config: config
)

// Check for pending interrupt
if let interrupt = result.pendingInterrupt {
    print("Agent wants to: \(interrupt.message)")

    // User approves
    let response = InterruptResponse(
        requestId: interrupt.id,
        action: .approve,
        value: nil,
        feedback: "Go ahead",
        timestamp: Date()
    )

    // Resume execution
    let resumed = try await agent.updateState(
        response,
        threadId: "session_1",
        config: config
    )
    print("Result: \(resumed.output)")
} else {
    print("Completed without interrupt: \(result.output)")
}
```

### Rejection Example

```swift
if let interrupt = result.pendingInterrupt {
    // User rejects the action
    let response = InterruptResponse(
        requestId: interrupt.id,
        action: .reject,
        value: nil,
        feedback: "Don't delete that file, read it instead.",
        timestamp: Date()
    )

    let resumed = try await agent.updateState(response, threadId: "session_1", config: config)
}
```
