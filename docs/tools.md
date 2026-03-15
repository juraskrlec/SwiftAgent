# Tools

Tools allow agents to interact with the outside world. SwiftAgent includes a `Tool` protocol and several built-in tools.

## Tool Protocol

```swift
public protocol Tool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: ToolParameters { get }
    func execute(arguments: [String: Any]) async throws -> String
}
```

### ToolParameters

```swift
public struct ToolParameters: Codable, Sendable {
    public let type: String                                 // Always "object"
    public let properties: [String: ParameterProperty]
    public let required: [String]

    public init(
        type: String = "object",
        properties: [String: ParameterProperty],
        required: [String] = []
    )
}
```

### ParameterProperty

```swift
public final class ParameterProperty: Codable, Sendable {
    public let type: String              // "string", "integer", "number", "boolean", "array"
    public let description: String
    public let enumValues: [String]?     // For enum-style parameters
    public let items: ParameterProperty? // For array items

    public init(
        type: String,
        description: String,
        enumValues: [String]? = nil,
        items: ParameterProperty? = nil
    )
}
```

### ToolError

```swift
public enum ToolError: Error, LocalizedError {
    case executionFailed(String)
    case invalidArguments(String)
    case toolNotFound(String)
    case permissionDenied(String)
}
```

---

## Creating Custom Tools

```swift
struct WeatherTool: Tool {
    let name = "get_weather"
    let description = "Get current weather for a city"
    let parameters = ToolParameters(
        properties: [
            "city": ParameterProperty(type: "string", description: "City name"),
            "unit": ParameterProperty(
                type: "string",
                description: "Temperature unit",
                enumValues: ["celsius", "fahrenheit"]
            )
        ],
        required: ["city"]
    )

    func execute(arguments: [String: Any]) async throws -> String {
        guard let city = arguments["city"] as? String else {
            throw ToolError.invalidArguments("Missing 'city' parameter")
        }
        let unit = arguments["unit"] as? String ?? "celsius"
        // Fetch weather...
        return "Weather in \(city): 22° \(unit == "celsius" ? "C" : "F"), sunny"
    }
}
```

### Array Parameters

```swift
let parameters = ToolParameters(
    properties: [
        "tags": ParameterProperty(
            type: "array",
            description: "List of tags",
            items: ParameterProperty(type: "string", description: "A tag")
        )
    ],
    required: ["tags"]
)
```

### Using Custom Tools

```swift
let agent = Agent(
    provider: provider,
    systemPrompt: "You have weather access.",
    tools: [WeatherTool()],
    maxIterations: 5
)

let result = try await agent.run(task: "What's the weather in Paris?")
```

---

## Built-in Tools

### WebSearchTool

DuckDuckGo web search.

```swift
WebSearchTool()
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | Yes | Search query |
| `max_results` | number | No | Max results (default: 5, max: 10) |

### CalculatorTool

Math expressions via `NSExpression`.

```swift
CalculatorTool()
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `expression` | string | Yes | Math expression (e.g., `sqrt(16)`, `2 + 2`) |

### DateTimeTool

Date/time operations.

```swift
DateTimeTool()
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `operation` | string | Yes | `now`, `add`, `subtract`, `format`, `parse`, `difference` |
| `timezone` | string | No | Timezone ID (e.g., `America/New_York`) |
| `date` | string | No | ISO 8601 date string |
| `amount` | number | No | Amount to add/subtract |
| `unit` | string | No | `seconds`, `minutes`, `hours`, `days`, `weeks`, `months`, `years` |
| `format` | string | No | Date format string (e.g., `yyyy-MM-dd`) |
| `date2` | string | No | Second date for difference |

### FileSystemTool

File read/write/list/delete with path security.

```swift
FileSystemTool()
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `operation` | string | Yes | `read`, `write`, `list`, `delete`, `exists`, `create_directory` |
| `path` | string | Yes | File or directory path |
| `content` | string | No | Content for `write` operation |

### HTTPRequestTool

HTTP requests to external APIs.

```swift
HTTPRequestTool()
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `method` | string | Yes | `GET`, `POST`, `PUT`, `DELETE`, `PATCH` |
| `url` | string | Yes | Target URL |
| `headers` | string | No | JSON string of headers |
| `body` | string | No | Request body |
| `timeout` | number | No | Timeout in seconds (default: 30) |

### JSONParserTool

JSON processing utilities.

```swift
JSONParserTool()
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `operation` | string | Yes | `parse`, `extract`, `validate`, `pretty_print` |
| `json` | string | Yes | JSON string |
| `key_path` | string | No | Dot-notation path for `extract` (e.g., `user.profile.name`) |

### CalendarTool

Local EventKit calendar management.

```swift
CalendarTool()
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | string | Yes | `create`, `read`, `search`, `update`, `delete`, `list_calendars` |
| `title` | string | No | Event title |
| `startDate` | string | No | ISO 8601 start date |
| `endDate` | string | No | ISO 8601 end date |
| `location` | string | No | Event location |
| `notes` | string | No | Event notes |
| `allDay` | boolean | No | All-day event flag |
| `url` | string | No | Associated URL |
| `eventId` | string | No | Event ID for update/delete |
| `query` | string | No | Search query |
| `timeframe` | string | No | `today`, `tomorrow`, `this_week`, `next_week`, `this_month`, `custom` |
| `customStartDate` | string | No | Custom range start |
| `customEndDate` | string | No | Custom range end |
| `calendars` | array | No | Calendar names filter |
| `limit` | integer | No | Max results (default: 10) |

### GoogleCalendarTool

Google Calendar API integration. Requires an OAuth2 access token.

```swift
GoogleCalendarTool(accessToken: "ya29....")
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | string | Yes | `create`, `list`, `get`, `update`, `delete`, `search`, `list_calendars` |
| `calendarId` | string | No | Calendar ID (default: `primary`) |
| `summary` | string | No | Event title |
| `description` | string | No | Event description |
| `location` | string | No | Event location |
| `startTime` | string | No | ISO 8601 start time |
| `endTime` | string | No | ISO 8601 end time |
| `timeZone` | string | No | Timezone (default: `UTC`) |
| `attendees` | array | No | Email addresses |
| `addMeetLink` | boolean | No | Add Google Meet link |
| `eventId` | string | No | Event ID for get/update/delete |
| `query` | string | No | Search query |
| `maxResults` | integer | No | Max results (default: 10) |
| `timeMin` | string | No | Lower time bound (ISO 8601) |
| `timeMax` | string | No | Upper time bound (ISO 8601) |

### ImageAnalysisTool

Delegates image analysis to the LLM's vision capabilities.

```swift
ImageAnalysisTool()
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `analysis_type` | string | Yes | `describe`, `ocr`, `objects`, `faces`, `colors` |

### OCRTool

Delegates OCR to the LLM's vision capabilities.

```swift
OCRTool()
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `format` | string | No | `plain`, `structured`, `markdown` |

---

## Tool Usage in Agents

```swift
let agent = Agent(
    provider: provider,
    systemPrompt: "You are a helpful assistant with many tools.",
    tools: [
        WebSearchTool(),
        CalculatorTool(),
        DateTimeTool(),
        FileSystemTool(),
        HTTPRequestTool(),
        JSONParserTool(),
        GoogleCalendarTool(accessToken: token)
    ],
    maxIterations: 15
)

let result = try await agent.run(task: "Search for today's weather and save it to a file")
```
