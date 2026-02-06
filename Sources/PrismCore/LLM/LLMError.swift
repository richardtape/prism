//
//  LLMError.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Canonical error states surfaced by the LLM client.
public enum LLMError: Error, Sendable, Equatable {
    case unauthorized
    case invalidRequest(String)
    case decoding(String)
    case timeout
    case network(String)
    case server(String)
    case unknown(String)
}
