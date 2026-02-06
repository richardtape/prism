//
//  LLMRequest.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Chat completion request payload for OpenAI-compatible endpoints.
public struct LLMRequest: Codable, Sendable, Equatable {
    public let model: String
    public let messages: [LLMMessage]
    public let tools: [LLMToolDefinition]?
    public let temperature: Double?
    public let maxTokens: Int?
    public let stream: Bool

    public init(
        model: String,
        messages: [LLMMessage],
        tools: [LLMToolDefinition]? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        stream: Bool = false
    ) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stream = stream
    }
}

private enum LLMRequestCodingKeys: String, CodingKey {
    case model
    case messages
    case tools
    case temperature
    case maxTokens = "max_tokens"
    case stream
}

extension LLMRequest {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: LLMRequestCodingKeys.self)
        model = try container.decode(String.self, forKey: .model)
        messages = try container.decode([LLMMessage].self, forKey: .messages)
        tools = try container.decodeIfPresent([LLMToolDefinition].self, forKey: .tools)
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens)
        stream = try container.decodeIfPresent(Bool.self, forKey: .stream) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LLMRequestCodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(tools, forKey: .tools)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
        try container.encode(stream, forKey: .stream)
    }
}
