//
//  LLMMessage.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Role values used in OpenAI-compatible chat completion requests.
public enum LLMRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool
}

/// Tool call payloads in assistant responses.
public struct LLMToolCall: Codable, Sendable, Equatable {
    public let id: String?
    public let type: String
    public let function: Function

    public struct Function: Codable, Sendable, Equatable {
        public let name: String
        public let arguments: JSONValue

        public init(name: String, arguments: JSONValue) {
            self.name = name
            self.arguments = arguments
        }
    }

    public init(id: String?, type: String = "function", function: Function) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Chat message payload for LLM requests.
public struct LLMMessage: Codable, Sendable, Equatable {
    public let role: LLMRole
    public let content: String?
    public let name: String?
    public let toolCallID: String?
    public let toolCalls: [LLMToolCall]?

    public init(
        role: LLMRole,
        content: String?,
        name: String? = nil,
        toolCallID: String? = nil,
        toolCalls: [LLMToolCall]? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCallID = toolCallID
        self.toolCalls = toolCalls
    }
}

private enum LLMMessageCodingKeys: String, CodingKey {
    case role
    case content
    case name
    case toolCallID = "tool_call_id"
    case toolCalls = "tool_calls"
}

extension LLMMessage {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: LLMMessageCodingKeys.self)
        role = try container.decode(LLMRole.self, forKey: .role)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        toolCallID = try container.decodeIfPresent(String.self, forKey: .toolCallID)
        toolCalls = try container.decodeIfPresent([LLMToolCall].self, forKey: .toolCalls)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LLMMessageCodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(toolCallID, forKey: .toolCallID)
        try container.encodeIfPresent(toolCalls, forKey: .toolCalls)
    }
}
