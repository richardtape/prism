//
//  OrchestrationModels.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Input for the full orchestration pipeline.
public struct OrchestrationInput: Sendable, Equatable {
    public let userText: String

    public init(userText: String) {
        self.userText = userText
    }
}

/// Router output describing the high-level handling decision.
public struct RouterDecision: Sendable, Equatable {
    public let needsTools: Bool

    public init(needsTools: Bool) {
        self.needsTools = needsTools
    }
}

/// Planner output with tool calls to execute.
public struct PlanResult: Sendable, Equatable {
    public let toolCalls: [ToolCall]

    public init(toolCalls: [ToolCall]) {
        self.toolCalls = toolCalls
    }
}

/// Responder output with user-facing text.
public struct ResponseResult: Sendable, Equatable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}
