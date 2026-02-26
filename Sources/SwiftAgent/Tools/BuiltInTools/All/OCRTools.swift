//
//  OCRTools.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 26.02.2026..
//

public struct OCRTool: Tool, Sendable {
    public let name = "ocr_tool"
    public let description = """
    Extract text from images using OCR.
    The image should be passed as part of the user message.
    """
    
    public init() {}
    
    public var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "format": ParameterProperty(
                    type: "string",
                    description: "Output format: plain, structured, markdown",
                    enumValues: ["plain", "structured", "markdown"]
                )
            ],
            required: []
        )
    }
    
    public func execute(arguments: [String: Any]) async throws -> String {
        return "OCR performed by LLM's vision capabilities."
    }
}
