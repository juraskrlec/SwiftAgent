//
//  DateTimeTool.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// A tool for getting current date, time, and performing date calculations
public struct DateTimeTool: Tool, Sendable {
    public let name = "datetime"
    public let description = "Get current date/time, calculate date differences, or format dates. Operations: 'now', 'add', 'subtract', 'format', 'parse'"
    
    public var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "operation": ParameterProperty(
                    type: "string",
                    description: "The operation to perform",
                    enumValues: ["now", "add", "subtract", "format", "parse", "difference"]
                ),
                "timezone": ParameterProperty(
                    type: "string",
                    description: "Timezone identifier (e.g., 'America/New_York', 'UTC'). Optional, defaults to system timezone."
                ),
                "date": ParameterProperty(
                    type: "string",
                    description: "ISO 8601 date string for operations that need a base date. Optional for 'add'/'subtract' (defaults to now)."
                ),
                "amount": ParameterProperty(
                    type: "number",
                    description: "Amount to add or subtract"
                ),
                "unit": ParameterProperty(
                    type: "string",
                    description: "Time unit for calculations",
                    enumValues: ["seconds", "minutes", "hours", "days", "weeks", "months", "years"]
                ),
                "format": ParameterProperty(
                    type: "string",
                    description: "Date format string (e.g., 'yyyy-MM-dd HH:mm:ss')"
                )
            ],
            required: ["operation"]
        )
    }
    
    public init() {}
    
    public func execute(arguments: [String: Any]) async throws -> String {
        guard let operation = arguments["operation"] as? String else {
            throw ToolError.invalidArguments("Missing 'operation' parameter")
        }
        
        let timeZone = getTimeZone(from: arguments)
        
        switch operation {
        case "now":
            return getCurrentDateTime(timeZone: timeZone, format: arguments["format"] as? String)
            
        case "add", "subtract":
            return try performDateCalculation(
                operation: operation,
                arguments: arguments,
                timeZone: timeZone
            )
            
        case "format":
            return try formatDate(arguments: arguments, timeZone: timeZone)
            
        case "parse":
            return try parseDate(arguments: arguments)
            
        case "difference":
            return try calculateDifference(arguments: arguments)
            
        default:
            throw ToolError.invalidArguments("Unknown operation: \(operation)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func getTimeZone(from arguments: [String: Any]) -> TimeZone {
        if let tzString = arguments["timezone"] as? String,
           let timeZone = TimeZone(identifier: tzString) {
            return timeZone
        }
        return TimeZone.current
    }
    
    private func getCurrentDateTime(timeZone: TimeZone, format: String?) -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        
        if let format = format {
            formatter.dateFormat = format
        } else {
            formatter.dateStyle = .full
            formatter.timeStyle = .full
        }
        
        return formatter.string(from: date)
    }
    
    private func performDateCalculation(
        operation: String,
        arguments: [String: Any],
        timeZone: TimeZone
    ) throws -> String {
        guard let amount = arguments["amount"] as? Int else {
            throw ToolError.invalidArguments("Missing 'amount' parameter")
        }
        
        guard let unitString = arguments["unit"] as? String else {
            throw ToolError.invalidArguments("Missing 'unit' parameter")
        }
        
        // If no date provided, use current date
        let baseDate: Date
        if let dateString = arguments["date"] as? String {
            baseDate = try parseFlexibleDate(dateString)
        } else {
            baseDate = Date()
        }
        
        let calendar = Calendar.current
        let component = try getCalendarComponent(from: unitString)
        let value = operation == "add" ? Int(amount) : -Int(amount)
        
        guard let resultDate = calendar.date(byAdding: component, value: value, to: baseDate) else {
            throw ToolError.executionFailed("Failed to calculate date")
        }
        
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        
        return formatter.string(from: resultDate)
    }
    
    private func formatDate(arguments: [String: Any], timeZone: TimeZone) throws -> String {
        guard let dateString = arguments["date"] as? String else {
            throw ToolError.invalidArguments("Missing 'date' parameter")
        }
        
        guard let format = arguments["format"] as? String else {
            throw ToolError.invalidArguments("Missing 'format' parameter")
        }
        
        let date = try parseFlexibleDate(dateString)
        
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        
        return formatter.string(from: date)
    }
    
    private func parseDate(arguments: [String: Any]) throws -> String {
        guard let dateString = arguments["date"] as? String else {
            throw ToolError.invalidArguments("Missing 'date' parameter")
        }
        
        let date = try parseFlexibleDate(dateString)
        return "Successfully parsed date: \(date.description)"
    }
    
    private func calculateDifference(arguments: [String: Any]) throws -> String {
        guard let date1String = arguments["date"] as? String else {
            throw ToolError.invalidArguments("Missing 'date' parameter")
        }
        
        guard let date2String = arguments["date2"] as? String else {
            throw ToolError.invalidArguments("Missing 'date2' parameter for difference operation")
        }
        
        let date1 = try parseFlexibleDate(date1String)
        let date2 = try parseFlexibleDate(date2String)
        
        let interval = date2.timeIntervalSince(date1)
        let days = abs(interval) / 86400
        let hours = (abs(interval).truncatingRemainder(dividingBy: 86400)) / 3600
        
        return String(format: "Difference: %.0f days, %.0f hours", days, hours)
    }
    
    private func parseFlexibleDate(_ string: String) throws -> Date {
        // Try ISO 8601 formats first
        let iso8601Formatter = ISO8601DateFormatter()
        
        // Try with fractional seconds
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: string) {
            return date
        }
        
        // Try without fractional seconds
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: string) {
            return date
        }
        
        // Try date only (no time)
        iso8601Formatter.formatOptions = [.withFullDate]
        if let date = iso8601Formatter.date(from: string) {
            return date
        }
        
        // Try common date formats
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy/MM/dd",
            "MMM dd, yyyy",
            "MMMM dd, yyyy"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: string) {
                return date
            }
        }
        
        throw ToolError.invalidArguments("Could not parse date '\(string)'. Please use ISO 8601 format (e.g., '2024-01-15T10:30:00Z') or common formats like 'yyyy-MM-dd'.")
    }
    
    private func getCalendarComponent(from unit: String) throws -> Calendar.Component {
        switch unit {
        case "seconds", "second": return .second
        case "minutes", "minute": return .minute
        case "hours", "hour": return .hour
        case "days", "day": return .day
        case "weeks", "week": return .weekOfYear
        case "months", "month": return .month
        case "years", "year": return .year
        default:
            throw ToolError.invalidArguments("Unknown unit: \(unit)")
        }
    }
}
