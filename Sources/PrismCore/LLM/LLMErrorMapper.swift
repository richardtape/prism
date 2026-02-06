//
//  LLMErrorMapper.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Maps errors to canonical LLMError values and fallback user messages.
public struct LLMErrorMapper {
    public static func map(_ error: Error) -> LLMError {
        if let llmError = error as? LLMError {
            return llmError
        }
        if let urlError = error as? URLError {
            if urlError.code == .timedOut {
                return .timeout
            }
            return .network(urlError.localizedDescription)
        }
        if error is DecodingError {
            return .decoding("Unable to decode response")
        }
        return .unknown(error.localizedDescription)
    }

    public static func fallbackMessage(for error: LLMError) -> String {
        switch error {
        case .unauthorized:
            return "LLM authentication failed."
        case .invalidRequest:
            return "LLM configuration is incomplete."
        case .decoding:
            return "LLM response could not be decoded."
        case .timeout:
            return "LLM request timed out."
        case .network:
            return "LLM network error."
        case .server:
            return "LLM server error."
        case .unknown:
            return "LLM error."
        }
    }
}
