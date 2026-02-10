//
//  AppleIntelligenceModels.swift
//  SwiftAgent
//
//  Created by Jura Skrlec on 10.02.2026..
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

// Re-export Foundation Models types for convenience
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public typealias LanguageModelSession = FoundationModels.LanguageModelSession

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public typealias Instructions = FoundationModels.Instructions

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public typealias Prompt = FoundationModels.Prompt

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public typealias Generable = FoundationModels.Generable

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public typealias ToolProtocol = FoundationModels.Tool

#endif
