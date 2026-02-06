//
//  RouterAgent.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Router agent that decides whether tool usage is required.
public struct RouterAgent: Agent {
    public init() {}

    public func run(input: OrchestrationInput) async throws -> RouterDecision {
        let trimmed = input.userText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Minimal heuristic until LLM routing is added.
        let needsTools = trimmed.contains("create") || trimmed.contains("remind")
        return RouterDecision(needsTools: needsTools)
    }
}
