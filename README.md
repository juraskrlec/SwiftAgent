# SwiftAgent

  **Build powerful AI agents natively in Swift**
  
  [![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
  [![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20watchOS-blue.svg)](https://developer.apple.com)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
  [![GitHub Stars](https://img.shields.io/github/stars/juraskrlec/SwiftAgent.svg)](https://github.com/juraskrlec/SwiftAgents)

A native Swift framework for building autonomous AI agents with support for multiple LLM providers, tool execution, RAG (Retrieval-Augmented Generation), and multi-agent workflows.

## Features

- **Multiple LLM Providers** - Claude (Anthropic), OpenAI (ChatGPT), Gemini (Google), and Apple Intelligence (on-device)
- **Tool System** - Built-in tools and easy custom tool creation
- **Autonomous Agents** - Agents that can reason and use tools to accomplish tasks
- **RAG Support** - Vector stores, embeddings, and knowledge bases for retrieval-augmented generation
- **Multi-Agent Graphs** - Build complex workflows with multiple specialized agents (LangGraph equivalent)
- **Streaming Support** - Real-time response streaming for all providers
- **Type-Safe** - Full Swift type safety with Sendable and async/await
- **Apple Intelligence** - Privacy-focused on-device AI support

## Installation

### Swift Package Manager

Add SwiftAgent to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/juraskrlec/SwiftAgent", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version

## Running Examples
```bash
# Build project
swift build

# Set API keys
export OPENAI_API_KEY="your-key"
export ANTHROPIC_API_KEY="your-key"
export GOOGLE_API_KEY="your-key"

# Run Research Assistant
swift run ResearchAssistant

# Run Continuous Learner
swift run ContinuousLearner

# Run Personal Assistant
swift run PersonalAssistant
```

Or in Xcode:
1. Open Package.swift in Xcode
2. Select the scheme (ResearchAssistant or ContinuousLearner)
3. Edit Scheme → Run → Arguments → Environment Variables
4. Add OPENAI_API_KEY, GOOGLE_API_KEY and ANTHROPIC_API_KEY
5. Run

## Quick Start

### Simple Agent with Claude
```swift
import SwiftAgent

// Create a Claude provider
let provider = ClaudeProvider(
    apiKey: "your-anthropic-api-key",
    model: .sonnet  // or .opus, .haiku
)

// Create an agent with tools
let agent = Agent(
    name: "Assistant",
    provider: provider,
    systemPrompt: "You are a helpful assistant.",
    tools: [DateTimeTool()],
    maxIterations: 5
)

// Run the agent
let result = try await agent.run(task: "What's the date 30 days from now?")
print(result.output)
```

### Using OpenAI
```swift
let provider = OpenAIProvider(
    apiKey: "your-openai-api-key",
    model: .gpt4oMini  // or .gpt4o, .o1, .o1Mini
)

let agent = Agent(
    name: "Assistant",
    provider: provider,
    tools: [DateTimeTool(), JSONParserTool()]
)

let result = try await agent.run(task: "Parse this JSON and tell me the name...")
```

### Using Gemini (Google)
```swift
let provider = GeminiProvider(
    apiKey: "your-google-api-key",
    model: .gemini3Flash
)

let agent = Agent(
    name: "Assistant",
    provider: provider,
    tools: [WebSearchTool(), DateTimeTool()]
)

let result = try await agent.run(task: "Search for latest Swift news")
```

### Using Apple Intelligence (On-Device)
```swift
#if canImport(FoundationModels)

// No API key needed - runs on-device!
let provider = try await AppleIntelligenceProvider(
    instructions: "You are a helpful assistant.",
    maxContextTokens: 3000
)

let agent = Agent(
    name: "OnDeviceAgent",
    provider: provider,
    tools: [DateTimeTool()]
)

let result = try await agent.run(task: "What's the date 7 days from now?")

#endif
```

**Requirements for Apple Intelligence:**
- iOS 26.0+, macOS 26.0+
- Device with Apple Intelligence support (iPhone 15 Pro+, M1+ Macs)
- FoundationModels framework

## RAG (Retrieval-Augmented Generation)

SwiftAgent includes comprehensive RAG support with vector stores and embeddings.

### In-Memory Vector Store
```swift
// Create embedding provider
let embeddingProvider = GeminiEmbeddingProvider(
    apiKey: "your-google-key",
    model: .embedding001
)

// Or use OpenAI embeddings
let embeddingProvider = OpenAIEmbeddingProvider(
    apiKey: "your-openai-key",
    model: .textEmbedding3Small
)

// Create vector store
let vectorStore = InMemoryVectorStore(embeddingProvider: embeddingProvider)

// Add documents
let documents = [
    Document(
        id: "doc1",
        content: "Swift is a powerful programming language for iOS development.",
        metadata: ["category": "swift", "source": "docs"]
    ),
    Document(
        id: "doc2",
        content: "SwiftUI is Apple's modern framework for building user interfaces.",
        metadata: ["category": "swiftui", "source": "docs"]
    )
]

try await vectorStore.add(documents: documents)

// Search
let results = try await vectorStore.search(query: "iOS development", topK: 5)

for result in results {
    print("Score: \(result.score)")
    print("Content: \(result.content)")
}
```

### Pinecone Vector Store

For production use with persistent storage:
```swift
let embeddingProvider = OpenAIEmbeddingProvider(
    apiKey: "your-openai-key",
    model: .textEmbedding3Small
)

let vectorStore = PineconeVectorStore(
    apiKey: "your-pinecone-key",
    environment: "us-east-1",
    indexName: "swiftagent-knowledge",
    embeddingProvider: embeddingProvider,
    dimension: 768
)

// Add documents (automatically generates embeddings)
try await vectorStore.add(documents: documents)

// Search (persists across app restarts)
let results = try await vectorStore.search(query: "Swift programming", topK: 5)
```

### Document Chunking

For long documents, use the chunking utility:
```swift
let longDocument = """
Very long document content...
Spans multiple paragraphs...
Contains lots of information...
"""

// Chunk by word count
let documents = DocumentChunker.createDocuments(
    from: longDocument,
    chunkSize: 300,        // words per chunk
    overlap: 50,           // overlapping words
    sourceMetadata: [
        "source": "documentation",
        "category": "swift",
        "date": "2026-02-13"
    ]
)

// Add chunks to vector store
try await vectorStore.add(documents: documents)
```

### RAG with Agents
```swift
// Create RAG-enabled agent
let ragAgent = Agent(
    name: "KnowledgeAgent",
    provider: GeminiProvider(apiKey: geminiKey, model: .gemini3Flash),
    systemPrompt: """
    You are a helpful assistant with access to a knowledge base.
    Use the search_knowledge_base tool to find relevant information.
    Always cite your sources.
    """,
    tools: [
        VectorSearchTool(vectorStore: vectorStore, defaultTopK: 5)
    ],
    maxIterations: 5
)

// Agent automatically searches knowledge base
let result = try await ragAgent.run(
    task: "What did we learn about Swift programming?"
)
print(result.output)
```

### Complete RAG Example
```swift
let openAIKey = "your-openai-api-key"

// 1. Embeddings
let embeddingProvider = OpenAIEmbeddingProvider(
    apiKey: openAIKey,
    model: .textEmbedding3Small
)

// 2. Vector Store
let vectorStore = InMemoryVectorStore(embeddingProvider: embeddingProvider)

// 3. LLM Provider
let llmProvider = OpenAIProvider(
    apiKey: openAIKey,
    model: .gpt52Mini
)

// 4. Load knowledge
let knowledge = """
SwiftAgent is a native Swift framework for building AI agents.
It supports multiple LLM providers including Claude, OpenAI, Gemini, and Apple Intelligence.
The framework includes RAG support with vector stores and embeddings.
"""

let docs = DocumentChunker.createDocuments(
    from: knowledge,
    chunkSize: 100,
    overlap: 20,
    sourceMetadata: ["source": "readme"]
)

try await vectorStore.add(documents: docs)

// 5. Create RAG agent
let agent = Agent(
    name: "KnowledgeBot",
    provider: llmProvider,
    systemPrompt: "Answer questions using the knowledge base. Cite sources.",
    tools: [VectorSearchTool(vectorStore: vectorStore)],
    maxIterations: 5
)

// 6. Ask questions
let result = try await agent.run(task: "What providers does SwiftAgent support?")
print(result.output)

```

## Streaming Responses
```swift
let agent = Agent(
    name: "StreamingAgent",
    provider: provider,
    tools: [DateTimeTool()]
)

let stream = agent.stream(task: "Calculate the date 45 days from now")

for try await event in stream {
    switch event {
    case .thinking(let text):
        print(text, terminator: "")
    case .toolCall(let call):
        print("\n🔧 Using tool: \(call.name)")
    case .toolResult(let result, _):
        print("Result: \(result)")
    case .completed(let result):
        print("\nDone: \(result.output)")
    case .error(let error):
        print("Error: \(error)")
    }
}
```

## Human-in-the-Loop

SwiftAgent supports interrupting agent execution to get human approval or input during task execution.

### Basic Interrupt

```swift
let agent = Agent(
    name: "Assistant",
    provider: provider,
    systemPrompt: "You are a helpful assistant.",
    tools: [DateTimeTool(), FileSystemTool()],
    maxIterations: 10
)

// Agent will pause before executing tools
let stream = agent.stream(task: "Delete all temporary files")

for try await event in stream {
    switch event {
    case .interrupt(let pendingCall):
        print("Agent wants to call: \(pendingCall.name)")
        print("Arguments: \(pendingCall.arguments)")
        
        // Get user approval
        print("Approve? (y/n): ", terminator: "")
        let input = readLine()
        
        if input?.lowercased() == "y" {
            // Continue with execution
            try await agent.resume()
        } else {
            // Cancel and provide alternative
            try await agent.resume(
                overrideResult: "User denied permission to delete files."
            )
        }
        
    case .toolCall(let call):
        print("🔧 Executing: \(call.name)")
        
    case .completed(let result):
        print("Done: \(result.output)")
        
    case .error(let error):
        print("Error: \(error)")
        
    default:
        break
    }
}
```

### Selective Tools Interrupt

Only interrupt for specific tools:

```swift
let agent = Agent(
    name: "Assistant",
    provider: provider,
    tools: [
        DateTimeTool(),
        FileSystemTool(),
        HTTPRequestTool()
    ],
    interruptBefore: ["file_system_tool", "http_request_tool"],  // Only these
    maxIterations: 10
)

let stream = agent.stream(task: "Check the date and delete old files")

for try await event in stream {
    switch event {
    case .interrupt(let pendingCall):
        // Only FileSystemTool and HTTPRequestTool trigger interrupts
        print("Agent wants to: \(pendingCall.name)")
        
        let approved = await getUserApproval(for: pendingCall)
        
        if approved {
            try await agent.resume()
        } else {
            try await agent.resume(overrideResult: "Permission denied")
        }
        
    case .completed(let result):
        print(result.output)
        
    default:
        break
    }
}
```

### Custom Approval Logic

```swift
func getUserApproval(for toolCall: ToolCall) async -> Bool {
    switch toolCall.name {
    case "file_system_tool":
        // Check if deleting system files
        if let path = toolCall.arguments["path"] as? String,
           path.hasPrefix("/System") {
            return false  // Auto-deny
        }
        return true  // Auto-approve safe paths
        
    case "http_request_tool":
        // Check if external API
        if let url = toolCall.arguments["url"] as? String,
           !url.contains("mycompany.com") {
            // Ask user for external APIs
            return await promptUser("Allow request to \(url)?")
        }
        return true
        
    default:
        return true
    }
}
```

## Agent Memory

SwiftAgent includes a comprehensive memory system for building agents that remember conversations, learn from interactions, and maintain context across sessions.

### Memory Types

SwiftAgent supports four types of memory:

    1. Working Memory - Short-term memory for current conversation
    2. Episodic Memory - Past conversations and interactions
    3. Semantic Memory - Learned knowledge and facts
    4. User Profile - User preferences and characteristics
    
### In-Memory Storage 

For development and testing:

```swift
let memoryStore = InMemoryMemoryStore()

// Save user profile
let profile = UserProfile(
    userId: "user123",
    name: "Jura",
    preferences: ["theme": "dark", "language": "en"],
    interests: ["Swift", "AI", "iOS"],
    expertise: ["Swift": .advanced, "Python": .intermediate],
    communicationStyle: .detailed
)

try await memoryStore.saveProfile(profile)

// Load profile
let loaded = try await memoryStore.loadProfile(userId: "user123")
print(loaded?.name)
```

### SwiftData Storage 

For production with persistent storage and optional iCloud sync:

```swift
// Local storage only
let memoryStore = try SwiftDataMemoryStore(
    configuration: .local
)

// iCloud sync enabled
let memoryStore = try SwiftDataMemoryStore(
    configuration: .init(enableCloudSync: true)
)

// Custom configuration
let memoryStore = try SwiftDataMemoryStore(
    configuration: .init(
        enableCloudSync: true,
        cloudKitContainerIdentifier: "iCloud.com.yourapp.agents"
    )
)
```

### Episodic Memory

Store and retrieve past conversations:

```swift
// Save episode
let episode = Episode(
    userId: "user123",
    threadId: "thread-abc",
    summary: "Discussed Swift concurrency and actors",
    keyPoints: [
        "Learned about actor isolation",
        "Discussed async/await patterns",
        "Explored TaskGroup usage"
    ],
    entities: ["Swift", "Concurrency", "Actors"],
    sentiment: .positive,
    importance: 0.8,
    startTime: Date().addingTimeInterval(-3600),
    endTime: Date()
)

try await memoryStore.saveEpisode(episode)

// Load recent episodes
let recentEpisodes = try await memoryStore.loadEpisodes(
    userId: "user123",
    limit: 10
)

// Search episodes
let swiftEpisodes = try await memoryStore.searchEpisodes(
    userId: "user123",
    query: "Swift",
    limit: 5
)

for episode in swiftEpisodes {
    print("Summary: \(episode.summary)")
    print("Key points: \(episode.keyPoints)")
    print("Importance: \(episode.importance)")
}
```

### Semantic Memory:

Store learned knowledge:

```swift
// Save knowledge
let memory = SemanticMemory(
    userId: "user123",
    category: "Programming",
    content: "Swift uses value types (structs) for performance and safety",
    relatedConcepts: ["Swift", "Structs", "Value Types"],
    confidence: 0.95,
    sources: ["episode-123", "documentation"]
)

try await memoryStore.saveSemanticMemory(memory)

// Load by category
let programmingKnowledge = try await memoryStore.loadSemanticMemories(
    userId: "user123",
    category: "Programming",
    limit: 10
)

// Search semantic memory
let swiftKnowledge = try await memoryStore.searchSemanticMemory(
    userId: "user123",
    query: "Swift type system",
    limit: 5
)
```

### Working Memory

Temporary memory for current conversation:

```swift
let threadId = "current-conversation"

// Create working memory
var workingMemory = WorkingMemory()

// Add entities mentioned in conversation
let entity = Entity(
    type: .person,
    name: "Alice",
    attributes: ["role": "developer", "expertise": "Swift"]
)
workingMemory.upsertEntity(entity)

// Add facts
let fact = Fact(
    content: "Alice prefers functional programming patterns",
    confidence: 0.8,
    source: "conversation"
)
workingMemory.addFact(fact)

// Set context
workingMemory.setContext(key: "topic", value: "Swift development")
workingMemory.recentSummary = "Discussing Swift best practices"

// Save
try await memoryStore.saveWorkingMemory(workingMemory, threadId: threadId)

// Load later
let loaded = try await memoryStore.loadWorkingMemory(threadId: threadId)
print(loaded?.context["topic"])  // "Swift development"

// Clear when done
try await memoryStore.clearWorkingMemory(threadId: threadId)
```

### Memory-Enabled Agent

```swift
let memoryStore = try SwiftDataMemoryStore(configuration: .local)
let userId = "user123"

// Load user profile
let profile = try await memoryStore.loadProfile(userId: userId)

// Load recent context
let recentEpisodes = try await memoryStore.loadEpisodes(
    userId: userId,
    limit: 5
)

// Build system prompt with memory
let systemPrompt = """
You are a helpful assistant for \(profile?.name ?? "the user").

User preferences:
- Communication style: \(profile?.communicationStyle.rawValue ?? "detailed")
- Interests: \(profile?.interests.joined(separator: ", ") ?? "none")

Recent conversations:
\(recentEpisodes.map { "- \($0.summary)" }.joined(separator: "\n"))

Remember past interactions and personalize responses.
"""

let agent = Agent(
    name: "MemoryAgent",
    provider: provider,
    systemPrompt: systemPrompt,
    tools: [DateTimeTool()],
    maxIterations: 10
)

// Run agent
let result = try await agent.run(task: "What did we discuss last time?")

// Save new episode after conversation
let newEpisode = Episode(
    userId: userId,
    threadId: UUID().uuidString,
    summary: "Discussed past conversation history",
    keyPoints: ["Reviewed memory system", "Explained episode storage"],
    startTime: Date().addingTimeInterval(-300),
    endTime: Date()
)

try await memoryStore.saveEpisode(newEpisode)
```


### Memory with RAG

Combine memory with vector search:

```swift
// Create memory-enhanced RAG agent
let memoryStore = try SwiftDataMemoryStore(configuration: .local)
let vectorStore = InMemoryVectorStore(embeddingProvider: embeddingProvider)

// Load user's learned knowledge into vector store
let semanticMemories = try await memoryStore.loadSemanticMemories(
    userId: "user123",
    category: nil,
    limit: 100
)

let memoryDocs = semanticMemories.map { memory in
    Document(
        id: memory.id,
        content: memory.content,
        metadata: [
            "category": memory.category,
            "confidence": String(memory.confidence),
            "sources": memory.sources.joined(separator: ",")
        ]
    )
}

try await vectorStore.add(documents: memoryDocs)

// Create agent with both memory and RAG
let agent = Agent(
    name: "SmartAssistant",
    provider: provider,
    systemPrompt: "Use both your memory and knowledge base to help the user.",
    tools: [
        VectorSearchTool(vectorStore: vectorStore),
        DateTimeTool()
    ],
    maxIterations: 10
)
```

### Multi-User Memory

```swift
// User 1
let user1Profile = UserProfile(
    userId: "user1",
    name: "Alice",
    interests: ["Swift", "iOS"]
)
try await memoryStore.saveProfile(user1Profile)

let user1Episode = Episode(
    userId: "user1",
    threadId: "thread1",
    summary: "Learned about SwiftUI",
    startTime: Date(),
    endTime: Date()
)
try await memoryStore.saveEpisode(user1Episode)

// User 2
let user2Profile = UserProfile(
    userId: "user2",
    name: "Bob",
    interests: ["Python", "ML"]
)
try await memoryStore.saveProfile(user2Profile)

let user2Episode = Episode(
    userId: "user2",
    threadId: "thread2",
    summary: "Discussed machine learning",
    startTime: Date(),
    endTime: Date()
)
try await memoryStore.saveEpisode(user2Episode)

// Load per-user data
let aliceEpisodes = try await memoryStore.loadEpisodes(
    userId: "user1",
    limit: 10
)  // Only Alice's episodes

let bobEpisodes = try await memoryStore.loadEpisodes(
    userId: "user2",
    limit: 10
)  // Only Bob's episodes
```

## Built-in Tools

SwiftAgent includes several ready-to-use tools:
```swift
// Date and time operations
DateTimeTool()

// JSON parsing and extraction
JSONParserTool()

// HTTP requests
HTTPRequestTool()

// File system operations
FileSystemTool(allowedPaths: ["/tmp"])

// Web search - Based on DuckDuckGo API
WebSearchTool()

// Vector search (RAG)
VectorSearchTool(vectorStore: vectorStore)

// Google Calendar
GoogleCalendarTool(accessToken: "")

// Calendar - Apple Calendar
CalendarTool()
```

## Creating Custom Tools

```swift
struct WeatherTool: Tool, Sendable {
    let name = "get_weather"
    let description = "Get current weather for a location"
    
    var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "location": ParameterProperty(
                    type: "string",
                    description: "City name"
                ),
                "units": ParameterProperty(
                    type: "string",
                    description: "Temperature units",
                    enumValues: ["celsius", "fahrenheit"]
                )
            ],
            required: ["location"]
        )
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let location = arguments["location"] as? String else {
            throw ToolError.invalidArguments("Missing location")
        }
        
        let units = arguments["units"] as? String ?? "celsius"
        
        // Your weather API logic here
        let temperature = await fetchWeather(location: location, units: units)
        
        return "The temperature in \(location) is \(temperature)°\(units == "celsius" ? "C" : "F")"
    }
}
```

## Multi-Agent Graphs

Build complex workflows with multiple specialized agents:

### Linear Workflow

```swift
let researcher = Agent(
    name: "Researcher",
    provider: provider,
    systemPrompt: "Research topics thoroughly.",
    tools: [WebSearchTool()]
)

let writer = Agent(
    name: "Writer",
    provider: provider,
    systemPrompt: "Write clear summaries."
)

let graph = AgentGraph()
await graph.addNode("research", agent: researcher)
await graph.addNode("write", agent: writer)
await graph.addEdge(from: .START, to: "research")
await graph.addEdge(from: "research", to: "write")
await graph.addEdge(from: "write", to: .END)

var state = GraphState()
state.addMessage(.user("Research and write about Swift concurrency"))

let result = try await graph.invoke(input: state)
```

## Provider Comparison

| Provider | API Key | Cost | Privacy | Tools | Streaming | Context |
|----------|---------|------|---------|-------|-----------|---------|
| **Claude** | ✅ Required | 💰 Paid | ☁️ Cloud | ✅ Yes | ✅ Yes | 200K |
| **OpenAI** | ✅ Required | 💰 Paid | ☁️ Cloud | ✅ Yes | ✅ Yes | 128K |
| **Gemini** | ✅ Required | 🆓 Free/Paid | ☁️ Cloud | ✅ Yes | ✅ Yes | 2M |
| **Apple Intelligence** | ❌ Not needed | 🆓 Free | 🔒 On-device | ✅ Yes | ✅ Yes | 4K |


## Vector Store Comparison

| Store | Persistence | Scale | Cost | Best For |
|-------|------------|-------|------|----------|
| **InMemoryVectorStore** | Lost on restart | Small (< 100K docs) | 🆓 Free | Development, testing |
| **PineconeVectorStore** | Permanent | Millions of docs | $0.096/GB/month | Production |

## Configuration

### Environment Variables

For testing, set API keys as environment variables:
```bash
export ANTHROPIC_API_KEY="your-key-here"
export OPENAI_API_KEY="your-key-here"
export GOOGLE_API_KEY="your-key-here"
```

### Generation Options

Customize generation behavior:
```swift
let options = GenerationOptions(
    maxTokens: 2000,
    temperature: 0.7,
    topP: 0.9,
    stopSequences: ["END"]
)

let response = try await provider.generate(
    messages: messages,
    tools: tools,
    options: options
)
```

## Error Handling
```swift
do {
    let result = try await agent.run(task: "Your task")
    print(result.output)
} catch AgentError.maxIterationsReached(let max) {
    print("Agent used all \(max) iterations")
} catch LLMError.rateLimitExceeded {
    print("Rate limit hit, retry later")
} catch LLMError.authenticationFailed {
    print("Invalid API key")
} catch {
    print("Error: \(error)")
}
```

## Testing

Run tests with:
```bash
swift test
```

Set API keys for provider tests:
```bash
export ANTHROPIC_API_KEY="your-key"
export OPENAI_API_KEY="your-key"
export GOOGLE_API_KEY="your-key"
swift test
```

Run specific tests:
```bash
swift test --filter AppleIntelligenceTests
swift test --filter GeminiProviderTests
swift test --filter GeminiEmbeddingTests
```

## Requirements

- iOS 17.0+ / macOS 14.0+ / watchOS 10.0+ / tvOS 17.0+
- Swift 6.0+
- Xcode 26.0+

**For Apple Intelligence:**
- iOS 26.0+ / macOS 26.0+
- Apple Silicon Mac (M1+) or iPhone 15 Pro+
- FoundationModels framework

## API Keys

### Claude (Anthropic)

Get your API key from [console.anthropic.com](https://platform.claude.com/settings/keys)
```swift
let provider = ClaudeProvider(apiKey: "sk-ant-...")
```

### OpenAI

Get your API key from [platform.openai.com](https://platform.openai.com/api-keys)
```swift
let provider = OpenAIProvider(apiKey: "sk-...")
```

### Gemini (Google)

Get your API key from [ai.google.dev](https://aistudio.google.com/app/api-keys)
```swift
let provider = GeminiProvider(apiKey: "...")
```

### Pinecone (Optional - for persistent RAG)

Get your API key from [pinecone.io](https://www.pinecone.io)
```swift
let vectorStore = PineconeVectorStore(
    apiKey: "...",
    environment: "us-east-1",
    indexName: "my-index",
    embeddingProvider: embeddingProvider
)
```

## Examples

Check out the `Examples/` directory for complete examples:
- **ResearchAssistant** - Multi-agent research pipeline with RAG
- **ContinuousLearner** - Agent that learns and improves over time
- **PersonalAssistan** - Agent that manages your Google Calendar

## Best Practices

### 1. Choose the Right Provider

- **Complex reasoning**: Claude Opus or Sonnet
- **Speed and cost**: Gemini 3 Flash, Claude Haiku, OpenAI GPT-5.2 Nano
- **Privacy**: Apple Intelligence
- **Huge context**: Gemini (2M tokens)

### 2. RAG Best Practices
```swift
// Chunk documents appropriately
let chunks = DocumentChunker.createDocuments(
    from: text,
    chunkSize: 300,      // ~300 words per chunk
    overlap: 50          // 50 words overlap for context
)

// Use descriptive metadata
let doc = Document(
    id: "unique-id",
    content: "...",
    metadata: [
        "source": "documentation",
        "category": "swift",
        "date": "2026-02-13",
        "author": "team"
    ]
)

// Search with appropriate topK
let results = try await vectorStore.search(
    query: query,
    topK: 5  // 3-5 results usually optimal
)
```

### 3. Free RAG Stack
```swift
// Use Gemini
let embeddingProvider = GeminiEmbeddingProvider(apiKey: key)
let vectorStore = InMemoryVectorStore(embeddingProvider: embeddingProvider)
let llmProvider = GeminiProvider(apiKey: key, model: .gemini20FlashExp)
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Add tests for new functionality
4. Ensure all tests pass (`swift test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Roadmap

- [x] Claude, OpenAI, Gemini, Apple Intelligence providers
- [x] RAG support (In-Memory, Pinecone)
- [x] Multi-agent graphs
- [x] Streaming responses
- [x] Memory system for persistent conversation history
- [ ] Additional vector stores (Weaviate, Qdrant, Chroma)
- [ ] Agent templates for common use cases
- [ ] Vision/multimodal tool support
- [ ] More built-in tools (Calendar, Contacts, Email, etc.)
- [ ] Agent observability and debugging tools

## License

MIT License - see [LICENSE](LICENSE) file for details

## Acknowledgments

- Inspired by [LangChain](https://github.com/langchain-ai/langchain) and [LangGraph](https://github.com/langchain-ai/langgraph)

## Support

- [Documentation](https://github.com/juraskrlec/SwiftAgent/wiki)
- [Issue Tracker](https://github.com/juraskrlec/SwiftAgent/issues)
- [Discussions](https://github.com/juraskrlec/SwiftAgent/discussions)
- Email: jskrlec4@gmail.com

---

**SwiftAgent** - Build powerful AI agents natively in Swift 🚀

Made with ❤️ by Jura Skrlec
