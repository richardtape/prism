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
    private let registry: SkillRegistry
    private let pendingStore = PendingConfirmationStore()
    private let confirmationTimeout: TimeInterval = 15

    public init(registry: SkillRegistry) {
        self.router = RouterAgent()
        self.planner = PlannerAgent(registry: registry)
        self.responder = ResponderAgent()
        self.registry = registry
    }

    /// Runs the pipeline and returns a response along with tool results.
    public func run(input: OrchestrationInput) async throws -> (ResponseResult, [ToolResult]) {
        if let pending = await pendingStore.current() {
            if pending.isExpired(relativeTo: Date()) {
                await pendingStore.clear()
            } else {
                return try await handlePendingConfirmation(pending, input: input)
            }
        }

        let decision = try await router.run(input: input)
        var toolResults: [ToolResult] = []
        var toolSummaries: [String] = []

        if decision.needsTools {
            let plan = try await planner.run(input: input)
            let executions = try await executeTools(plan.toolCalls)
            toolResults = executions.map { $0.toolResult }
            toolSummaries = summaries(from: executions)
            await registerPendingConfirmation(from: executions)
        }

        let response = try await responder.run(input: input, toolSummaries: toolSummaries)
        return (response, toolResults)
    }

    private func executeTools(_ calls: [ToolCall]) async throws -> [SkillExecution] {
        var results: [SkillExecution] = []
        for call in calls {
            guard let skill = registry.skill(id: call.name) else { continue }
            logSkillInput(call)
            let skillResult = try await skill.execute(call: call)
            let toolResult = ToolResult(callID: call.id, output: skillResult.toolOutput())
            logSkillOutput(call, result: toolResult)
            results.append(SkillExecution(call: call, skillResult: skillResult, toolResult: toolResult))
        }
        return results
    }

    private func handlePendingConfirmation(
        _ pending: PendingConfirmationState,
        input: OrchestrationInput
    ) async throws -> (ResponseResult, [ToolResult]) {
        switch ConfirmationParser.parse(input.userText) {
        case .confirmed:
            await pendingStore.clear()
            let confirmedCall = confirmedToolCall(from: pending.toolCall)
            let executions = try await executeTools([confirmedCall])
            let toolResults = executions.map { $0.toolResult }
            let toolSummaries = summaries(from: executions)
            await registerPendingConfirmation(from: executions)
            let response = try await responder.run(input: input, toolSummaries: toolSummaries)
            return (response, toolResults)
        case .denied:
            await pendingStore.clear()
            return (ResponseResult(message: "Okay, I won't do that."), [])
        case .unclear:
            return (ResponseResult(message: "Please confirm or cancel."), [])
        }
    }

    private func registerPendingConfirmation(from executions: [SkillExecution]) async {
        guard let pending = executions.first(where: { $0.skillResult.pendingConfirmation != nil }),
              let confirmation = pending.skillResult.pendingConfirmation else {
            return
        }

        let now = Date()
        let state = PendingConfirmationState(
            id: confirmation.id,
            toolCall: pending.call,
            prompt: confirmation.prompt,
            createdAt: now,
            expiresAt: now.addingTimeInterval(confirmationTimeout)
        )
        await pendingStore.set(state)
    }

    private func summaries(from executions: [SkillExecution]) -> [String] {
        executions
            .map { $0.skillResult.summary.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func confirmedToolCall(from call: ToolCall) -> ToolCall {
        var arguments = call.arguments.objectValue ?? [:]
        arguments["confirmed"] = .bool(true)
        return ToolCall(id: call.id, name: call.name, arguments: .object(arguments))
    }

    private func logSkillInput(_ call: ToolCall) {
        let payload = prettyPrinted(call.arguments)
        PrismLogger.skillInfo("Skill input (\(call.name)): \(payload)")
    }

    private func logSkillOutput(_ call: ToolCall, result: ToolResult) {
        let payload = prettyPrinted(result.output)
        PrismLogger.skillInfo("Skill output (\(call.name)): \(payload)")
    }

    private func prettyPrinted(_ value: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "\(value)"
        }
        return string
    }
}

private struct SkillExecution {
    let call: ToolCall
    let skillResult: SkillResult
    let toolResult: ToolResult
}

private struct PendingConfirmationState: Sendable {
    let id: UUID
    let toolCall: ToolCall
    let prompt: String
    let createdAt: Date
    let expiresAt: Date

    func isExpired(relativeTo date: Date) -> Bool {
        date >= expiresAt
    }
}

private actor PendingConfirmationStore {
    private var pending: PendingConfirmationState?

    func current() -> PendingConfirmationState? {
        pending
    }

    func set(_ confirmation: PendingConfirmationState) {
        pending = confirmation
    }

    func clear() {
        pending = nil
    }
}
