//
//  OrchestrationPipeline.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Pipeline that orchestrates router, planner, responder, and memory agents.
public struct OrchestrationPipeline {
    private let router: RouterAgent
    private let planner: PlannerAgent
    private let responder: ResponderAgent
    private let memory: MemoryAgent
    private let registry: SkillRegistry

    public init(registry: SkillRegistry) {
        self.router = RouterAgent()
        self.planner = PlannerAgent(registry: registry)
        self.responder = ResponderAgent()
        self.memory = MemoryAgent()
        self.registry = registry
    }

    /// Runs the pipeline and returns a response along with tool results.
    public func run(input: OrchestrationInput) async throws -> (ResponseResult, [ToolResult]) {
        let decision = try await router.run(input: input)
        var toolResults: [ToolResult] = []

        if decision.needsTools {
            let plan = try await planner.run(input: input)
            toolResults = try await executeTools(plan.toolCalls)
        }

        let response = try await responder.run(input: input)
        _ = try await memory.run(input: response)

        return (response, toolResults)
    }

    private func executeTools(_ calls: [ToolCall]) async throws -> [ToolResult] {
        var results: [ToolResult] = []
        for call in calls {
            guard let skill = registry.skill(id: call.name) else { continue }
            let result = try await skill.execute(call: call)
            results.append(result)
        }
        return results
    }
}
