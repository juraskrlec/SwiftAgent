//
//  Client.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 15.02.2026..
//


import Foundation

/// Client for Google Calendar REST API
public actor GoogleCalendarClient {
    private let accessToken: String
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let debug: Bool
    
    public init(accessToken: String, debug: Bool = false) {
        self.accessToken = accessToken
        self.debug = debug
    }
    
    // MARK: - Calendar Operations
    
    /// List all calendars
    public func listCalendars() async throws -> [GoogleCalendar] {
        let url = URL(string: "\(baseURL)/users/me/calendarList")!
        
        let response: CalendarList = try await request(url: url, method: "GET")
        return response.items
    }
    
    /// Get a specific calendar
    public func getCalendar(calendarId: String) async throws -> GoogleCalendar {
        let encodedId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let url = URL(string: "\(baseURL)/calendars/\(encodedId)")!
        
        return try await request(url: url, method: "GET")
    }
    
    // MARK: - Event Operations
    
    /// Create an event
    public func createEvent(
        calendarId: String = "primary",
        summary: String,
        description: String? = nil,
        location: String? = nil,
        startTime: Date,
        endTime: Date,
        timeZone: String = "UTC",
        attendees: [String]? = nil,
        addMeetLink: Bool = false
    ) async throws -> GoogleCalendarEvent {
        let encodedId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        var urlComponents = URLComponents(string: "\(baseURL)/calendars/\(encodedId)/events")!
        
        // Add conferenceDataVersion if Meet link requested
        if addMeetLink {
            urlComponents.queryItems = [URLQueryItem(name: "conferenceDataVersion", value: "1")]
        }
        
        guard let url = urlComponents.url else {
            throw GoogleCalendarError.invalidResponse
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        var eventRequest = CreateEventRequest(
            summary: summary,
            description: description,
            location: location,
            start: CreateEventRequest.EventDateTime(
                dateTime: formatter.string(from: startTime),
                timeZone: timeZone
            ),
            end: CreateEventRequest.EventDateTime(
                dateTime: formatter.string(from: endTime),
                timeZone: timeZone
            ),
            attendees: attendees?.map { CreateEventRequest.Attendee(email: $0, displayName: nil, optional: false) },
            conferenceData: nil
        )
        
        // Add Meet link if requested
        if addMeetLink {
            eventRequest = CreateEventRequest(
                summary: eventRequest.summary,
                description: eventRequest.description,
                location: eventRequest.location,
                start: eventRequest.start,
                end: eventRequest.end,
                attendees: eventRequest.attendees,
                conferenceData: CreateEventRequest.ConferenceData(
                    createRequest: CreateEventRequest.ConferenceData.CreateRequest(
                        requestId: UUID().uuidString,
                        conferenceSolutionKey: CreateEventRequest.ConferenceData.CreateRequest.Key(type: "hangoutsMeet")
                    )
                )
            )
        }
        
        return try await request(url: url, method: "POST", body: eventRequest)
    }
    
    /// List events
    public func listEvents(
        calendarId: String = "primary",
        timeMin: Date? = nil,
        timeMax: Date? = nil,
        maxResults: Int = 10,
        query: String? = nil
    ) async throws -> [GoogleCalendarEvent] {
        let encodedId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        var urlComponents = URLComponents(string: "\(baseURL)/calendars/\(encodedId)/events")!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "maxResults", value: "\(maxResults)"),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        if let timeMin = timeMin {
            queryItems.append(URLQueryItem(name: "timeMin", value: formatter.string(from: timeMin)))
        }
        
        if let timeMax = timeMax {
            queryItems.append(URLQueryItem(name: "timeMax", value: formatter.string(from: timeMax)))
        }
        
        if let query = query {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw GoogleCalendarError.invalidResponse
        }
        
        let response: EventsList = try await request(url: url, method: "GET")
        return response.items ?? []
    }
    
    /// Get a specific event
    public func getEvent(calendarId: String = "primary", eventId: String) async throws -> GoogleCalendarEvent {
        let encodedCalendarId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let encodedEventId = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventId
        let url = URL(string: "\(baseURL)/calendars/\(encodedCalendarId)/events/\(encodedEventId)")!
        
        return try await request(url: url, method: "GET")
    }
    
    /// Update an event
    public func updateEvent(
        calendarId: String = "primary",
        eventId: String,
        summary: String? = nil,
        description: String? = nil,
        location: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        timeZone: String = "UTC"
    ) async throws -> GoogleCalendarEvent {
        // First get the existing event
        let existingEvent = try await getEvent(calendarId: calendarId, eventId: eventId)
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        // Build update request with existing values as defaults
        let eventRequest = CreateEventRequest(
            summary: summary ?? existingEvent.summary ?? "",
            description: description ?? existingEvent.description,
            location: location ?? existingEvent.location,
            start: CreateEventRequest.EventDateTime(
                dateTime: startTime.map { formatter.string(from: $0) } ?? existingEvent.start.dateTime ?? "",
                timeZone: timeZone
            ),
            end: CreateEventRequest.EventDateTime(
                dateTime: endTime.map { formatter.string(from: $0) } ?? existingEvent.end.dateTime ?? "",
                timeZone: timeZone
            ),
            attendees: nil,
            conferenceData: nil
        )
        
        let encodedCalendarId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let encodedEventId = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventId
        let url = URL(string: "\(baseURL)/calendars/\(encodedCalendarId)/events/\(encodedEventId)")!
        
        return try await request(url: url, method: "PUT", body: eventRequest)
    }
    
    /// Delete an event
    public func deleteEvent(calendarId: String = "primary", eventId: String) async throws {
        let encodedCalendarId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let encodedEventId = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventId
        let url = URL(string: "\(baseURL)/calendars/\(encodedCalendarId)/events/\(encodedEventId)")!
        
        let _: EmptyResponse? = try await request(url: url, method: "DELETE")
    }
    
    // MARK: - Private Helpers
    
    private func request<T: Decodable>(
            url: URL,
            method: String,
            body: (some Encodable)? = nil as EmptyRequest?
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
            
            if debug {
                print("[DEBUG] Request URL: \(url)")
                print("[DEBUG] Request Method: \(method)")
                print("[DEBUG] Request Body:")
                if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                    print(bodyString)
                }
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.invalidResponse
        }
        
        if debug {
            print("[DEBUG] Response Status: \(httpResponse.statusCode)")
            print("[DEBUG] Response Body:")
            if let responseString = String(data: data, encoding: .utf8) {
                print(responseString)
            }
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            } catch {
                print("[ERROR] Failed to decode response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[ERROR] Response was: \(responseString)")
                }
                throw GoogleCalendarError.invalidResponse
            }
            
        case 401:
            throw GoogleCalendarError.authenticationFailed
            
        case 400...499:
            if let errorResponse = try? JSONDecoder().decode(GoogleAPIError.self, from: data) {
                print("[ERROR] API Error: \(errorResponse.error.message)")
                throw GoogleCalendarError.apiError(errorResponse.error.message)
            }
            
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("[ERROR] HTTP \(httpResponse.statusCode) Response: \(responseString)")
            }
            
            throw GoogleCalendarError.apiError("HTTP \(httpResponse.statusCode)")
            
        case 500...599:
            throw GoogleCalendarError.apiError("Server error: \(httpResponse.statusCode)")
            
        default:
            throw GoogleCalendarError.apiError("Unknown error: \(httpResponse.statusCode)")
        }
    }
}

// MARK: - Helper Types

private struct EmptyRequest: Encodable {}
private struct EmptyResponse: Decodable {}

private struct GoogleAPIError: Decodable {
    let error: ErrorDetails
    
    struct ErrorDetails: Decodable {
        let code: Int
        let message: String
        let status: String
    }
}
