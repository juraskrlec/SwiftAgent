//
//  CalculatorTool.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 13.02.2026..
//

import Foundation

/// Performs mathematical calculations
struct CalculatorTool: Tool {
    let name = "calculator"
    let description = "Perform mathematical calculations. Supports basic math, algebra, and advanced functions."
    
    var parameters: ToolParameters {
        ToolParameters(
            properties: [
                "expression": ParameterProperty(
                    type: "string",
                    description: "Mathematical expression to evaluate (e.g., '2 + 2', 'sqrt(16)', 'sin(45)')"
                )
            ],
            required: ["expression"]
        )
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let expression = arguments["expression"] as? String else {
            throw ToolError.invalidArguments("Missing expression")
        }
        
        // Use NSExpression for evaluation
        let mathExpression = NSExpression(format: expression)
        
        guard let result = mathExpression.expressionValue(with: nil, context: nil) else {
            throw ToolError.executionFailed("Invalid mathematical expression")
        }
        
        return "Result: \(result)"
    }
}
