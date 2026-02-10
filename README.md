# SwiftAgent

A native Swift framework for building autonomous AI agents with support for multiple LLM providers, tool execution, and multi-agent workflows.

## Features

- **Multiple LLM Providers** - Claude (Anthropic), OpenAI (ChatGPT), and Apple Intelligence (on-device)
- **Tool System** - Built-in tools and easy custom tool creation
- **Autonomous Agents** - Agents that can reason and use tools to accomplish tasks
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
    model: .gpt5Mini 
)

let agent = Agent(
    name: "Assistant",
    provider: provider,
    tools: [DateTimeTool(), JSONParserTool()]
)

let result = try await agent.run(task: "Parse this JSON and tell me the name...")
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

### Conditional Routing

```swift
let graph = AgentGraph()

await graph.addNode("classifier", agent: classifierAgent)
await graph.addNode("simple_handler", agent: simpleAgent)
await graph.addNode("complex_handler", agent: complexAgent)

await graph.addEdge(from: .START, to: "classifier")

// Route based on classifier's output
await graph.addConditionalEdge(from: "classifier") { state in
    let lastMessage = state.messages.last?.content ?? ""
    return lastMessage.contains("complex") ? "complex_handler" : "simple_handler"
}

await graph.addEdge(from: "simple_handler", to: .END)
await graph.addEdge(from: "complex_handler", to: .END)
```

### Parallel Execution

```swift
let graph = AgentGraph()

// Create specialized agents
await graph.addNode("tech_research", agent: techAgent)
await graph.addNode("market_research", agent: marketAgent)
await graph.addNode("synthesize", agent: synthAgent)

// Run research in parallel
await graph.addParallelEdges(from: .START, to: ["tech_research", "market_research"])

// Combine results
await graph.addEdge(from: ["tech_research", "market_research"], to: "synthesize")
await graph.addEdge(from: "synthesize", to: .END)

let result = try await graph.invoke(input: initialState)
```

## Provider Comparison

| Provider | API Key | Cost | Speed | Privacy | Tools | Streaming |
|----------|---------|------|-------|---------|-------|-----------|
| **Claude** | ✅ Required | 💰 Paid | ⚡ Fast | ☁️ Cloud | ✅ Yes | ✅ Yes |
| **OpenAI** | ✅ Required | 💰 Paid | ⚡ Fast | ☁️ Cloud | ✅ Yes | ✅ Yes |
| **Apple Intelligence** | ❌ Not needed | 🆓 Free | 🚀 Very Fast | 🔒 On-device | ✅ Yes | ✅ Yes |

### When to use each:

- **Claude**: Most capable reasoning, complex tasks, long context
- **OpenAI**: Broad capabilities, good documentation, wide adoption
- **Apple Intelligence**: Privacy-focused, offline capability, no API costs

## Configuration

### Environment Variables

For testing, set API keys as environment variables:

