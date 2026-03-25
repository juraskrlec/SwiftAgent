# SwiftAgent

  **Build powerful AI agents natively in Swift**
  
  [![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
  [![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20watchOS-blue.svg)](https://developer.apple.com)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
  [![GitHub Stars](https://img.shields.io/github/stars/juraskrlec/SwiftAgent.svg)](https://github.com/juraskrlec/SwiftAgents)

A native Swift framework for building autonomous AI agents with support for multiple LLM providers, tool execution, RAG (Retrieval-Augmented Generation), vision capabilities, and multi-agent workflows.

# Table of Contents

## Getting Started
- [Features](#features)
- [Installation](#installation)
  - [Swift Package Manager](#swift-package-manager)
- [Running Examples](#running-examples)
- [Requirements](#requirements)

## Quick Start
- [Simple Agent with Claude](#simple-agent-with-claude)
- [Using OpenAI](#using-openai)
- [Using Gemini (Google)](#using-gemini-google)
- [Using Apple Intelligence (On-Device)](#using-apple-intelligence-on-device)
## Core Capabilities

### Vision (Multimodal)
- [Basic Image Analysis](#basic-image-analysis)
- [Receipt Scanner](#receipt-scanner)
- [Multiple Images](#multiple-images)
- [Document Analysis](#document-analysis)
- [Vision with Streaming](#vision-with-streaming)
- [Supported Image Formats](#supported-image-formats)

### Agent Prompts from Markdown Files
- [Basic Usage](#basic-usage)
- [With Variables](#with-variables)
- [Frontmatter Support](#frontmatter-support)
- [Project Structure](#project-structure)

### RAG (Retrieval-Augmented Generation)
- [In-Memory Vector Store](#in-memory-vector-store)
- [Pinecone Vector Store](#pinecone-vector-store)
- [Gemini Embeddings](#gemini-embeddings)
  - [Task Types](#task-types)
  - [Controlling Embedding Size](#controlling-embedding-size)
  - [Multimodal Embeddings](#multimodal-embeddings)
- [OpenAI Embeddings](#openai-embeddings)
- [Document Chunking](#document-chunking)
- [RAG with Agents](#rag-with-agents)

### Streaming
- [Streaming Responses](#streaming-responses)

### Human-in-the-Loop
- [Basic Interrupt](#basic-interrupt)
- [Selective Tool Interrupts](#selective-tool-interrupts)

### Memory System
- [Memory Types](#memory-types)
- [SwiftData Storage (Production)](#swiftdata-storage-production)
- [Memory-Enabled Agent](#memory-enabled-agent)

## Tools & Extensions
- [Built-in Tools](#built-in-tools)
- [Creating Custom Tools](#creating-custom-tools)

## Advanced Features
- [Multi-Agent Graphs](#multi-agent-graphs)
- [Orchestration](#orchestration)
  - [Basic Orchestrator](#basic-orchestrator)
  - [Shared Workspace](#shared-workspace)
  - [Custom Orchestrator Prompt](#custom-orchestrator-prompt)
  - [AgentTool](#agenttool)
- [Provider Comparison](#provider-comparison)

## Configuration & Usage
- [Configuration](#configuration)
  - [Environment Variables](#environment-variables)
  - [Generation Options](#generation-options)
- [Error Handling](#error-handling)
- [Testing](#testing)

## Documentation for AI Assistants
- [LLM-Friendly Docs](#llm-friendly-documentation)

## Additional Resources
- [Examples](#examples)
- [Best Practices](#best-practices)
  - [Choose the Right Provider](#1-choose-the-right-provider)
  - [Vision Best Practices](#2-vision-best-practices)
  - [RAG Best Practices](#3-rag-best-practices)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)
- [Acknowledgments](#acknowledgments)
- [Support](#support)

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
- **Orchestration** - Coordinate multiple specialized agents with shared workspace
- **LLM-Friendly Documentation** - Comprehensive markdown docs (`CLAUDE.md` + `docs/`) for AI coding assistants to quickly understand and use the framework

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
    model: .gpt54  // or .gpt5Mini, .o1, .o1Mini
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
let provider = OpenAIProvider(apiKey: apiKey, model: .gpt54)
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
    provider: OpenAIProvider(apiKey: key, model: .gpt54),
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

## Agent Prompts from Markdown Files

SwiftAgent supports loading agent system prompts from markdown files, making it easy to maintain and version control your agent instructions.

### Basic Usage
```swift
// Load prompt from file
let agent = try Agent(
    name: "Assistant",
    provider: provider,
    promptFile: "Prompts/coding-assistant.md",
    tools: [FileSystemTool()]
)
```

### With Variables
```swift
// Use variables in your prompts
let agent = try Agent(
    name: "Support",
    provider: provider,
    promptFile: "Prompts/customer-support.md",
    promptVariables: [
        "company_name": "Acme Corp",
        "support_email": "help@acme.com"
    ]
)
```

In your markdown file:
```markdown
You are {{company_name}}'s customer support agent.
Contact: {{support_email}}
```

### Frontmatter Support

Add metadata to your prompt files:
```markdown
---
name: Coding Assistant
version: 1.0
model_recommendations: gpt-5.2
temperature: 0.3
---

# Your prompt content here...
```

### Project Structure
```
MyProject/
├── Prompts/
│   ├── coding-assistant.md
│   ├── research-assistant.md
│   └── customer-support.md
└── main.swift
```

This pattern makes it easy to:
- Version control your prompts
- Share prompts across projects
- A/B test different prompt versions
- Collaborate with non-technical team members

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

### Gemini Embeddings

`GeminiEmbeddingProvider` supports two models with different capabilities:

| Model | Modalities | MRL Truncation | Best For |
|---|---|---|---|
| `gemini-embedding-001` | Text only | ✅ 128–3072 dims | Cost-effective text RAG |
| `gemini-embedding-2-preview` | Text, Image, Audio, Video, PDF | ❌ | Multimodal search |
```swift
let embeddingProvider = GeminiEmbeddingProvider(
    apiKey: "your-google-key",
    model: .embedding001
)
```

#### Task Types

Specifying a task type optimises the embedding space for your use case, improving retrieval accuracy:
```swift
// When indexing documents
let docEmbedding = try await embeddingProvider.embed(
    text: "Swift is a powerful language for iOS development.",
    taskType: .retrievalDocument
)

// When embedding a search query
let queryEmbedding = try await embeddingProvider.embed(
    text: "iOS development tips",
    taskType: .retrievalQuery
)

// Other task types
// .semanticSimilarity   — duplicate detection, recommendations
// .classification       — sentiment analysis, spam detection
// .clustering           — document organisation
// .codeRetrievalQuery   — natural language → code search
// .questionAnswering    — chatbot Q&A retrieval
// .factVerification     — evidence retrieval
```

Use `embedBatch` with task types for efficient bulk indexing:
```swift
let embeddings = try await embeddingProvider.embedBatch(
    texts: documents.map(\.content),
    taskType: .retrievalDocument
)
```

#### Controlling Embedding Size

`gemini-embedding-001` uses Matryoshka Representation Learning (MRL), allowing you to truncate the default 3072-dimension vector to save storage and speed up similarity search with minimal quality loss.
```swift
// Recommended output sizes: 768, 1536, 3072 (default)
let embedding = try await embeddingProvider.embed(
    text: "What is SwiftUI?",
    taskType: .retrievalDocument,
    outputDimensionality: 768   // ~75% smaller, comparable MTEB score
)
```

| Dimensions | MTEB Score | Relative Size |
|---|---|---|
| 3072 (default) | 68.26 | 100% |
| 1536 | 68.17 | 50% |
| 768 | 67.99 | 25% |
| 512 | 67.55 | 17% |

> **Note:** The 3072-dimension output is pre-normalised. For 768 or 1536 dimensions, L2-normalise the result before computing cosine similarity.

#### Multimodal Embeddings

`gemini-embedding-2-preview` maps text, images, audio, video, and PDFs into the same vector space, enabling cross-modal search.
```swift
let multimodalProvider = GeminiEmbeddingProvider(
    apiKey: "your-google-key",
    model: .embedding2
)

// Embed an image
let imageData = try Data(contentsOf: imageURL)
let imageEmbedding = try await multimodalProvider.embedParts([
    .inlineData(mimeType: "image/png", base64Data: imageData.base64EncodedString())
])

// Embed text + image together (aggregated into one vector)
let combinedEmbedding = try await multimodalProvider.embedParts([
    .text("A photo of a dog"),
    .inlineData(mimeType: "image/png", base64Data: imageData.base64EncodedString())
])

// Embed a PDF (up to 6 pages)
let pdfData = try Data(contentsOf: pdfURL)
let pdfEmbedding = try await multimodalProvider.embedParts([
    .inlineData(mimeType: "application/pdf", base64Data: pdfData.base64EncodedString())
])
```

**Supported modalities and limits:**

| Modality | Formats | Limit |
|---|---|---|
| Text | — | 8,192 tokens |
| Image | PNG, JPEG | 6 images per request |
| Audio | MP3, WAV | 80 seconds |
| Video | MP4, MOV (H264, H265, AV1, VP9) | 128 seconds |
| PDF | — | 6 pages |

### OpenAI Embeddings

`OpenAIEmbeddingProvider` supports three models with different capability and cost trade-offs:

| Model | Dimensions | MRL Truncation | Notes |
|---|---|---|---|
| `textEmbedding3Small` | 1536 | ✅ | Best price/performance |
| `textEmbedding3Large` | 3072 | ✅ | Highest quality |
| `textEmbeddingAda002` | 1536 | ❌ | Legacy, not recommended |
```swift
let embeddingProvider = OpenAIEmbeddingProvider(
    apiKey: "your-openai-key",
    model: .textEmbedding3Small
)
```

#### Controlling Embedding Size

`text-embedding-3-small` and `text-embedding-3-large` support MRL truncation via the `dimensions` parameter. Smaller vectors reduce storage and speed up similarity search with minimal quality loss.
```swift
// Truncate text-embedding-3-large from 3072 → 256
// Still outperforms the full ada-002 (1536 dims) on MTEB
let embedding = try await embeddingProvider.embed(
    text: "What is SwiftUI?",
    outputDimensionality: 256
)
```

> **Note:** `textEmbeddingAda002` does not support the `dimensions` parameter — passing `outputDimensionality` is silently ignored for that model.

#### Batch Embedding

Pass up to 2,048 strings in a single request (max 300,000 tokens total across all inputs). Results are returned in the same order as the input regardless of how the API processes them.
```swift
let texts = documents.map(\.content)

let embeddings = try await embeddingProvider.embedBatch(
    texts: texts,
    outputDimensionality: 1536  // Truncate large model to match small model's default
)
```

#### Model Comparison

| Model | MTEB (English) | MIRACL (Multilingual) | Price per 1M tokens |
|---|---|---|---|
| `text-embedding-3-large` | 64.6% | 54.9% | $0.13 |
| `text-embedding-3-small` | 62.3% | 44.0% | $0.02 |
| `text-embedding-ada-002` | 61.0% | 31.4% | $0.10 |

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

## Orchestration

SwiftAgent provides a built-in orchestrator pattern for coordinating multiple specialized agents. An orchestrator agent delegates subtasks to worker agents and synthesizes their results using a shared workspace.

### Basic Orchestrator
```swift
// Create specialized worker agents
let researcher = Agent(
    name: "Researcher",
    provider: provider,
    systemPrompt: "Research topics thoroughly using web search.",
    tools: [WebSearchTool()],
    maxIterations: 5
)

let analyst = Agent(
    name: "Analyst",
    provider: provider,
    systemPrompt: "Analyze data and extract key trends and statistics.",
    tools: [CalculatorTool()],
    maxIterations: 3
)

let writer = Agent(
    name: "Writer",
    provider: provider,
    systemPrompt: "Write clear, well-structured reports with executive summaries.",
    maxIterations: 3
)

// Create orchestrator - automatically wraps workers as tools
let (orchestrator, workspace) = Agent.orchestrator(
    provider: provider,
    workers: [researcher, analyst, writer],
    maxIterations: 10
)

// Run a complex task - the orchestrator decides which agents to call
let result = try await orchestrator.run(
    task: "Research on-device AI on Apple platforms, analyze the capabilities, and write a report."
)
print(result.output)
```

The orchestrator LLM automatically:
- Breaks down the task into subtasks
- Delegates each subtask to the appropriate worker agent
- Passes shared context between workers via the workspace
- Synthesizes the final result

### Shared Workspace

The `Workspace` is a thread-safe actor that allows agents to share context:
```swift
// Pre-populate workspace with initial data
let workspace = Workspace(initialData: [
    "project": ["requirements": "Build a REST API with authentication"]
])

let (orchestrator, ws) = Agent.orchestrator(
    provider: provider,
    workers: [researcher, coder, reviewer],
    workspace: workspace
)

let result = try await orchestrator.run(task: "Implement the project requirements")

// Inspect what each agent contributed
let log = await ws.contributionLog()
for entry in log {
    print("[\(entry.agentName)] \(entry.key): \(entry.value.prefix(100))...")
}

// Read a specific agent's output
let review = await ws.read(namespace: "Reviewer", key: "result")
```

### Custom Orchestrator Prompt

Provide a custom system prompt to control orchestration strategy:
```swift
let (orchestrator, workspace) = Agent.orchestrator(
    name: "ProjectManager",
    provider: provider,
    systemPrompt: """
    You are a project manager coordinating a development team.
    Always start with research, then move to implementation, then review.
    If the reviewer finds issues, send the work back to the implementer.
    """,
    workers: [researcher, coder, reviewer],
    additionalTools: [FileSystemTool()],  // Extra tools for the orchestrator itself
    maxIterations: 15
)
```

### AgentTool

Under the hood, each worker agent is wrapped in an `AgentTool` that the orchestrator LLM can call like any other tool:
```swift
// Manual AgentTool creation (advanced usage)
let tool = AgentTool(
    agent: researcher,
    toolName: "research_agent",         // Custom tool name
    toolDescription: "Search the web and compile research findings",
    workspace: workspace                // Optional shared workspace
)

// Use it in any agent's tool list
let agent = Agent(
    name: "Coordinator",
    provider: provider,
    tools: [tool, CalculatorTool()]
)
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
- **OrchestratorExample** - Multi-agent orchestration with shared workspace

## Best Practices

### 1. Choose the Right Provider

- **Complex reasoning**: GPT-5.2, Claude Sonnet 4.6, Gemini 3.1 Pro
- **Vision**: GPT-5.2, Claude Sonnet 4.6, Gemini 3.1 Pro
- **Speed and cost**: Gemini 3.0 Flash, Claude Haiku
- **Privacy**: Apple Intelligence
- **Offline / no API key**: Apple Intelligence
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

## LLM-Friendly Documentation

SwiftAgent includes comprehensive markdown documentation designed for AI coding assistants (Claude Code, Cursor, GitHub Copilot, etc.) to quickly understand and use the framework.

| File | Description |
|------|-------------|
| [`CLAUDE.md`](CLAUDE.md) | Quick-start reference with concise examples for every feature |
| [`docs/providers.md`](docs/providers.md) | Full API reference for all LLM providers (Claude, OpenAI, Gemini, Apple Intelligence) |
| [`docs/agents.md`](docs/agents.md) | Agent API, execution methods, streaming events, prompts, and message types |
| [`docs/tools.md`](docs/tools.md) | Tool protocol, custom tool creation, and all built-in tool parameter tables |
| [`docs/rag.md`](docs/rag.md) | Embedding providers, vector stores, document chunking, and RAG pipeline |
| [`docs/advanced.md`](docs/advanced.md) | Multi-agent graphs, memory system, and human-in-the-loop |

Add `CLAUDE.md` or the `docs/` folder to your AI assistant's context for accurate code generation with SwiftAgent.

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
- [x] Orchestrator multi-agent coordination
- [x] LLM-friendly documentation (`CLAUDE.md` + `docs/`)
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
