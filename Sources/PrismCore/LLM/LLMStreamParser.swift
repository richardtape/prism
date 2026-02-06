//
//  LLMStreamParser.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Parses OpenAI-compatible SSE streaming payloads into LLM events.
struct LLMStreamParser {
    func parse(lines: [String]) -> [LLMEvent] {
        var events: [LLMEvent] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard trimmed.hasPrefix("data:") else { continue }

            let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" {
                events.append(.done)
                continue
            }

            guard let data = payload.data(using: .utf8) else { continue }
            do {
                let chunk = try JSONDecoder().decode(LLMStreamChunk.self, from: data)
                events.append(contentsOf: chunk.events)
            } catch {
                events.append(.error(.decoding("Unable to decode streaming chunk")))
            }
        }

        return events
    }
}

private struct LLMStreamChunk: Codable {
    struct Choice: Codable {
        struct Delta: Codable {
            let content: String?
            let toolCalls: [LLMToolCall]?

            private enum CodingKeys: String, CodingKey {
                case content
                case toolCalls = "tool_calls"
            }
        }

        let delta: Delta?
        let finishReason: String?

        private enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    let choices: [Choice]

    var events: [LLMEvent] {
        var collected: [LLMEvent] = []

        for choice in choices {
            if let content = choice.delta?.content, !content.isEmpty {
                collected.append(.token(content))
            }
            if let toolCalls = choice.delta?.toolCalls {
                for toolCall in toolCalls {
                    collected.append(.toolCall(toolCall))
                }
            }
            if choice.finishReason != nil {
                collected.append(.done)
            }
        }

        return collected
    }
}
