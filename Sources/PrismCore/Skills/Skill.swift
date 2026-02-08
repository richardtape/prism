//
//  Skill.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Tool call request as produced by the LLM.
public struct ToolCall: Sendable, Equatable {
    public let id: String?
    public let name: String
    public let arguments: JSONValue

    public init(id: String?, name: String, arguments: JSONValue) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// Tool execution result returned by a skill.
public struct ToolResult: Sendable, Equatable {
    public let callID: String?
    public let output: JSONValue

    public init(callID: String?, output: JSONValue) {
        self.callID = callID
        self.output = output
    }
}

/// Metadata describing a skill for UI display.
public struct SkillMetadata: Sendable, Equatable {
    public let name: String
    public let description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

/// Protocol describing a tool-capable skill.
public protocol Skill: Sendable {
    var id: String { get }
    var metadata: SkillMetadata { get }
    var toolSchema: LLMToolDefinition { get }

    func execute(call: ToolCall) async throws -> SkillResult
}
