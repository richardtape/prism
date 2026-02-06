//
//  PlannerAgent.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Planner agent that prepares tool calls when routing requires tools.
public struct PlannerAgent: Agent, @unchecked Sendable {
    private let registry: SkillRegistry

    public init(registry: SkillRegistry) {
        self.registry = registry
    }

    public func run(input: OrchestrationInput) async throws -> PlanResult {
        let tools = registry.enabledToolSchemas()
        guard let firstTool = tools.first else {
            return PlanResult(toolCalls: [])
        }

        let toolCall = ToolCall(id: UUID().uuidString, name: firstTool.function.name, arguments: .object([:]))
        return PlanResult(toolCalls: [toolCall])
    }
}