```bash
export ANTHROPIC_API_KEY="your-key-here"
export OPENAI_API_KEY="your-key-here"
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

### Agent Configuration

```swift
let agent = Agent(
    name: "CustomAgent",
    provider: provider,
    systemPrompt: "Custom instructions...",
    tools: [tool1, tool2],
    maxIterations: 10  // Maximum tool-calling loops
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
swift test
```

Run specific tests:

```bash
swift test --filter AppleIntelligenceTests
swift test --filter ClaudeProviderTests
swift test --filter OpenAIProviderTests
```

## Requirements

- iOS 16.0+ / macOS 13.0+ / watchOS 9.0+ / tvOS 16.0+
- Swift 6.0+
- Xcode 26.0+

**For Apple Intelligence:**
- iOS 26+ / macOS 26.0+
- Apple Silicon Mac (M1+) or iPhone 15+ Pro/Max
- FoundationModels framework

## API Keys

### Claude (Anthropic)

Get your API key from [platform.claude.com](https://platform.claude.com/settings/keys)

```swift
let provider = ClaudeProvider(apiKey: "sk-ant-...")
```

### OpenAI

Get your API key from [platform.openai.com](https://platform.openai.com/api-keys)

```swift
let provider = OpenAIProvider(apiKey: "sk-...")
```

### Apple Intelligence

No API key needed! Just requires:
1. Compatible device (iPhone 15 Pro+, M1+ Mac)
2. iOS 26.0+ or macOS 26.0+
3. Apple Intelligence enabled in Settings

## Examples

### Chat Application

```swift
let agent = Agent(
    name: "ChatBot",
    provider: ClaudeProvider(apiKey: apiKey, model: .sonnet),
    systemPrompt: "You are a friendly chatbot."
)

// Maintain conversation history
var messages: [Message] = []

func chat(userMessage: String) async throws -> String {
    messages.append(.user(userMessage))
    
    let result = try await agent.run(task: userMessage)
    messages.append(.assistant(result.output))
    
    return result.output
}
```

### Research Assistant

```swift
let researcher = Agent(
    name: "Researcher",
    provider: provider,
    systemPrompt: "Research topics thoroughly and cite sources.",
    tools: [WebSearchTool(), JSONParserTool()]
)

let result = try await researcher.run(
    task: "Research the latest developments in quantum computing"
)
```

### Data Analysis Pipeline

```swift
let analyzer = Agent(
    name: "Analyzer",
    provider: provider,
    systemPrompt: "Analyze data and provide insights.",
    tools: [JSONParserTool(), HTTPRequestTool()]
)

let reporter = Agent(
    name: "Reporter",
    provider: provider,
    systemPrompt: "Create clear reports from analysis."
)

let graph = AgentGraph()
await graph.addNode("analyze", agent: analyzer)
await graph.addNode("report", agent: reporter)
await graph.addEdge(from: .START, to: "analyze")
await graph.addEdge(from: "analyze", to: "report")
await graph.addEdge(from: "report", to: .END)

var state = GraphState()
state.addMessage(.user("Analyze sales data from Q1-Q4"))

let result = try await graph.invoke(input: state)
```

## Best Practices

### 1. Choose the Right Provider

- **Complex reasoning**: Claude Opus or Sonnet
- **Speed and cost**: Claude Haiku, OpenAI GPT-5-mini
- **Privacy**: Apple Intelligence
- **Multimodal**: OpenAI GPT-5

### 2. System Prompts

Be specific and clear:

```swift
// Vague
systemPrompt: "You are helpful."

// Specific
systemPrompt: """
You are a customer support agent for an e-commerce platform.
- Be friendly and professional
- Prioritize customer satisfaction
- Use tools to look up order information
- Always verify customer identity before sharing sensitive data
"""
```

### 3. Tool Design

Keep tools focused and single-purpose:

```swift
// Too broad
struct AllInOneTool: Tool { ... }

// Focused
struct GetOrderTool: Tool { ... }
struct CancelOrderTool: Tool { ... }
struct RefundOrderTool: Tool { ... }
```

### 4. Error Handling

Always handle agent failures gracefully:

```swift
do {
    let result = try await agent.run(task: task)
    return result.output
} catch AgentError.maxIterationsReached {
    return "Task too complex, please simplify"
} catch LLMError.rateLimitExceeded {
    // Retry with backoff
    try await Task.sleep(for: .seconds(60))
    return try await agent.run(task: task).output
} catch {
    logger.error("Agent failed: \(error)")
    return "I encountered an error. Please try again."
}
```

### 5. Context Management

For long conversations, manage context size:

```swift
// Keep only recent messages
if messages.count > 20 {
    let systemMessages = messages.filter { $0.role == .system }
    let recentMessages = messages.suffix(15)
    messages = systemMessages + recentMessages
}
```

## Troubleshooting

### Apple Intelligence Not Available

```swift
let provider = try await AppleIntelligenceProvider()
// Error: Foundation Models not available

// Solution:
// 1. Check device compatibility (iPhone 15 Pro+, M1+ Mac)
// 2. Update to iOS 26.0+ or macOS 26.0+
// 3. Enable Apple Intelligence in Settings
```

### Rate Limits

```swift
// Implement exponential backoff
func runWithRetry(task: String, maxRetries: Int = 3) async throws -> String {
    var attempt = 0
    var delay: TimeInterval = 1
    
    while attempt < maxRetries {
        do {
            let result = try await agent.run(task: task)
            return result.output
        } catch LLMError.rateLimitExceeded {
            attempt += 1
            if attempt >= maxRetries { throw LLMError.rateLimitExceeded }
            try await Task.sleep(for: .seconds(delay))
            delay *= 2
        }
    }
    
    throw LLMError.rateLimitExceeded
}
```

### Context Window Exceeded

```swift
// For Apple Intelligence (4096 token limit)
let provider = try await AppleIntelligenceProvider(
    maxContextTokens: 3000  // Leave buffer for response
)

// Trim messages if needed
func trimMessages(_ messages: [Message]) -> [Message] {
    // Keep system message + recent messages
    let system = messages.first { $0.role == .system }
    let recent = messages.suffix(10)
    return [system].compactMap { $0 } + recent
}
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

### Development Setup

```bash
git clone https://github.com/juraskrlec/SwiftAgent.git
cd SwiftAgent
swift build
swift test
```

## Roadmap

- [ ] Additional providers (Gemini, Llama, etc.)
- [ ] Memory system for persistent conversation history
- [ ] Agent templates for common use cases
- [ ] RAG (Retrieval Augmented Generation) support
- [ ] Vision/multimodal tool support
- [ ] Agent observability and debugging tools
- [ ] Async tool execution
- [ ] Human-in-the-loop workflows

## License

MIT License - see [LICENSE](LICENSE) file for details

## Acknowledgments

- Inspired by [LangChain](https://github.com/langchain-ai/langchain) and [LangGraph](https://github.com/langchain-ai/langgraph)
- Built with ❤️ using Swift

## Support

- 📖 [Documentation](https://github.com/juraskrlec/SwiftAgent/wiki)
- 🐛 [Issue Tracker](https://github.com/juraskrlec/SwiftAgent/issues)
- 💬 [Discussions](https://github.com/juraskrlec/SwiftAgent/discussions)
- 📧 Email: jskrlec4@gmail.com

---

**SwiftAgent** - Build powerful AI agents natively in Swift 🚀

Made with ❤️ by the Jura Skrlec
