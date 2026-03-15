# RAG (Retrieval-Augmented Generation)

SwiftAgent provides a complete RAG pipeline: document chunking, embedding providers, vector stores, and a search tool for agents.

## Overview

```
Text -> DocumentChunker -> [Document] -> VectorStore.add()
                                              |
Query -> VectorStore.search() -> [SearchResult] -> Agent context
```

---

## EmbeddingProvider Protocol

```swift
public protocol EmbeddingProvider: Sendable {
    func embed(text: String) async throws -> [Float]
    func embedBatch(texts: [String]) async throws -> [[Float]]
}
```

Extended methods (optional overrides):

```swift
func embed(text: String, taskType: EmbeddingTaskType?, outputDimensionality: Int?) async throws -> [Float]
func embedBatch(texts: [String], taskType: EmbeddingTaskType?, outputDimensionality: Int?) async throws -> [[Float]]
```

### EmbeddingTaskType

```swift
public enum EmbeddingTaskType: String {
    case semanticSimilarity
    case classification
    case clustering
    case retrievalDocument
    case retrievalQuery
    case codeRetrievalQuery
    case questionAnswering
    case factVerification
}
```

### EmbeddingError

```swift
public enum EmbeddingError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    case emptyText
    case unsupportedModality
}
```

---

## OpenAIEmbeddingProvider

```swift
public actor OpenAIEmbeddingProvider: EmbeddingProvider
```

### Models

| Case | Raw Value | Dimensions | Supports MRL |
|------|-----------|-----------|--------------|
| `.textEmbedding3Small` | `text-embedding-3-small` | 1536 | Yes |
| `.textEmbedding3Large` | `text-embedding-3-large` | 3072 | Yes |
| `.textEmbeddingAda002` | `text-embedding-ada-002` | 1536 | No |

### Initialization

```swift
public init(
    apiKey: String,
    model: Model = .textEmbedding3Small,
    baseURL: String = "https://api.openai.com"
)
```

### Methods

```swift
// Standard
func embed(text: String) async throws -> [Float]
func embedBatch(texts: [String]) async throws -> [[Float]]

// With MRL (Matryoshka Representation Learning) dimension truncation
func embed(text: String, outputDimensionality: Int?) async throws -> [Float]
func embedBatch(texts: [String], outputDimensionality: Int?) async throws -> [[Float]]
```

### Example

```swift
let embeddings = OpenAIEmbeddingProvider(apiKey: "sk-...", model: .textEmbedding3Small)

let vector = try await embeddings.embed(text: "Swift concurrency")
// vector: [Float] with 1536 dimensions

// Reduced dimensions (faster, smaller)
let smallVector = try await embeddings.embed(text: "Swift concurrency", outputDimensionality: 256)
```

---

## GeminiEmbeddingProvider

```swift
public actor GeminiEmbeddingProvider: EmbeddingProvider
```

### Models

| Case | Raw Value | Type |
|------|-----------|------|
| `.embedding001` | `text-embedding-001` | Text only (default) |
| `.embedding2` | `gemini-embedding-exp-03-07` | Multimodal |

### Initialization

```swift
public init(
    apiKey: String,
    model: Model = .embedding001,
    baseURL: String = "https://generativelanguage.googleapis.com"
)
```

### Methods

```swift
// Standard
func embed(text: String) async throws -> [Float]
func embedBatch(texts: [String]) async throws -> [[Float]]

// With task type and dimensions
func embed(text: String, taskType: EmbeddingTaskType?, outputDimensionality: Int?) async throws -> [Float]
func embedBatch(texts: [String], taskType: EmbeddingTaskType?, outputDimensionality: Int?) async throws -> [[Float]]

// Multimodal (embedding2 model only)
func embedParts(_ parts: [Part], taskType: EmbeddingTaskType?, outputDimensionality: Int?) async throws -> [Float]
```

### Part (Multimodal)

```swift
public enum Part {
    case text(String)
    case inlineData(mimeType: String, base64Data: String)
}
```

### Example

```swift
let embeddings = GeminiEmbeddingProvider(apiKey: "...", model: .embedding001)

// Text embedding with task type
let vector = try await embeddings.embed(
    text: "What is quantum computing?",
    taskType: .retrievalQuery,
    outputDimensionality: 256
)

// Multimodal (embedding2 only)
let multimodalEmbeddings = GeminiEmbeddingProvider(apiKey: "...", model: .embedding2)
let vector = try await multimodalEmbeddings.embedParts([
    .text("A cat"),
    .inlineData(mimeType: "image/jpeg", base64Data: base64Image)
])
```

---

## VectorStore Protocol

```swift
public protocol VectorStore: Sendable {
    func search(query: String, topK: Int) async throws -> [SearchResult]
    func add(documents: [Document]) async throws
    func delete(ids: [String]) async throws
    func clear() async throws
    func count() async throws -> Int
}
```

### Document

```swift
public struct Document: Sendable {
    public let id: String
    public let content: String
    public let metadata: [String: String]

    public init(id: String = UUID().uuidString, content: String, metadata: [String: String] = [:])
}
```

### SearchResult

