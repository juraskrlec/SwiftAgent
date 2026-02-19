//
//  FoundationModelsToolWrappers.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 17.02.2026..
//

//
//  FoundationModelToolWrappers.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 16.02.2026..
//


import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct DateTimeToolWrapper: FMTool {
    let name = "datetime_tool"
    let description = """
    Perform date and time operations: get current time, add/subtract time, 
    format dates, parse date strings, and calculate differences between dates.
    """
    
    @Generable
    struct Arguments {
        @Guide(description: """
        Operation to perform:
        - 'now': Get current date and time
        - 'add': Add time to a date
        - 'subtract': Subtract time from a date
        - 'format': Format a date into a readable string
        - 'parse': Parse a date string into ISO 8601
        - 'difference': Calculate difference between two dates
        """)
        let operation: String
        
        @Guide(description: """
        REQUIRED for add/subtract operations. 
        Time unit from the user's query. Extract the unit word directly:
        - If user says "30 DAYS from now" → use "days"
        - If user says "2 WEEKS ago" → use "weeks"
        - If user says "3 MONTHS later" → use "months"
        Allowed values: 'days', 'weeks', 'months', 'years', 'hours', 'minutes', 'seconds'
        
        Default: "days"
        """)
        let unit: String?
        
        @Guide(description: "Amount of time units to add or subtract (required for add/subtract)")
        let amount: Int?
        
        @Guide(description: "ISO 8601 date string for operations that need a base date. Optional for 'add'/'subtract' (defaults to now).")
        let date: String?
        
        @Guide(description: "Output format string e.g. 'MMMM d, yyyy' or 'dd/MM/yyyy' (for format operation)")
        let format: String?
        
        @Guide(description: "Timezone identifier e.g. 'America/New_York', 'Europe/Zagreb' (optional, defaults to UTC)")
        let timeZone: String?
    }
    
    func call(arguments: Arguments) async throws -> String {
        let tool = DateTimeTool()
        
        var args: [String: Any] = ["operation": arguments.operation]
        
        if let amount = arguments.amount   { args["amount"] = amount }
        if let date = arguments.date       { args["date"] = date }
        if let format = arguments.format   { args["format"] = format }
        if let timeZone = arguments.timeZone { args["timezone"] = timeZone }
        
        if arguments.operation == "add" || arguments.operation == "subtract" {
            args["unit"] = arguments.unit ?? "days" 
        } else if let unit = arguments.unit {
            args["unit"] = unit
        }
        
        return try await tool.execute(arguments: args)
    }
}

// MARK: - FileSystemTool Wrapper

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct FileSystemToolWrapper: FMTool {
    let name = "file_system"
    let description = "Read, write, list, delete files and directories on the file system"
    
    private let allowedPaths: [String]
    private let maxResponseContext: Int
    
    /// Maximum context window for Apple Intelligence is 4096
    /// Set maxResponseContext when default for context prompt is 2000
    ///
    /// See: https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window
    init(allowedPaths: [String] = [NSTemporaryDirectory()], maxResponseContext: Int = 500) {
        self.allowedPaths = allowedPaths
        self.maxResponseContext = maxResponseContext
    }
    
    @Generable
    struct Arguments {
        @Guide(description: "Action to perform: 'read', 'write', 'list', 'delete', 'exists', 'create_directory'")
        let operation: String
        
        @Guide(description: "File or directory path to operate on")
        let path: String
        
        @Guide(description: "Content to write to the file (required for write action)")
        let content: String?
        
        @Guide(description: "Whether to search recursively (for list action, defaults to false)")
        let recursive: Bool?
    }
    
    func call(arguments: Arguments) async throws -> String {
        let tool = FileSystemTool(allowedPaths: allowedPaths)
        
        var args: [String: Any] = [
            "operation": arguments.operation,
            "path": arguments.path
        ]
        
        if let content = arguments.content { args["content"] = content }
        
        return truncateOutput(try await tool.execute(arguments: args), maxTokens: maxResponseContext) // The maximum context vwindow
    }
    
    private func truncateOutput(_ text: String, maxTokens: Int) -> String {
        let maxChars = maxTokens * 4
        
        if text.count <= maxChars {
            return text
        }
        
        let lines = text.components(separatedBy: .newlines)
        var output = ""
        var count = 0
        
        for line in lines {
            if (output.count + line.count) > maxChars { break }
            output += line + "\n"
            count += 1
        }
        
        return """
        \(output.trimmingCharacters(in: .whitespacesAndNewlines))
        
        (Showing \(count) files - truncated for context limit)
        """
    }
}

