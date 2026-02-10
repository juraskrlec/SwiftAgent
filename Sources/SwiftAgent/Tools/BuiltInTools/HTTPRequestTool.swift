//
//  HTTPRequestTool.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

/// A tool for making HTTP requests
public struct HTTPRequestTool: Tool {
    public let name = "http_request"
    public let description = "Make HTTP requests (GET, POST, PUT, DELETE) to external APIs"
    
    public var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "method": ParameterProperty(
                    type: "string",
                    description: "HTTP method",
                    enumValues: ["GET", "POST", "PUT", "DELETE", "PATCH"]
                ),
                "url": ParameterProperty(
                    type: "string",
                    description: "The URL to request"
                ),
                "headers": ParameterProperty(
                    type: "string",
                    description: "JSON string of headers (optional)"
                ),
                "body": ParameterProperty(
                    type: "string",
                    description: "Request body (for POST, PUT, PATCH)"
                ),
                "timeout": ParameterProperty(
                    type: "number",
                    description: "Timeout in seconds (default: 30)"
                )
            ],
            required: ["method", "url"]
        )
    }
    
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func execute(arguments: [String: Any]) async throws -> String {
        guard let method = arguments["method"] as? String else {
            throw ToolError.invalidArguments("Missing 'method' parameter")
        }
        
        guard let urlString = arguments["url"] as? String,
              let url = URL(string: urlString) else {
            throw ToolError.invalidArguments("Invalid or missing 'url' parameter")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Set timeout
        if let timeout = arguments["timeout"] as? Double {
            request.timeoutInterval = timeout
        } else {
            request.timeoutInterval = 30
        }
        
        // Add headers
        if let headersString = arguments["headers"] as? String,
           let headersData = headersString.data(using: .utf8),
           let headers = try? JSONSerialization.jsonObject(with: headersData) as? [String: String] {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Add body for POST, PUT, PATCH
        if ["POST", "PUT", "PATCH"].contains(method) {
            if let body = arguments["body"] as? String {
                request.httpBody = body.data(using: .utf8)
                
                // Set default content type if not specified
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ToolError.executionFailed("Invalid response type")
            }
            
            let statusCode = httpResponse.statusCode
            let body = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            
            var result = "Status: \(statusCode)\n"
            
            if (200...299).contains(statusCode) {
                result += "Success!\n"
            } else {
                result += "Error\n"
            }
            
            result += "Response:\n\(body)"
            
            return result
            
        } catch {
            throw ToolError.executionFailed("HTTP request failed: \(error.localizedDescription)")
        }
    }
}