```swift
public struct SearchResult: Sendable {
    public let id: String
    public let content: String
    public let score: Double            // Cosine similarity (0.0 to 1.0)
    public let metadata: [String: String]
}
```

---

## InMemoryVectorStore

High-performance in-memory vector store with SIMD-optimized similarity computation.

```swift
public actor InMemoryVectorStore: VectorStore
```

### Initialization

```swift
public init(
    embeddingProvider: EmbeddingProvider,
    embeddingDimension: Int = 1536
)
```

### Features

- Query embedding cache (LRU, max 100 items)
- SIMD-optimized cosine similarity via Accelerate framework
- Parallel computation for large datasets (>1000 documents)

### Example

```swift
let embeddings = OpenAIEmbeddingProvider(apiKey: "sk-...")
let store = InMemoryVectorStore(embeddingProvider: embeddings)

// Add documents
let docs = [
    Document(content: "Swift is a programming language by Apple.", metadata: ["source": "wiki"]),
    Document(content: "Python is widely used in data science.", metadata: ["source": "wiki"]),
]
try await store.add(documents: docs)

// Search
let results = try await store.search(query: "Apple programming", topK: 3)
for result in results {
    print("\(result.score): \(result.content)")
}
```

---

## PineconeVectorStore

Cloud-hosted vector store using Pinecone.

```swift
public actor PineconeVectorStore: VectorStore
```

### Initialization

```swift
// Recommended (host-based)
public init(
    apiKey: String,
    host: String,                        // e.g., "index-xxx.svc.pinecone.io"
    embeddingProvider: EmbeddingProvider,
    dimension: Int = 1536
)
```

### Features

- Batch upserts in groups of 100
- Cloud-hosted persistent storage
- Namespace support

### VectorStoreError

```swift
public enum VectorStoreError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    case networkError(Error)
}
```

### Example

```swift
let embeddings = OpenAIEmbeddingProvider(apiKey: openaiKey)
let store = PineconeVectorStore(
    apiKey: pineconeKey,
    host: "my-index-abc123.svc.pinecone.io",
    embeddingProvider: embeddings,
    dimension: 1536
)

try await store.add(documents: docs)
let results = try await store.search(query: "machine learning", topK: 5)
```

---

## DocumentChunker

Utilities for splitting text into chunks for embedding.

```swift
public struct DocumentChunker {
    // Split by word count
    static func chunk(text: String, chunkSize: Int = 500, overlap: Int = 50) -> [String]

    // Split by character count
    static func chunkByCharacters(text: String, chunkSize: Int = 2000, overlap: Int = 200) -> [String]

    // Split by sentences
    static func chunkBySentences(text: String, targetChunkSize: Int = 500, overlap: Int = 1) -> [String]

    // Create Document objects with metadata
    static func createDocuments(
        from text: String,
        chunkSize: Int = 500,
        overlap: Int = 50,
        sourceMetadata: [String: String] = [:]
    ) -> [Document]
}
```

### Example

```swift
let longText = "..."  // Your document text

// Create documents with metadata
let documents = DocumentChunker.createDocuments(
    from: longText,
    chunkSize: 300,
    overlap: 50,
    sourceMetadata: [
        "source": "research_paper",
        "author": "Smith et al.",
        "date": "2026-01-15"
    ]
)

try await store.add(documents: documents)
```

---

## VectorSearchTool

A `Tool` that wraps a `VectorStore` for agent use.

```swift
public struct VectorSearchTool: Tool {
    public let name = "search_knowledge_base"
    public let description = "Search through the knowledge base for relevant information..."

    public init(vectorStore: VectorStore, defaultTopK: Int = 5)
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | Search query |
| `limit` | integer | No | Max results, 1-20 (default: 5) |

### Example

```swift
let searchTool = VectorSearchTool(vectorStore: store, defaultTopK: 5)

let agent = Agent(
    provider: provider,
    systemPrompt: "Answer questions using the knowledge base. Always cite sources.",
    tools: [searchTool],
    maxIterations: 5
)

let result = try await agent.run(task: "What do we know about Swift concurrency?")
```

---

## Complete RAG Pipeline

```swift
import SwiftAgent

// 1. Setup embeddings and store
let embeddings = OpenAIEmbeddingProvider(apiKey: openaiKey)
let store = InMemoryVectorStore(embeddingProvider: embeddings)

// 2. Ingest documents
let text = try String(contentsOfFile: "/path/to/document.txt", encoding: .utf8)
let documents = DocumentChunker.createDocuments(
    from: text,
    chunkSize: 500,
    overlap: 50,
    sourceMetadata: ["source": "document.txt"]
)
try await store.add(documents: documents)

// 3. Create agent with search tool
let agent = Agent(
    provider: ClaudeProvider(apiKey: claudeKey, model: .sonnet),
    systemPrompt: """
    You are a knowledgeable assistant. Use the search tool to find
    relevant information before answering. Always cite your sources.
    """,
    tools: [VectorSearchTool(vectorStore: store)],
    maxIterations: 5
)

// 4. Query
let result = try await agent.run(task: "Summarize the key points from the document")
print(result.output)
```
