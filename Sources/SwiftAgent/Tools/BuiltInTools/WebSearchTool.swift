//
//  WebSearchTool.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 11.02.2026..
//

import Foundation

/// A tool for searching the web
public struct WebSearchTool: Tool, Sendable {
    public let name = "web_search"
    public let description = "Search the web for information using DuckDuckGo. Returns search results with titles, snippets, and URLs."
    
    public var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "query": ParameterProperty(
                    type: "string",
                    description: "The search query"
                ),
                "max_results": ParameterProperty(
                    type: "number",
                    description: "Maximum number of results to return (default: 5, max: 10)"
                )
            ],
            required: ["query"]
        )
    }
    
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func execute(arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String else {
            throw ToolError.invalidArguments("Missing 'query' parameter")
        }
        
        let maxResults = (arguments["max_results"] as? Int) ?? 5
        let limitedResults = min(maxResults, 10)
        
        // Use DuckDuckGo's HTML API
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://html.duckduckgo.com/html/?q=\(encodedQuery)"
        
        guard let url = URL(string: urlString) else {
            throw ToolError.executionFailed("Invalid search URL")
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw ToolError.executionFailed("Search request failed")
            }
            
            guard let html = String(data: data, encoding: .utf8) else {
                throw ToolError.executionFailed("Failed to decode search results")
            }
            
            let results = parseSearchResults(from: html, maxResults: limitedResults)
            
            if results.isEmpty {
                return "No results found for query: '\(query)'"
            }
            
            return formatResults(results, query: query)
            
        } catch {
            throw ToolError.executionFailed("Web search failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    
    private struct SearchResult {
        let title: String
        let url: String
        let snippet: String
    }
    
    private func parseSearchResults(from html: String, maxResults: Int) -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Simple HTML parsing for DuckDuckGo results
        // This is a basic implementation - for production, consider using a proper HTML parser
        
        let resultPattern = #"<a rel="nofollow" class="result__a" href="([^"]+)">([^<]+)</a>"#
        let snippetPattern = #"<a class="result__snippet"[^>]*>([^<]+)</a>"#
        
        guard let resultRegex = try? NSRegularExpression(pattern: resultPattern, options: []),
              let snippetRegex = try? NSRegularExpression(pattern: snippetPattern, options: []) else {
            return results
        }
        
        let nsString = html as NSString
        let resultMatches = resultRegex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
        let snippetMatches = snippetRegex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
        
        for (index, match) in resultMatches.prefix(maxResults).enumerated() {
            guard match.numberOfRanges >= 3 else { continue }
            
            let urlRange = match.range(at: 1)
            let titleRange = match.range(at: 2)
            
            let url = nsString.substring(with: urlRange)
            let title = nsString.substring(with: titleRange)
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&#x27;", with: "'")
                .replacingOccurrences(of: "&quot;", with: "\"")
            
            var snippet = ""
            if index < snippetMatches.count {
                let snippetMatch = snippetMatches[index]
                if snippetMatch.numberOfRanges >= 2 {
                    let snippetRange = snippetMatch.range(at: 1)
                    snippet = nsString.substring(with: snippetRange)
                        .replacingOccurrences(of: "&amp;", with: "&")
                        .replacingOccurrences(of: "&#x27;", with: "'")
                        .replacingOccurrences(of: "&quot;", with: "\"")
                }
            }
            
            results.append(SearchResult(title: title, url: url, snippet: snippet))
        }
        
        return results
    }
    
    private func formatResults(_ results: [SearchResult], query: String) -> String {
        var output = "Search results for '\(query)':\n\n"
        
        for (index, result) in results.enumerated() {
            output += "\(index + 1). \(result.title)\n"
            output += "   URL: \(result.url)\n"
            if !result.snippet.isEmpty {
                output += "   \(result.snippet)\n"
            }
            output += "\n"
        }
        
        return output
    }
}
