//
//  LLMCompletion.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Normalized non-streaming response returned by the LLM client.
public struct LLMCompletion: Sendable, Equatable {
    public let message: LLMMessage
    public let finishReason: String?
    public let model: String
    public let usage: LLMUsage?

    public init(message: LLMMessage, finishReason: String?, model: String, usage: LLMUsage?) {
        self.message = message
        self.finishReason = finishReason
        self.model = model
        self.usage = usage
    }
}

/// Usage payload returned by OpenAI-compatible APIs.
public struct LLMUsage: Codable, Sendable, Equatable {
    public let promptTokens: Int?
    public let completionTokens: Int?
    public let totalTokens: Int?

    public init(promptTokens: Int?, completionTokens: Int?, totalTokens: Int?) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

private enum LLMUsageCodingKeys: String, CodingKey {
    case promptTokens = "prompt_tokens"
    case completionTokens = "completion_tokens"
    case totalTokens = "total_tokens"
}

extension LLMUsage {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: LLMUsageCodingKeys.self)
        promptTokens = try container.decodeIfPresent(Int.self, forKey: .promptTokens)
        completionTokens = try container.decodeIfPresent(Int.self, forKey: .completionTokens)
        totalTokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LLMUsageCodingKeys.self)
        try container.encodeIfPresent(promptTokens, forKey: .promptTokens)
        try container.encodeIfPresent(completionTokens, forKey: .completionTokens)
        try container.encodeIfPresent(totalTokens, forKey: .totalTokens)
    }
}
