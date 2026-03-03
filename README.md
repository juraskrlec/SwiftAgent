# SwiftAgent

  **Build powerful AI agents natively in Swift**
  
  [![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
  [![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20watchOS-blue.svg)](https://developer.apple.com)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
  [![GitHub Stars](https://img.shields.io/github/stars/juraskrlec/SwiftAgent.svg)](https://github.com/juraskrlec/SwiftAgents)

A native Swift framework for building autonomous AI agents with support for multiple LLM providers, tool execution, RAG (Retrieval-Augmented Generation), vision capabilities, and multi-agent workflows.

## Features

- **Multiple LLM Providers** - Claude (Anthropic), OpenAI (ChatGPT), Gemini (Google), and Apple Intelligence (on-device)
- **Vision Support** - Analyze images with GPT-5, Claude Sonnet 4.6, and Gemini 3.1
- **Tool System** - Built-in tools and easy custom tool creation
- **Autonomous Agents** - Agents that can reason and use tools to accomplish tasks
- **RAG Support** - Vector stores, embeddings, and knowledge bases for retrieval-augmented generation
- **Memory System** - Persistent conversation history with SwiftData and optional iCloud sync
- **Multi-Agent Graphs** - Build complex workflows with multiple specialized agents (LangGraph equivalent)
- **Human-in-the-Loop** - Interrupt agents for approval before executing tools
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
5. Run!

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
    model: .gpt52  // or .gpt52Mini, .o1, .o1Mini
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
    model: .gemini31Pro
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

## Vision (Multimodal)

SwiftAgent supports vision capabilities across multiple providers, allowing agents to analyze images.

### Basic Image Analysis
```swift
import SwiftAgent
import Foundation

// Load an image
let imageURL = URL(fileURLWithPath: "photo.jpg")
let imageData = try Data(contentsOf: imageURL)
let image = Message.ImageContent(data: imageData, mimeType: "image/jpeg")

// Create vision-capable agent
let provider = OpenAIProvider(apiKey: apiKey, model: .gpt52)
let agent = Agent(name: "VisionAgent", provider: provider)

// Analyze the image
let result = try await agent.run(
    task: "What's in this image? Describe in detail.",
    images: [image]
)

print(result.output)
```

### Receipt Scanner
```swift
let receiptAgent = Agent(
    name: "ReceiptScanner",
    provider: OpenAIProvider(apiKey: key, model: .gpt52),
    systemPrompt: """
    You are a receipt scanner. Extract structured information from receipt images.
    Return data in JSON format.
    """,
    tools: [OCRTool(), JSONParserTool()]
)

let receiptImage = Message.ImageContent(
    data: receiptImageData,
    mimeType: "image/jpeg"
)

let result = try await receiptAgent.run(
    task: "Extract merchant, date, total, and all items from this receipt",
    images: [receiptImage]
)

// Output: {"merchant": "Starbucks", "total": 15.42, "items": [...]}
```

### Multiple Images
```swift
let image1 = Message.ImageContent(data: photo1Data, mimeType: "image/jpeg")
let image2 = Message.ImageContent(data: photo2Data, mimeType: "image/jpeg")

let result = try await agent.run(
    task: "Compare these two images. What are the differences?",
    images: [image1, image2]
)
```

### Document Analysis
```swift
let docAgent = Agent(
    name: "DocumentAnalyzer",
    provider: ClaudeProvider(apiKey: key, model: .sonnet),
    tools: [OCRTool(), FileSystemTool()]
)

let documentImage = Message.ImageContent(
    data: documentData,
    mimeType: "image/png",
    detail: .high  // Request high-quality analysis (OpenAI)
)

let result = try await docAgent.run(
    task: """
    1. Extract all text from this document
    2. Summarize the main points
    3. Save the extracted text to a file
    """,
    images: [documentImage]
)
```

### Vision with Streaming
```swift
let stream = agent.stream(
    task: "Describe this image in detail",
    images: [image]
)

for try await event in stream {
    switch event {
    case .thinking(let text):
        print(text, terminator: "")
    case .completed(let result):
        print("\nAnalysis complete!")
    default:
        break
    }
}
```

### Supported Image Formats

| Format | OpenAI | Claude | Gemini |
|--------|--------|--------|--------|
| JPEG | ✅ | ✅ | ✅ |
| PNG | ✅ | ✅ | ✅ |
| WebP | ✅ | ✅ | ✅ |
| GIF | ✅ | ✅ | ✅ |

## RAG (Retrieval-Augmented Generation)

SwiftAgent includes comprehensive RAG support with vector stores and embeddings.

### In-Memory Vector Store
```swift
// Create embedding provider
let embeddingProvider = GeminiEmbeddingProvider(
    apiKey: "your-google-key",
    model: .embedding001  // Free!
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

vectorStore = PineconeVectorStore(apiKey: "<api_key>", host: "<direct_host>", embeddingProvider: embeddingProvider)

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
    provider: GeminiProvider(apiKey: geminiKey, model: .gemini31Pro),
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
            try await agent.resume()
        } else {
            try await agent.resume(
                overrideResult: "User denied permission to delete files."
            )
        }
        
    case .completed(let result):
        print("Done: \(result.output)")
        
    default:
        break
    }
}
```

### Selective Tool Interrupts

Only interrupt for specific tools:
```swift
let agent = Agent(
    name: "Assistant",
    provider: provider,
    tools: [DateTimeTool(), FileSystemTool(), HTTPRequestTool()],
    interruptBefore: ["file_system_tool", "http_request_tool"],  // Only these
    maxIterations: 10
)
```

## Agent Memory

SwiftAgent includes a comprehensive memory system for building agents that remember conversations, learn from interactions, and maintain context across sessions.

### Memory Types

1. **Working Memory** - Short-term memory for current conversation
2. **Episodic Memory** - Past conversations and interactions
3. **Semantic Memory** - Learned knowledge and facts
4. **User Profile** - User preferences and characteristics

### SwiftData Storage (Production)

For production with persistent storage and optional iCloud sync:
```swift
// Local storage only
let memoryStore = try SwiftDataMemoryStore(configuration: .local)

// iCloud sync enabled
let memoryStore = try SwiftDataMemoryStore(
    configuration: .init(enableCloudSync: true)
)
```

### Memory-Enabled Agent
```swift
let memoryStore = try SwiftDataMemoryStore(configuration: .local)
let userId = "user123"

// Load user profile
let profile = try await memoryStore.loadProfile(userId: userId)

// Build system prompt with memory
let systemPrompt = """
You are a helpful assistant for \(profile?.name ?? "the user").

User preferences:
- Communication style: \(profile?.communicationStyle.rawValue ?? "detailed")
- Interests: \(profile?.interests.joined(separator: ", ") ?? "none")

Remember past interactions and personalize responses.
"""

let agent = Agent(
    name: "MemoryAgent",
    provider: provider,
    systemPrompt: systemPrompt,
    tools: [DateTimeTool()],
    maxIterations: 10
)
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

// Web search - DuckDuckGo API
WebSearchTool()

// Vector search (RAG)
VectorSearchTool(vectorStore: vectorStore)

// Google Calendar
GoogleCalendarTool(accessToken: "token")

// Vision tools (for reference)
ImageAnalysisTool()
OCRTool()
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
        let temperature = await fetchWeather(location: location, units: units)
        
        return "The temperature in \(location) is \(temperature)°\(units == "celsius" ? "C" : "F")"
    }
}
```

## Multi-Agent Graphs

Build complex workflows with multiple specialized agents:
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

| Provider | API Key | Cost | Privacy | Tools | Streaming | Vision | Context |
|----------|---------|------|---------|-------|-----------|--------|---------|
| **Claude** | ✅ Required | 💰 Paid | ☁️ Cloud | ✅ Yes | ✅ Yes | ✅ Yes | 200K |
| **OpenAI** | ✅ Required | 💰 Paid | ☁️ Cloud | ✅ Yes | ✅ Yes | ✅ Yes | 128K |
| **Gemini** | ✅ Required | 🆓 Free/Paid | ☁️ Cloud | ✅ Yes | ✅ Yes | ✅ Yes | 2M |
| **Apple Intelligence** | ❌ Not needed | 🆓 Free | 🔒 On-device | ✅ Yes | ✅ Yes | ❌ No | 4K |

## Configuration

### Environment Variables
```bash
export ANTHROPIC_API_KEY="your-key-here"
export OPENAI_API_KEY="your-key-here"
export GOOGLE_API_KEY="your-key-here"
```

### Generation Options
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
swift test --filter VisionTests
swift test --filter GeminiProviderTests
swift test --filter MemoryTests
```

## Requirements

- iOS 17.0+ / macOS 14.0+ / watchOS 10.0+ / tvOS 17.0+
- Swift 6.0+
- Xcode 16.0+

**For Apple Intelligence:**
- iOS 26.0+ / macOS 26.0+
- Apple Silicon Mac (M1+) or iPhone 15 Pro+
- FoundationModels framework

## Examples

Check out the `Examples/` directory:
- **ResearchAssistant** - Multi-agent research pipeline with RAG
- **ContinuousLearner** - Agent that learns and improves over time
- **PersonalAssistant** - Agent that manages your Google Calendar

## Best Practices

### 1. Choose the Right Provider

- **Complex reasoning**: GPT-5.2, Claude Sonnet 4.6, Gemini 3.1 Pro
- **Vision**: GPT-5.2, Claude Sonnet 4.6, Gemini 3.1 Pro
- **Speed and cost**: Gemini 3.0 Flash, Claude Haiku
- **Privacy**: Apple Intelligence
- **Huge context**: Gemini (2M tokens)

### 2. Vision Best Practices

- Use high-quality images (JPG, PNG, WebP)
- For OCR, ensure text is clear and well-lit
- Specify detail level for OpenAI (`detail: .high`)
- Keep images under 20MB
- Use multiple images for comparisons

### 3. RAG Best Practices
```swift
// Chunk documents appropriately
let chunks = DocumentChunker.createDocuments(
    from: text,
    chunkSize: 300,      // ~300 words per chunk
    overlap: 50          // 50 words overlap
)

// Search with appropriate topK
let results = try await vectorStore.search(query: query, topK: 5)
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
- [x] Vision/multimodal support (images)
- [x] RAG support (In-Memory, Pinecone)
- [x] Memory system (SwiftData with iCloud sync)
- [x] Multi-agent graphs
- [x] Streaming responses
- [x] Human-in-the-loop
- [ ] Additional vector stores (Weaviate, Qdrant, Chroma)
- [ ] Agent templates for common use cases
- [ ] Audio/video support
- [ ] More built-in tools
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
