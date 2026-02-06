//
//  ResponderAgent.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Responder agent that crafts the final user-facing message.
public struct ResponderAgent: Agent {
    public init() {}

    public func run(input: OrchestrationInput) async throws -> ResponseResult {
        ResponseResult(message: "Heard: \(input.userText)")
    }
}
