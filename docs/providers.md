# LLM Providers

SwiftAgent supports multiple LLM providers through a unified `LLMProvider` protocol. All providers are actors conforming to `Sendable`.

## LLMProvider Protocol

```swift
public protocol LLMProvider: Sendable {
    func generate(messages: [Message], tools: [Tool]?, options: GenerationOptions) async throws -> LLMResponse
    func stream(messages: [Message], tools: [Tool]?, options: GenerationOptions) async throws -> AsyncThrowingStream<LLMChunk, Error>
}
```

## GenerationOptions

```swift
public struct GenerationOptions: Sendable {
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?
    public let stopSequences: [String]?
    public let thinkingLevel: ThinkingLevel?    // .minimal, .low, .medium, .high, .auto

    public init(
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        stopSequences: [String]? = nil,
        thinkingLevel: ThinkingLevel? = nil
    )

    public static let `default` = GenerationOptions()
}
```

## Response Types

### LLMResponse

```swift
public struct LLMResponse: Sendable {
    public let id: String
    public let content: String
    public let toolCalls: [ToolCall]?
    public let stopReason: StopReason          // .endTurn, .maxTokens, .stopSequence, .toolUse
    public let usage: TokenUsage?
    public let thoughtSignature: String?       // Gemini thinking signature
}
```

### LLMChunk (Streaming)

```swift
public struct LLMChunk: Sendable {
    public enum ChunkType: Sendable {
        case content(String)
        case toolCall(ToolCall)
        case done(StopReason)
    }
    public let type: ChunkType
    public let usage: TokenUsage?
}
```

### TokenUsage

```swift
public struct TokenUsage: Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public var totalTokens: Int { inputTokens + outputTokens }
}
```

## LLMError

```swift
public enum LLMError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    case networkError(Error)
    case rateLimitExceeded
    case authenticationFailed
    case invalidAPIKey
}
```

---

## ClaudeProvider (Anthropic)

```swift
public actor ClaudeProvider: LLMProvider
```

### Models

| Case | Raw Value | Alias |
|------|-----------|-------|
| `.claudeOpus46` | `claude-opus-4-6` | `.opus` |
| `.claudeOpus45` | `claude-opus-4-5-20251101` | |
| `.claudeOpus41` | `claude-opus-4-1-20250805` | |
| `.claudeOpus4` | `claude-opus-4-20250514` | |
| `.claudeSonnet45` | `claude-sonnet-4-5-20250929` | `.sonnet` |
| `.claudeSonnet4` | `claude-sonnet-4-20250514` | |
| `.claudeHaiku45` | `claude-haiku-4-5-20251001` | `.haiku` |
| `.claudeHaiku3` | `claude-3-haiku-20240307` | |

### Initialization

```swift
public init(
    apiKey: String,
    model: Model = .sonnet,
    defaultMaxTokens: Int = 4096
)
```

### Features

- Multi-part content (text + images)
- Tool use with Anthropic's block-based format
- Image content with base64 encoding
- SSE streaming with content block events

### Example

```swift
let claude = ClaudeProvider(apiKey: "sk-ant-...", model: .opus)

let response = try await claude.generate(
    messages: [.system("You are helpful."), .user("Hello!")],
    tools: nil,
    options: GenerationOptions(maxTokens: 1024, temperature: 0.7)
)
print(response.content)
```

---

## OpenAIProvider

```swift
public actor OpenAIProvider: LLMProvider, Sendable
```

### Models

| Case | Raw Value | Alias |
|------|-----------|-------|
| `.gpt54` | `gpt-5.4` | `.defaultChatGPTModel` |
| `.gpt54Pro` | `gpt-5.4-pro` | |
| `.gpt52Pro` | `gpt-5.2-pro` | |
| `.gpt52` | `gpt-5.2` | |
| `.gpt5Mini` | `gpt-5-mini` | |
| `.gpt5Nano` | `gpt-5-nano` | |
| `.gpt5` | `gpt-5` | |

### Initialization

```swift
public init(apiKey: String, model: Model = .defaultChatGPTModel)
```

### Features

- Direct HTTP API calls (no SDK dependency)
- Multimodal content with image data URLs
- Tool call accumulation during streaming
- Configurable image detail levels (high/low)

### Example

```swift
let openai = OpenAIProvider(apiKey: "sk-...", model: .gpt54)

let response = try await openai.generate(
    messages: [.user("Explain quantum entanglement")],
    tools: nil,
    options: .default
)
```

---

## GeminiProvider (Google)

```swift
public actor GeminiProvider: LLMProvider
```

### Models

| Case | Raw Value | Alias |
|------|-----------|-------|
| `.gemini31Pro` | `gemini-3.1-pro-preview` | `.defaultGeminiModel` |
| `.gemini31FlashLite` | `gemini-3.1-flash-lite-preview` | |
| `.gemini31FlashImage` | `gemini-3.1-flash-image-preview` | |

### Initialization

```swift
public init(
    apiKey: String,
    model: Model = .defaultGeminiModel,
    defaultMaxTokens: Int = 8192,
    thinkingLevel: ThinkingLevel? = nil     // Extended thinking support
)
```

### ThinkingLevel

```swift
public enum ThinkingLevel: String, Sendable {
    case minimal, low, medium, high, auto
}
```

Priority: `options.thinkingLevel` > provider default > `.auto` for Gemini 3.1 Pro/FlashLite.

### Features

- Extended thinking with `ThinkingLevel`
- `thoughtSignature` in responses and tool calls
- Function call (tool) support with Google's format
- Same-role message consolidation

### Example

