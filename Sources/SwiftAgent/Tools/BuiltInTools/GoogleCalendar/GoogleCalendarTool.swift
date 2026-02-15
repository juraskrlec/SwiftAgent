//
//  GoogleCalendarTool.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 15.02.2026..
//

import Foundation

/// Tool for interacting with Google Calendar
public struct GoogleCalendarTool: Tool, Sendable {
    public let name = "google_calendar"
    public let description = """
    Manage Google Calendar events. Can create, read, update, and delete calendar events.
    Requires Google Calendar API access token.
    """
    
    private let accessToken: String
    private let debug: Bool
    
    public init(accessToken: String, debug: Bool = false) {
        self.accessToken = accessToken
        self.debug = debug
    }
    
    public var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "action": ParameterProperty(
                    type: "string",
                    description: "Action to perform",
                    enumValues: ["create", "list", "get", "update", "delete", "search", "list_calendars"]
                ),
                "calendarId": ParameterProperty(
                    type: "string",
                    description: "Calendar ID (default: 'primary' for main calendar)"
                ),
                "summary": ParameterProperty(
                    type: "string",
                    description: "Event title/summary"
                ),
                "description": ParameterProperty(
                    type: "string",
                    description: "Event description"
                ),
                "location": ParameterProperty(
                    type: "string",
                    description: "Event location"
                ),
                "startTime": ParameterProperty(
                    type: "string",
                    description: "Start time in ISO 8601 format (e.g., '2026-02-15T14:00:00Z' or '2026-02-15T14:00:00+01:00')"
                ),
                "endTime": ParameterProperty(
                    type: "string",
                    description: "End time in ISO 8601 format"
                ),
                "timeZone": ParameterProperty(
                    type: "string",
                    description: "Time zone (e.g., 'America/New_York', 'Europe/Zagreb', default: 'UTC')"
                ),
//                "attendees": ParameterProperty(
//                    type: "array",
//                    description: "Array of attendee email addresses"
////                    items: ParameterProperty(
////                        type: "string",
////                        description: "Email address of an attendee"
////                    )
//                ),
                "addMeetLink": ParameterProperty(
                    type: "boolean",
                    description: "Add Google Meet link (for create action)"
                ),
                "eventId": ParameterProperty(
                    type: "string",
                    description: "Event ID (for get, update, delete actions)"
                ),
                "query": ParameterProperty(
                    type: "string",
                    description: "Search query (for search action)"
                ),
                "maxResults": ParameterProperty(
                    type: "integer",
                    description: "Maximum number of results (for list/search, default: 10)"
                ),
                "timeMin": ParameterProperty(
                    type: "string",
                    description: "Lower bound for event start time (ISO 8601)"
                ),
                "timeMax": ParameterProperty(
                    type: "string",
                    description: "Upper bound for event start time (ISO 8601)"
                )
            ],
            required: ["action"]
        )
    }
    
    public func execute(arguments: [String: Any]) async throws -> String {
        if debug {
            print("\n[DEBUG] GoogleCalendarTool called with arguments:")
            print(arguments)
        }
        
        guard let action = arguments["action"] as? String else {
            throw ToolError.invalidArguments("Missing 'action' parameter")
        }
        
        let client = GoogleCalendarClient(accessToken: accessToken, debug: debug)
        
        switch action {
        case "create":
            return try await createEvent(client: client, arguments: arguments)
        case "list":
            return try await listEvents(client: client, arguments: arguments)
        case "get":
            return try await getEvent(client: client, arguments: arguments)
        case "update":
            return try await updateEvent(client: client, arguments: arguments)
        case "delete":
            return try await deleteEvent(client: client, arguments: arguments)
        case "search":
            return try await searchEvents(client: client, arguments: arguments)
        case "list_calendars":
            return try await listCalendars(client: client)
        default:
            throw ToolError.invalidArguments("Invalid action: \(action)")
        }
    }
    
    // MARK: - Actions
    
    private func createEvent(client: GoogleCalendarClient, arguments: [String: Any]) async throws -> String {
        guard let summary = arguments["summary"] as? String else {
            throw ToolError.invalidArguments("Missing 'summary'")
        }
        
        guard let startTimeStr = arguments["startTime"] as? String else {
            throw ToolError.invalidArguments("Missing 'startTime' - use ISO 8601 format like '2026-02-15T14:00:00Z'")
        }
        
        guard let endTimeStr = arguments["endTime"] as? String else {
            throw ToolError.invalidArguments("Missing 'endTime' - use ISO 8601 format like '2026-02-15T15:00:00Z'")
        }
        
        if debug {
            print("[DEBUG] Creating event:")
            print("  Summary: \(summary)")
            print("  Start: \(startTimeStr)")
            print("  End: \(endTimeStr)")
        }
        
        let startTime = try parseDate(startTimeStr)
        let endTime = try parseDate(endTimeStr)
        
        let calendarId = arguments["calendarId"] as? String ?? "primary"
        let description = arguments["description"] as? String
        let location = arguments["location"] as? String
        let timeZone = arguments["timeZone"] as? String ?? "UTC"
        let attendees = arguments["attendees"] as? [String]
        let addMeetLink = arguments["addMeetLink"] as? Bool ?? false
        
        let event = try await client.createEvent(
            calendarId: calendarId,
            summary: summary,
            description: description,
            location: location,
            startTime: startTime,
            endTime: endTime,
            timeZone: timeZone,
            attendees: attendees,
            addMeetLink: addMeetLink
        )
        
        var response = "✅ Event '\(summary)' created successfully\n"
        response += "📅 When: \(formatDate(startTime)) - \(formatDate(endTime))\n"
        
        if let location = location {
            response += "📍 Where: \(location)\n"
        }
        
        if let htmlLink = event.htmlLink {
            response += "🔗 Link: \(htmlLink)\n"
        }
        
        if let eventId = event.id {
            response += "🆔 Event ID: \(eventId)\n"
        }
        
        return response
    }
    
    private func listEvents(client: GoogleCalendarClient, arguments: [String: Any]) async throws -> String {
        let calendarId = arguments["calendarId"] as? String ?? "primary"
        let maxResults = arguments["maxResults"] as? Int ?? 10
        
        let timeMin: Date?
        if let timeMinStr = arguments["timeMin"] as? String {
            timeMin = try parseDate(timeMinStr)
        } else {
            timeMin = Date() // Default to now
        }
        
        let timeMax: Date?
        if let timeMaxStr = arguments["timeMax"] as? String {
            timeMax = try parseDate(timeMaxStr)
        } else {
            timeMax = nil
        }
        
        let events = try await client.listEvents(
            calendarId: calendarId,
            timeMin: timeMin,
            timeMax: timeMax,
            maxResults: maxResults
        )
        
        if events.isEmpty {
            return "No upcoming events found"
        }
        
        var response = "📅 Upcoming Events (\(events.count)):\n\n"
        
        for (index, event) in events.enumerated() {
            response += "\(index + 1). **\(event.summary ?? "Untitled")**\n"
            
            if let startStr = event.start.dateTime, let start = try? parseDate(startStr) {
                response += "   ⏰ \(formatDate(start))\n"
            }
            
            if let location = event.location {
                response += "   📍 \(location)\n"
            }
            
            if let eventId = event.id {
                response += "   🆔 \(eventId)\n"
            }
            
            if index < events.count - 1 {
                response += "\n"
            }
        }
        
        return response
    }
    
    private func getEvent(client: GoogleCalendarClient, arguments: [String: Any]) async throws -> String {
        guard let eventId = arguments["eventId"] as? String else {
            throw ToolError.invalidArguments("Missing 'eventId'")
        }
        
        let calendarId = arguments["calendarId"] as? String ?? "primary"
        
        let event = try await client.getEvent(calendarId: calendarId, eventId: eventId)
        
        var response = "📅 Event Details\n\n"
        response += "**\(event.summary ?? "Untitled")**\n\n"
        
        if let description = event.description {
            response += "📝 \(description)\n\n"
        }
        
        if let startStr = event.start.dateTime, let start = try? parseDate(startStr),
           let endStr = event.end.dateTime, let end = try? parseDate(endStr) {
            response += "⏰ \(formatDate(start)) - \(formatDate(end))\n"
        }
        
        if let location = event.location {
            response += "📍 \(location)\n"
        }
        
        if let attendees = event.attendees, !attendees.isEmpty {
            response += "\n👥 Attendees:\n"
            for attendee in attendees {
                response += "   - \(attendee.email)"
                if let status = attendee.responseStatus {
                    response += " (\(status))"
                }
                response += "\n"
            }
        }
        
        if let htmlLink = event.htmlLink {
            response += "\n🔗 \(htmlLink)\n"
        }
        
        return response
    }
    
    private func updateEvent(client: GoogleCalendarClient, arguments: [String: Any]) async throws -> String {
        guard let eventId = arguments["eventId"] as? String else {
            throw ToolError.invalidArguments("Missing 'eventId'")
        }
        
        let calendarId = arguments["calendarId"] as? String ?? "primary"
        let summary = arguments["summary"] as? String
        let description = arguments["description"] as? String
        let location = arguments["location"] as? String
        let timeZone = arguments["timeZone"] as? String ?? "UTC"
        
        let startTime: Date?
        if let startTimeStr = arguments["startTime"] as? String {
            startTime = try parseDate(startTimeStr)
        } else {
            startTime = nil
        }
        
        let endTime: Date?
        if let endTimeStr = arguments["endTime"] as? String {
            endTime = try parseDate(endTimeStr)
        } else {
            endTime = nil
        }
        
        let event = try await client.updateEvent(
            calendarId: calendarId,
            eventId: eventId,
            summary: summary,
            description: description,
            location: location,
            startTime: startTime,
            endTime: endTime,
            timeZone: timeZone
        )
        
        return "✅ Event updated successfully\n🔗 \(event.htmlLink ?? "")"
    }
    
    private func deleteEvent(client: GoogleCalendarClient, arguments: [String: Any]) async throws -> String {
        guard let eventId = arguments["eventId"] as? String else {
            throw ToolError.invalidArguments("Missing 'eventId'")
        }
        
        let calendarId = arguments["calendarId"] as? String ?? "primary"
        
        try await client.deleteEvent(calendarId: calendarId, eventId: eventId)
        
        return "✅ Event deleted successfully (ID: \(eventId))"
    }
    
    private func searchEvents(client: GoogleCalendarClient, arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String else {
            throw ToolError.invalidArguments("Missing 'query'")
        }
        
        let calendarId = arguments["calendarId"] as? String ?? "primary"
        let maxResults = arguments["maxResults"] as? Int ?? 10
        
        let events = try await client.listEvents(
            calendarId: calendarId,
            maxResults: maxResults,
            query: query
        )
        
        if events.isEmpty {
            return "No events found matching '\(query)'"
        }
        
        var response = "🔍 Found \(events.count) event(s) matching '\(query)':\n\n"
        
        for (index, event) in events.enumerated() {
            response += "\(index + 1). **\(event.summary ?? "Untitled")**\n"
            
            if let startStr = event.start.dateTime, let start = try? parseDate(startStr) {
                response += "   ⏰ \(formatDate(start))\n"
            }
            
            if let eventId = event.id {
                response += "   🆔 \(eventId)\n"
            }
            
            if index < events.count - 1 {
                response += "\n"
            }
        }
        
        return response
    }
    
    private func listCalendars(client: GoogleCalendarClient) async throws -> String {
        let calendars = try await client.listCalendars()
        
        if calendars.isEmpty {
            return "No calendars found"
        }
        
        var response = "📚 Your Calendars (\(calendars.count)):\n\n"
        
        for (index, calendar) in calendars.enumerated() {
            response += "\(index + 1). **\(calendar.summary)**\n"
            response += "   🆔 ID: \(calendar.id)\n"
            
            if let description = calendar.description {
                response += "   📝 \(description)\n"
            }
            
            if calendar.primary == true {
                response += "   ⭐ Primary calendar\n"
            }
            
            if index < calendars.count - 1 {
                response += "\n"
            }
        }
        
        return response
    }
    
    // MARK: - Helpers
    
    private func parseDate(_ dateString: String) throws -> Date {
        // Try different formats
        let formatters: [(ISO8601DateFormatter.Options, String)] = [
            ([.withInternetDateTime, .withFractionalSeconds], "ISO8601 with fractional seconds"),
            ([.withInternetDateTime], "ISO8601 standard"),
            ([.withFullDate, .withTime, .withColonSeparatorInTime], "ISO8601 without timezone"),
        ]
        
        for (options, formatName) in formatters {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            
            if let date = formatter.date(from: dateString) {
                if debug {
                    print("[DEBUG] Parsed '\(dateString)' using \(formatName) -> \(date)")
                }
                return date
            }
        }
        
        // Try fallback: manual parsing for common formats
        if let date = tryManualParse(dateString) {
            return date
        }
        
        throw GoogleCalendarError.invalidDateFormat
    }
    
    private func tryManualParse(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSS"
        ]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                if debug {
                    print("[DEBUG] Parsed '\(dateString)' using manual format '\(format)' -> \(date)")
                }
                return date
            }
        }
        
        return nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
