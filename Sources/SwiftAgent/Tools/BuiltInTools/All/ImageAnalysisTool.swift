//
//  imageAnalysisTool.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 26.02.2026..
//

public struct ImageAnalysisTool: Tool, Sendable {
    public let name = "image_analysis_tool"
    public let description = """
    Analyze images using vision capabilities.
    Images should be passed as part of the user message.
    """
    
    public init() {}
    
    public var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "analysis_type": ParameterProperty(
                    type: "string",
                    description: "Type of analysis: describe, ocr, objects, faces, colors",
                    enumValues: ["describe", "ocr", "objects", "faces", "colors"]
                )
            ],
            required: ["analysis_type"]
        )
    }
    
    public func execute(arguments: [String: Any]) async throws -> String {
        return "Image analysis handled by LLM's native vision capabilities."
    }
}
