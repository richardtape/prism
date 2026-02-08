//
//  SkillResult.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-08.
//

import Foundation

/// Status values describing the outcome of a skill execution.
public enum SkillResultStatus: String, Sendable, Equatable {
    case ok
    case error
    case needsClarification = "needs_clarification"
    case pendingConfirmation = "pending_confirmation"
}

/// Confirmation state for destructive skill actions.
public struct PendingConfirmation: Sendable, Equatable {
    public let id: UUID
    public let prompt: String

    public init(id: UUID = UUID(), prompt: String) {
        self.id = id
        self.prompt = prompt
    }
}

/// Structured result returned by a skill execution.
public struct SkillResult: Sendable, Equatable {
    public let status: SkillResultStatus
    public let summary: String
    public let data: JSONValue?
    public let error: String?
    public let pendingConfirmation: PendingConfirmation?

    public init(
        status: SkillResultStatus,
        summary: String,
        data: JSONValue? = nil,
        error: String? = nil,
        pendingConfirmation: PendingConfirmation? = nil
    ) {
        self.status = status
        self.summary = summary
        self.data = data
        self.error = error
        self.pendingConfirmation = pendingConfirmation
    }

    public static func ok(summary: String, data: JSONValue? = nil) -> SkillResult {
        SkillResult(status: .ok, summary: summary, data: data)
    }

    public static func error(summary: String, error: Error? = nil) -> SkillResult {
        SkillResult(status: .error, summary: summary, error: error?.localizedDescription)
    }

    public static func needsClarification(_ summary: String) -> SkillResult {
        SkillResult(status: .needsClarification, summary: summary)
    }

    public static func pendingConfirmation(prompt: String) -> SkillResult {
        let confirmation = PendingConfirmation(prompt: prompt)
        return SkillResult(
            status: .pendingConfirmation,
            summary: prompt,
            pendingConfirmation: confirmation
        )
    }

    func toolOutput() -> JSONValue {
        var payload: [String: JSONValue] = [
            "status": .string(status.rawValue),
            "summary": .string(summary)
        ]
        if let data {
            payload["data"] = data
        }
        if let error {
            payload["error"] = .string(error)
        }
        if let pendingConfirmation {
            payload["pendingConfirmation"] = .object([
                "id": .string(pendingConfirmation.id.uuidString),
                "prompt": .string(pendingConfirmation.prompt)
            ])
        }
        return .object(payload)
    }
}
