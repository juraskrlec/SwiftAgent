//
//  CalendarTool.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 13.02.2026..
//

import Foundation
import EventKit

actor CalendarActor {
    static let shared = CalendarActor()
    
    private let eventStore = EKEventStore()
    
    private init() {}
    
    func requestAccess() async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
    }
    
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date?,
        location: String?,
        notes: String?,
        allDay: Bool,
        url: URL?
    ) throws -> String {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate)
        event.location = location
        event.notes = notes
        event.isAllDay = allDay
        event.url = url
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        try eventStore.save(event, span: .thisEvent)
        
        return event.eventIdentifier
    }
    
    func readEvents(
        startDate: Date,
        endDate: Date,
        calendars: [String]?
    ) -> [EventInfo] {
        let ekCalendars: [EKCalendar]?
        if let calendarTitles = calendars {
            ekCalendars = eventStore.calendars(for: .event).filter { calendar in
                calendarTitles.contains(calendar.title)
            }
        } else {
            ekCalendars = nil
        }
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: ekCalendars
        )
        
        let events = eventStore.events(matching: predicate)
        
        return events.map { event in
            EventInfo(
                id: event.eventIdentifier,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                notes: event.notes,
                isAllDay: event.isAllDay,
                calendar: event.calendar.title,
                url: event.url
            )
        }
    }
    
    func searchEvents(query: String, limit: Int) -> [EventInfo] {
        let now = Date()
        let futureDate = Calendar.current.date(byAdding: .year, value: 1, to: now)!
        
        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: futureDate,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
            .filter { event in
                let titleMatch = event.title?.localizedCaseInsensitiveContains(query) ?? false
                let locationMatch = event.location?.localizedCaseInsensitiveContains(query) ?? false
                let notesMatch = event.notes?.localizedCaseInsensitiveContains(query) ?? false
                return titleMatch || locationMatch || notesMatch
            }
            .prefix(limit)
        
        return events.map { event in
            EventInfo(
                id: event.eventIdentifier,
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                notes: event.notes,
                isAllDay: event.isAllDay,
                calendar: event.calendar.title,
                url: event.url
            )
        }
    }
    
    func updateEvent(
        eventId: String,
        title: String?,
        startDate: Date?,
        endDate: Date?,
        location: String?,
        notes: String?,
        url: URL?
    ) throws {
        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw CalendarError.eventNotFound
        }
        
        if let title = title {
            event.title = title
        }
        if let startDate = startDate {
            event.startDate = startDate
        }
        if let endDate = endDate {
            event.endDate = endDate
        }
        if let location = location {
            event.location = location
        }
        if let notes = notes {
            event.notes = notes
        }
        if let url = url {
            event.url = url
        }
        
        try eventStore.save(event, span: .thisEvent)
    }
    
    func deleteEvent(eventId: String) throws {
        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw CalendarError.eventNotFound
        }
        
        try eventStore.remove(event, span: .thisEvent)
    }
    
    func listCalendars() -> [CalendarInfo] {
        eventStore.calendars(for: .event).map { calendar in
            CalendarInfo(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                isSubscribed: calendar.isSubscribed,
                allowsContentModifications: calendar.allowsContentModifications
            )
        }
    }
}

// MARK: - Data Models

struct EventInfo: Codable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let calendar: String
    let url: URL?
}

struct CalendarInfo: Codable, Sendable {
    let id: String
    let title: String
    let isSubscribed: Bool
    let allowsContentModifications: Bool
}

enum CalendarError: Error, LocalizedError {
    case permissionDenied
    case eventNotFound
    case invalidDate
    case invalidArguments(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Calendar access was denied. Please enable in Settings."
        case .eventNotFound:
            return "Event not found"
        case .invalidDate:
            return "Invalid date format"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        }
    }
}

// MARK: - Calendar Tool

/// Manage calendar events and schedules
public struct CalendarTool: Tool, Sendable {
    public let name = "calendar"
    public let description = """
    Create, read, update, delete, and search calendar events. Can manage the user's calendar, 
    schedule meetings, check availability, and find upcoming events.
    """
    
