# Agents

The `Agent` actor is the core component of SwiftAgent. It orchestrates LLM calls, tool execution, and iterative reasoning.

## Agent

```swift
public actor Agent {
    public let name: String
    public let provider: LLMProvider
    public let systemPrompt: String?
    public let tools: [String: Tool]
    public let maxIterations: Int
    public let options: GenerationOptions
    public var isRunning: Bool
}
```

### Initialization

#### Direct system prompt

```swift
public init(
    name: String = "Agent",
    provider: LLMProvider,
    systemPrompt: String? = nil,
    tools: [Tool] = [],
    maxIterations: Int = 10,
    options: GenerationOptions = .default
)
```

#### From prompt file

```swift
public init(
    name: String = "Agent",
    provider: LLMProvider,
    promptFile: String,                          // Absolute file path
    promptVariables: [String: String] = [:],     // {{variable}} replacement
    tools: [Tool] = [],
    maxIterations: Int = 10,
    options: GenerationOptions = .default
) throws
```

#### From bundle resource

```swift
public init(
    name: String = "Agent",
    provider: LLMProvider,
    promptResource: String,                      // Resource name (without extension)
    bundle: Bundle = .main,
    promptVariables: [String: String] = [:],
    tools: [Tool] = [],
    maxIterations: Int = 10,
    options: GenerationOptions = .default
) throws
```

### Execution Methods

#### `run(task:images:)` — Full agentic loop

Runs the agent until it completes or hits `maxIterations`. The agent will call tools and iterate as needed.

```swift
public func run(task: String, images: [Message.ImageContent] = []) async throws -> AgentResult
```

```swift
let result = try await agent.run(task: "Find the weather in Tokyo")
print(result.output)        // Final text response
print(result.totalTokens)   // Total tokens used
print(result.success)       // true if completed without error
print(result.state)         // AgentState with full message history
```

#### `stream(task:images:)` — Real-time event streaming

Returns an `AsyncThrowingStream<AgentEvent, Error>` for real-time processing.

```swift
public func stream(task: String, images: [Message.ImageContent] = []) -> AsyncThrowingStream<AgentEvent, Error>
```

```swift
let stream = await agent.stream(task: "Analyze this codebase")
for try await event in stream {
    switch event {
    case .thinking(let text):
        // Partial text being generated
        print(text, terminator: "")
    case .toolCall(let call):
        // Agent is calling a tool
        print("Tool: \(call.name)(\(call.arguments))")
    case .toolResult(let name, let result):
        // Tool returned a result
        print("\(name) -> \(result)")
    case .response(let text):
        // Final response text chunk
        print(text, terminator: "")
    case .completed(let result):
        // Agent finished
        print("\nDone: \(result.output)")
    case .error(let error):
        // Error occurred
        print("Error: \(error)")
    }
}
```

#### `invoke(input:images:)` — Single turn (no tool loop)

Makes a single LLM call without iterating on tool calls.

```swift
public func invoke(input: String, images: [Message.ImageContent] = []) async throws -> LLMResponse
```

```swift
let response = try await agent.invoke(input: "What is 2+2?")
print(response.content)
```

#### `cancel()`

Cancels a running agent task.

```swift
public func cancel()
```

### Vision / Image Support

Pass images with any execution method:

```swift
let imageData = try Data(contentsOf: URL(fileURLWithPath: "/path/to/image.jpg"))
let image = Message.ImageContent(data: imageData, mimeType: "image/jpeg", detail: .high)

// With run
let result = try await agent.run(task: "Describe this image", images: [image])

// With stream
let stream = await agent.stream(task: "What objects are in this photo?", images: [image])
```

### AgentError

```swift
public enum AgentError: Error, LocalizedError {
    case maxIterationsReached(Int)
    case configurationError(String)
    case alreadyRunning
}
```

---

## AgentResult

```swift
public struct AgentResult: Sendable {
    public let output: String           // Final text output
    public let state: AgentState        // Full execution state
    public let totalTokens: Int         // Total tokens consumed
    public let success: Bool            // true if no errors
    public let error: Error?            // nil if successful
}
```

---

## AgentEvent

Events emitted during `stream()`:

```swift
public enum AgentEvent: Sendable {
    case thinking(String)                       // Partial generation text
    case toolCall(ToolCall)                     // Tool being invoked
    case toolResult(String, String)             // (toolName, result)
    case response(String)                       // Final response text chunk
    case completed(AgentResult)                 // Agent finished
    case error(Error)                           // Error occurred
}
```

