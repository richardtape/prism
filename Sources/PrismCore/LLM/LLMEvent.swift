//
//  LLMEvent.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Streaming events emitted by the LLM client.
public enum LLMEvent: Sendable, Equatable {
    case token(String)
    case toolCall(LLMToolCall)
    case done
    case error(LLMError)
}