    public var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "action": ParameterProperty(
                    type: "string",
                    description: "Action to perform",
                    enumValues: ["create", "read", "search", "update", "delete", "list_calendars"]
                ),
                "title": ParameterProperty(
                    type: "string",
                    description: "Event title (for create/update)"
                ),
                "startDate": ParameterProperty(
                    type: "string",
                    description: "Start date/time in ISO 8601 format (e.g., '2026-02-14T10:00:00Z')"
                ),
                "endDate": ParameterProperty(
                    type: "string",
                    description: "End date/time in ISO 8601 format (optional, defaults to 1 hour after start)"
                ),
                "location": ParameterProperty(
                    type: "string",
                    description: "Event location"
                ),
                "notes": ParameterProperty(
                    type: "string",
                    description: "Event notes/description"
                ),
                "allDay": ParameterProperty(
                    type: "boolean",
                    description: "Whether this is an all-day event (default: false)"
                ),
                "url": ParameterProperty(
                    type: "string",
                    description: "URL associated with the event (e.g., Zoom link)"
                ),
                "eventId": ParameterProperty(
                    type: "string",
                    description: "Event identifier (for update/delete)"
                ),
                "query": ParameterProperty(
                    type: "string",
                    description: "Search query (for search action)"
                ),
                "timeframe": ParameterProperty(
                    type: "string",
                    description: "Timeframe for reading events",
                    enumValues: ["today", "tomorrow", "this_week", "next_week", "this_month", "custom"]
                ),
                "customStartDate": ParameterProperty(
                    type: "string",
                    description: "Custom start date for read action (ISO 8601)"
                ),
                "customEndDate": ParameterProperty(
                    type: "string",
                    description: "Custom end date for read action (ISO 8601)"
                ),
                "calendars": ParameterProperty(
                    type: "array",
                    description: "Array of calendar names to filter (optional)"
                ),
                "limit": ParameterProperty(
                    type: "integer",
                    description: "Maximum number of results to return (for search, default: 10)"
                )
            ],
            required: ["action"]
        )
    }
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> String {
        // Request calendar access
        let granted = try await CalendarActor.shared.requestAccess()
        guard granted else {
            throw CalendarError.permissionDenied
        }
        
        guard let action = arguments["action"] as? String else {
            throw ToolError.invalidArguments("Missing 'action' parameter")
        }
        
        switch action {
        case "create":
            return try await createEvent(arguments)
        case "read":
            return try await readEvents(arguments)
        case "search":
            return try await searchEvents(arguments)
        case "update":
            return try await updateEvent(arguments)
        case "delete":
            return try await deleteEvent(arguments)
        case "list_calendars":
            return try await listCalendars()
        default:
            throw ToolError.invalidArguments("Invalid action: \(action)")
        }
    }
    
    // MARK: - Action Implementations
    
    private func createEvent(_ args: [String: Any]) async throws -> String {
        guard let title = args["title"] as? String else {
            throw CalendarError.invalidArguments("Missing 'title'")
        }
        
        guard let startDateStr = args["startDate"] as? String,
              let startDate = parseDate(startDateStr) else {
            throw CalendarError.invalidDate
        }
        
        let endDate: Date?
        if let endDateStr = args["endDate"] as? String {
            endDate = parseDate(endDateStr)
        } else {
            endDate = nil
        }
        
        let location = args["location"] as? String
        let notes = args["notes"] as? String
        let allDay = args["allDay"] as? Bool ?? false
        
        let url: URL?
        if let urlStr = args["url"] as? String {
            url = URL(string: urlStr)
        } else {
            url = nil
        }
        
        let eventId = try await CalendarActor.shared.createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: notes,
            allDay: allDay,
            url: url
        )
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var response = "Event '\(title)' created successfully"
        response += "\nWhen: \(formatter.string(from: startDate))"
        if let endDate = endDate {
            response += " - \(formatter.string(from: endDate))"
        }
        if let location = location {
            response += "\nWhere: \(location)"
        }
        if let url = url {
            response += "\nLink: \(url.absoluteString)"
        }
        response += "\nEvent ID: \(eventId)"
        
        return response
    }
    
    private func readEvents(_ args: [String: Any]) async throws -> String {
        let timeframe = args["timeframe"] as? String ?? "this_week"
        
        let (startDate, endDate) = try getDateRange(
            timeframe: timeframe,
            customStart: args["customStartDate"] as? String,
            customEnd: args["customEndDate"] as? String
        )
        
        let calendars = args["calendars"] as? [String]
        
        let events = await CalendarActor.shared.readEvents(
            startDate: startDate,
            endDate: endDate,
            calendars: calendars
        )
        
        if events.isEmpty {
            return "No events found for \(timeframe)"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var response = "Events for \(timeframe) (\(events.count) total):\n\n"
        
        for (index, event) in events.enumerated() {
            response += "\(index + 1). **\(event.title)**\n"
            
            if event.isAllDay {
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                response += "   All day on \(formatter.string(from: event.startDate))\n"
            } else {
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                response += "   \(formatter.string(from: event.startDate))"
                if event.startDate != event.endDate {
                    response += " - \(formatter.string(from: event.endDate))\n"
                } else {
                    response += "\n"
                }
            }
            
            if let location = event.location {
                response += "   \(location)\n"
            }
            
            if let notes = event.notes, !notes.isEmpty {
                let truncatedNotes = notes.prefix(100)
                response += "   \(truncatedNotes)\(notes.count > 100 ? "..." : "")\n"
            }
            
            if let url = event.url {
                response += "   \(url.absoluteString)\n"
            }
            
            response += "   Calendar: \(event.calendar)\n"
            response += "   ID: \(event.id)\n"
            
            if index < events.count - 1 {
                response += "\n"
            }
        }
        
        return response
    }
    
    private func searchEvents(_ args: [String: Any]) async throws -> String {
        guard let query = args["query"] as? String else {
            throw CalendarError.invalidArguments("Missing 'query'")
        }
        
        let limit = args["limit"] as? Int ?? 10
        
        let events = await CalendarActor.shared.searchEvents(query: query, limit: limit)
        
        if events.isEmpty {
            return "No events found matching '\(query)'"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var response = "Found \(events.count) event(s) matching '\(query)':\n\n"
        
        for (index, event) in events.enumerated() {
            response += "\(index + 1). **\(event.title)**\n"
            response += "   \(formatter.string(from: event.startDate))\n"
            
            if let location = event.location {
                response += "   \(location)\n"
            }
            
            response += "   ID: \(event.id)\n"
            
            if index < events.count - 1 {
                response += "\n"
            }
        }
        
        return response
    }
    
    private func updateEvent(_ args: [String: Any]) async throws -> String {
        guard let eventId = args["eventId"] as? String else {
            throw CalendarError.invalidArguments("Missing 'eventId'")
        }
        
        let title = args["title"] as? String
        
        let startDate: Date?
        if let startDateStr = args["startDate"] as? String {
            startDate = parseDate(startDateStr)
        } else {
            startDate = nil
        }
        
        let endDate: Date?
        if let endDateStr = args["endDate"] as? String {
            endDate = parseDate(endDateStr)
        } else {
            endDate = nil
        }
        
        let location = args["location"] as? String
        let notes = args["notes"] as? String
        
        let url: URL?
        if let urlStr = args["url"] as? String {
            url = URL(string: urlStr)
        } else {
            url = nil
        }
        
        try await CalendarActor.shared.updateEvent(
            eventId: eventId,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: notes,
            url: url
        )
        
        return "Event updated successfully (ID: \(eventId))"
    }
    
    private func deleteEvent(_ args: [String: Any]) async throws -> String {
        guard let eventId = args["eventId"] as? String else {
            throw CalendarError.invalidArguments("Missing 'eventId'")
        }
        
        try await CalendarActor.shared.deleteEvent(eventId: eventId)
        
        return "Event deleted successfully (ID: \(eventId))"
    }
    
    private func listCalendars() async throws -> String {
        let calendars = await CalendarActor.shared.listCalendars()
        
        if calendars.isEmpty {
            return "No calendars found"
        }
        
        var response = "Available Calendars (\(calendars.count)):\n\n"
        
        for (index, calendar) in calendars.enumerated() {
            response += "\(index + 1). **\(calendar.title)**\n"
            response += "   ID: \(calendar.id)\n"
            
            if calendar.isSubscribed {
                response += "   Subscribed calendar\n"
            }
            
            if !calendar.allowsContentModifications {
                response += "   Read-only\n"
            }
            
            if index < calendars.count - 1 {
                response += "\n"
            }
        }
        
        return response
    }
    
    // MARK: - Helper Methods
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
    
    private func getDateRange(
        timeframe: String,
        customStart: String?,
        customEnd: String?
    ) throws -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeframe {
        case "today":
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
            
        case "tomorrow":
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let startOfDay = calendar.startOfDay(for: tomorrow)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
            
        case "this_week":
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
            
        case "next_week":
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            let nextWeekEnd = calendar.date(byAdding: .day, value: 7, to: nextWeekStart)!
            return (nextWeekStart, nextWeekEnd)
            
        case "this_month":
            let components = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: components)!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            return (startOfMonth, endOfMonth)
            
        case "custom":
            guard let startStr = customStart,
                  let endStr = customEnd,
                  let start = parseDate(startStr),
                  let end = parseDate(endStr) else {
                throw CalendarError.invalidArguments("Invalid custom date range")
            }
            return (start, end)
            
        default:
            throw CalendarError.invalidArguments("Invalid timeframe: \(timeframe)")
        }
    }
}