```swift
let gemini = GeminiProvider(apiKey: "...", model: .gemini31Pro, thinkingLevel: .high)

let response = try await gemini.generate(
    messages: [.user("Solve this step by step: what is 23^4?")],
    tools: nil,
    options: GenerationOptions(thinkingLevel: .high)
)
```

---

## AppleIntelligenceProvider (On-Device)

```swift
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public actor AppleIntelligenceProvider: LLMProvider
```

### Initialization

```swift
public init(
    instructions: String? = nil,
    maxContextTokens: Int = 2000        // Max 4096 total
) async throws
```

### Features

- Runs entirely on-device (no network)
- Uses Apple's FoundationModels framework
- Context window management with automatic message trimming (system message always preserved)
- Session prewarming for performance
- Tool wrappers for built-in tools via `FoundationModelToolFactory`
- Falls back with `LLMError` on unsupported platforms

### Supported Tools via FoundationModels Wrappers

The following SwiftAgent tools have automatic FoundationModels wrappers:
- `DateTimeTool` -> `DateTimeToolWrapper`
- `FileSystemTool` -> `FileSystemToolWrapper`
- `HTTPRequestTool` -> `HTTPRequestToolWrapper`
- `JSONParserTool` -> `JSONParserToolWrapper`
- `WebSearchTool` -> `WebSearchToolWrapper`
- `GoogleCalendarTool` -> `GoogleCalendarToolWrapper`

### Example

```swift
let apple = try await AppleIntelligenceProvider(
    instructions: "You are a helpful coding assistant.",
    maxContextTokens: 2000
)

let agent = Agent(
    provider: apple,
    systemPrompt: "Help users with Swift code.",
    tools: [DateTimeTool(), WebSearchTool()]
)

let result = try await agent.run(task: "What time is it?")
```

---

## MLXProvider (Local LLM on Apple Silicon)

```swift
@available(macOS 14.0, *)
public actor MLXProvider: LLMProvider
```

**macOS only.** Models are auto-downloaded from HuggingFace Hub on first use and cached in `~/.cache/huggingface/`.

### Models

| Case | Raw Value |
|------|-----------|
| `.llama3_2_3B` | `mlx-community/Llama-3.2-3B-Instruct-4bit` |
| `.llama3_2_1B` | `mlx-community/Llama-3.2-1B-Instruct-4bit` |
| `.llama3_1_8B` | `mlx-community/Meta-Llama-3.1-8B-Instruct-4bit` |
| `.qwen3_8B` | `mlx-community/Qwen3-8B-4bit` |
| `.qwen3_4B` | `mlx-community/Qwen3-4B-4bit` |
| `.qwen2_5_7B` | `mlx-community/Qwen2.5-7B-Instruct-4bit` |
| `.qwen2_5_1_5B` | `mlx-community/Qwen2.5-1.5B-Instruct-4bit` |
| `.gemma3_4B` | `mlx-community/gemma-3-4b-it-4bit` |
| `.gemma2_9B` | `mlx-community/gemma-2-9b-it-4bit` |
| `.gemma2_2B` | `mlx-community/gemma-2-2b-it-4bit` |
| `.phi4Mini` | `mlx-community/phi-4-mini-instruct-4bit` |
| `.mistral7B` | `mlx-community/Mistral-7B-Instruct-v0.3-4bit` |
| `.smolLM2_1_7B` | `mlx-community/SmolLM2-1.7B-Instruct-4bit` |
| `.smolLM2_360M` | `mlx-community/SmolLM2-360M-Instruct-4bit` |
| `.deepSeekR1_8B` | `mlx-community/DeepSeek-R1-Distill-Llama-8B-4bit` |

Default: `.llama3_2_3B`

### MLXGenerateParameters

```swift
public struct MLXGenerateParameters: Sendable {
    public let temperature: Float           // default: 0.6
    public let topP: Float                  // default: 0.9
    public let repetitionPenalty: Float?     // default: 1.1
    public let repetitionContextSize: Int    // default: 20
}
```

### Initialization

```swift
// Predefined model
public init(
    model: Model = .default,
    parameters: MLXGenerateParameters = .default,
    maxTokens: Int = 2048,
    progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
) async throws

// ModelConfiguration (from MLXLMCommon)
public init(
    configuration: ModelConfiguration,
    parameters: MLXGenerateParameters = .default,
    maxTokens: Int = 2048,
    progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
) async throws

// Custom HuggingFace model ID
public init(
    modelId: String,
    parameters: MLXGenerateParameters = .default,
    maxTokens: Int = 2048,
    progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
) async throws

// Local directory (no download)
public init(
    modelDirectory: URL,
    parameters: MLXGenerateParameters = .default,
    maxTokens: Int = 2048
) async throws
```

### Example

```swift
let mlx = try await MLXProvider(model: .llama3_2_3B) { progress in
    print("Download: \(Int(progress.fractionCompleted * 100))%")
}

let agent = Agent(
    provider: mlx,
    systemPrompt: "You are a helpful local assistant.",
    tools: []
)

let result = try await agent.run(task: "Explain Swift actors")
print(result.output)
```

---

## Switching Providers

All providers share the same `LLMProvider` protocol, so you can swap them freely:

```swift
func createAgent(provider: LLMProvider) -> Agent {
    Agent(
        provider: provider,
        systemPrompt: "You are helpful.",
        tools: [WebSearchTool()]
    )
}

// Use any provider
let agent1 = createAgent(provider: ClaudeProvider(apiKey: claudeKey))
let agent2 = createAgent(provider: OpenAIProvider(apiKey: openaiKey))
let agent3 = createAgent(provider: try await MLXProvider(model: .llama3_2_3B))
```