---

## AgentState

Internal execution state, accessible via `AgentResult.state`:

```swift
public struct AgentState: Codable, Sendable {
    public var messages: [Message]              // Full conversation history
    public var iterations: Int                  // Number of iterations completed
    public var metadata: [String: String]       // Arbitrary metadata

    public mutating func addMessage(_ message: Message)
    public mutating func addMessages(_ newMessages: [Message])
    public mutating func incrementIteration()
}
```

---

## AgentPrompt

Utility for loading prompts from files:

```swift
public struct AgentPrompt {
    // Load from file path
    public static func load(fromFile path: String) throws -> String

    // Load from bundle resource
    public static func load(fromBundle filename: String, bundle: Bundle = .main) throws -> String

    // Load multiple prompt files, joined by separator
    public static func loadMultiple(fromFiles paths: [String], separator: String = "\n\n---\n\n") throws -> String

    // Load with {{variable}} replacement
    public static func load(fromFile path: String, variables: [String: String]) throws -> String

    // Load with YAML frontmatter parsing
    public static func loadWithFrontmatter(fromFile path: String) throws -> (metadata: [String: String], content: String)
}
```

### Prompt Variables

Prompt files can contain `{{variableName}}` placeholders:

```markdown
# System Prompt
You are {{name}}, a {{role}} assistant.
Your expertise is in {{domain}}.
```

```swift
let agent = try Agent(
    provider: provider,
    promptFile: "/prompts/system.md",
    promptVariables: [
        "name": "Atlas",
        "role": "research",
        "domain": "computer science"
    ]
)
```

---

## Message

The `Message` struct represents a conversation message:

```swift
public struct Message: Codable, Sendable, Equatable {
    public let id: String
    public let role: Role                       // .system, .user, .assistant, .tool
    public let content: [ContentPart]           // .text(String), .image(ImageContent)
    public let toolCallId: String?              // For tool result messages
    public let toolCalls: [ToolCall]?           // For assistant messages with tool calls
    public let timestamp: Date
    public let thoughtSignature: String?        // Gemini thinking signature
}
```

### Convenience Constructors

```swift
Message.system("You are a helpful assistant.")
Message.user("Hello!")
Message.user("Describe this", images: [imageContent])
Message.user("What's this?", image: singleImage)
Message.assistant("I can help with that.", toolCalls: nil)
Message.tool("Result text", toolCallId: "call_123")
```

### ContentPart

```swift
public enum ContentPart: Sendable, Codable, Equatable {
    case text(String)
    case image(ImageContent)
}
```

### ImageContent

```swift
public struct ImageContent: Sendable, Codable, Equatable {
    public let data: Data
    public let mimeType: String                 // "image/jpeg", "image/png", etc.
    public let detail: ImageDetail?             // .low, .high, .auto

    public init(data: Data, mimeType: String = "image/jpeg", detail: ImageDetail? = nil)
}
```

### ToolCall

```swift
public struct ToolCall: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let arguments: [String: AnyCodable]
    public let thoughtSignature: String?
}
```

### AnyCodable

Type-erased Codable value:

```swift
public enum AnyCodable: Codable, Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])
    case null

    public init(_ value: Any?)

    // Value extraction
    public var value: Any
    public var boolValue: Bool?
    public var intValue: Int?
    public var doubleValue: Double?
    public var stringValue: String?
    public var arrayValue: [AnyCodable]?
    public var dictionaryValue: [String: AnyCodable]?
}
```

---

## Complete Example

```swift
import SwiftAgent

let provider = ClaudeProvider(apiKey: "sk-ant-...", model: .sonnet)

let agent = Agent(
    name: "ResearchAgent",
    provider: provider,
    systemPrompt: """
    You are a research assistant. Use tools to find information,
    then synthesize it into clear, cited responses.
    """,
    tools: [WebSearchTool(), CalculatorTool()],
    maxIterations: 15,
    options: GenerationOptions(maxTokens: 4096, temperature: 0.7)
)

// Synchronous execution
let result = try await agent.run(task: "What is the population of Tokyo?")
print("Answer: \(result.output)")
print("Tokens: \(result.totalTokens)")
print("Iterations: \(result.state.iterations)")

// Streaming execution
let stream = await agent.stream(task: "Compare Python and Swift performance")
for try await event in stream {
    if case .response(let text) = event {
        print(text, terminator: "")
    }
}
```
