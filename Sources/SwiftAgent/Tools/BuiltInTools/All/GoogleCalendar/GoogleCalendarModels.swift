//
//  Models.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 15.02.2026..
//

import Foundation

// MARK: - Calendar

public struct GoogleCalendar: Codable, Sendable {
    let id: String
    let summary: String
    let description: String?
    let timeZone: String?
    let backgroundColor: String?
    let primary: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case summary
        case description
        case timeZone
        case backgroundColor
        case primary
    }
}

public struct CalendarList: Codable {
    let items: [GoogleCalendar]
}

// MARK: - Event

public struct GoogleCalendarEvent: Codable, Sendable {
    let id: String?
    let summary: String?
    let description: String?
    let location: String?
    let start: EventDateTime
    let end: EventDateTime
    let attendees: [EventAttendee]?
    let htmlLink: String?
    let status: String?
    let created: String?
    let updated: String?
    
    struct EventDateTime: Codable {
        let dateTime: String?
        let date: String?
        let timeZone: String?
    }
    
    struct EventAttendee: Codable {
        let email: String
        let displayName: String?
        let responseStatus: String?
        let optional: Bool?
    }
}

public struct EventsList: Codable {
    let items: [GoogleCalendarEvent]?
    let nextPageToken: String?
    let summary: String?
}

// MARK: - Request/Response Models

public struct CreateEventRequest: Codable {
    let summary: String
    let description: String?
    let location: String?
    let start: EventDateTime
    let end: EventDateTime
    let attendees: [Attendee]?
    let conferenceData: ConferenceData?
    
    struct EventDateTime: Codable {
        let dateTime: String
        let timeZone: String
    }
    
    struct Attendee: Codable {
        let email: String
        let displayName: String?
        let optional: Bool?
    }
    
    struct ConferenceData: Codable {
        let createRequest: CreateRequest
        
        struct CreateRequest: Codable {
            let requestId: String
            let conferenceSolutionKey: Key
            
            struct Key: Codable {
                let type: String // "hangoutsMeet"
            }
        }
    }
}

// MARK: - Errors

public enum GoogleCalendarError: Error, LocalizedError {
    case invalidAccessToken
    case networkError(String)
    case apiError(String)
    case invalidResponse
    case authenticationFailed
    case invalidDateFormat
    
    public var errorDescription: String? {
        switch self {
        case .invalidAccessToken:
            return "Invalid or expired access token"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidResponse:
            return "Invalid response from Google Calendar API"
        case .authenticationFailed:
            return "Authentication failed. Please re-authenticate."
        case .invalidDateFormat:
            return "Invalid date format"
        }
    }
}