// MARK: - HTTPRequestTool Wrapper

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct HTTPRequestToolWrapper: FMTool {
    let name = "http_request"
    let description = "Make HTTP requests to APIs and web services"
    
    @Generable
    struct Arguments {
        @Guide(description: "Full URL to send the request to")
        let url: String
        
        @Guide(description: "HTTP method: 'GET', 'POST', 'PUT', 'DELETE', 'PATCH'")
        let method: String
        
        @Guide(description: "Request body as JSON string (for POST, PUT, PATCH)")
        let body: String?
        
        @Guide(description: "Request headers as JSON object string e.g. '{\"Content-Type\": \"application/json\"}'")
        let headers: String?
        
        @Guide(description: "Timeout in seconds (default: 30)")
        let timeout: Int?
    }
    
    func call(arguments: Arguments) async throws -> String {
        let tool = HTTPRequestTool()
        
        var args: [String: Any] = [
            "url": arguments.url,
            "method": arguments.method
        ]
        
        if let body = arguments.body { args["body"] = body }
        if let headers = arguments.headers { args["headers"] = headers }
        if let timeout = arguments.timeout { args["timeout"] = timeout }
        
        return try await tool.execute(arguments: args)
    }
}

// MARK: - JSONParserTool Wrapper

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct JSONParserToolWrapper: FMTool {
    let name = "json_parser"
    let description = "Parse JSON strings and extract values using dot-notation paths"
    
    @Generable
    struct Arguments {
        @Guide(description: "JSON string to parse")
        let json: String
        
        @Guide(description: "Dot-notation path to extract a specific value e.g. 'user.name' or 'items.0.id'")
        let key_path: String?
        
        @Guide(description: "Operation: 'parse', 'extract', 'validate', 'format'")
        let operation: String?
    }
    
    func call(arguments: Arguments) async throws -> String {
        let tool = JSONParserTool()
        
        var args: [String: Any] = ["json": arguments.json]
        
        if let key_path = arguments.key_path { args["key_path"] = key_path }
        if let operation = arguments.operation { args["operation"] = operation }
        
        return try await tool.execute(arguments: args)
    }
}

// MARK: - WebSearchTool Wrapper

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct WebSearchToolWrapper: FMTool {
    let name = "web_search"
    let description = "Search the web for current information, news, facts and data"
    
    @Generable
    struct Arguments {
        @Guide(description: "Search query to look up on the web")
        let query: String
        
        @Guide(description: "Maximum number of results to return (1-10, defaults to 5)", .range(1...10))
        let maxResults: Int?
    }
    
    func call(arguments: Arguments) async throws -> String {
        let tool = WebSearchTool()
        
        var args: [String: Any] = ["query": arguments.query]
        if let maxResults = arguments.maxResults { args["max_results"] = maxResults }
        
        return try await tool.execute(arguments: args)
    }
}

// MARK: - GoogleCalendarTool Wrapper

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct GoogleCalendarToolWrapper: FMTool {
    let name = "google_calendar_tool"
    let description = "Manage Google Calendar events. Can create, read, update, and delete calendar events."
    
    private let accessToken: String
    
    init(accessToken: String) {
        self.accessToken = accessToken
    }
    
    @Generable
    struct Arguments {
        @Guide(description: """
        Action to perform:
        - 'create': Create a new calendar event
        - 'list': List upcoming events
        - 'get': Get details of a specific event
        - 'update': Update an existing event
        - 'delete': Delete an event
        - 'search': Search for events
        - 'list_calendars': List all calendars
        """)
        let action: String
        
        @Guide(description: "Calendar ID (default: 'primary' for main calendar)")
        let calendarId: String?
        
        @Guide(description: "Event title/summary (required for create)")
        let summary: String?
        
        @Guide(description: "Event description")
        let description: String?
        
        @Guide(description: "Event location")
        let location: String?
        
        @Guide(description: "Start time in ISO 8601 format e.g. '2026-02-19T14:00:00Z' (required for create)")
        let startTime: String?
        
        @Guide(description: "End time in ISO 8601 format e.g. '2026-02-19T15:00:00Z' (required for create)")
        let endTime: String?
        
        @Guide(description: "Time zone e.g. 'America/New_York', 'Europe/Zagreb' (default: 'UTC')")
        let timeZone: String?
        
        @Guide(description: "Comma-separated attendee emails e.g. 'alice@example.com,bob@example.com'")
        let attendees: String?
        
        @Guide(description: "Add Google Meet link (true/false)")
        let addMeetLink: Bool?
        
        @Guide(description: "Event ID (required for get, update, delete actions)")
        let eventId: String?
        
        @Guide(description: "Search query (required for search action)")
        let query: String?
        
        @Guide(description: "Maximum number of results (1-50, default: 10)", .range(1...50))
        let maxResults: Int?
        
        @Guide(description: "Lower bound for event start time in ISO 8601 format")
        let timeMin: String?
        
        @Guide(description: "Upper bound for event start time in ISO 8601 format")
        let timeMax: String?
    }
    
    func call(arguments: Arguments) async throws -> String {
        let tool = GoogleCalendarTool(accessToken: accessToken)
        
        var args: [String: Any] = ["action": arguments.action]
        
        if let calendarId = arguments.calendarId { args["calendarId"] = calendarId }
        if let summary = arguments.summary { args["summary"] = summary }
        if let description = arguments.description { args["description"] = description }
        if let location = arguments.location { args["location"] = location }
        if let startTime = arguments.startTime { args["startTime"] = startTime }
        if let endTime = arguments.endTime { args["endTime"] = endTime }
        if let timeZone = arguments.timeZone { args["timeZone"] = timeZone }
        
        if let attendeesStr = arguments.attendees, !attendeesStr.isEmpty {
            let attendeesList = attendeesStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            args["attendees"] = attendeesList
        }
        
        if let addMeetLink = arguments.addMeetLink { args["addMeetLink"] = addMeetLink }
        if let eventId = arguments.eventId { args["eventId"] = eventId }
        if let query = arguments.query { args["query"] = query }
        if let maxResults = arguments.maxResults { args["maxResults"] = maxResults }
        if let timeMin = arguments.timeMin { args["timeMin"] = timeMin }
        if let timeMax = arguments.timeMax { args["timeMax"] = timeMax }
        
        return try await tool.execute(arguments: args)
    }
}

// MARK: - Factory

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct FoundationModelToolFactory {
    
    /// Convert SwiftAgents tools to Foundation Models tools
    public static func wrap(_ tools: [Tool]) -> [any FMTool] {
        return tools.compactMap { wrap($0) }
    }
    
    /// Convert a single SwiftAgents tool to Foundation Models tool
    public static func wrap(_ tool: Tool) -> (any FMTool)? {
        switch tool.name {
        case "datetime_tool":
            return DateTimeToolWrapper()
        case "file_system_tool":
            return FileSystemToolWrapper()
        case "http_request_tool":
            return HTTPRequestToolWrapper()
        case "json_parser_tool":
            return JSONParserToolWrapper()
        case "web_search_tool":
            return WebSearchToolWrapper()
        case "google_calendar_tool":  //
            if let calendarTool = tool as? GoogleCalendarTool {
                return GoogleCalendarToolWrapper(accessToken: calendarTool.accessToken)
            }
            return nil
        default:
            return nil
        }
    }
}

#endif
