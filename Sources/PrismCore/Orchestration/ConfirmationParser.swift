//
//  ConfirmationParser.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-08.
//

import Foundation

/// Parses short user responses into confirmation decisions.
public enum ConfirmationDecision: Sendable, Equatable {
    case confirmed
    case denied
    case unclear
}

/// Lightweight parser for yes/no confirmation responses.
public struct ConfirmationParser {
    private static let confirmTokens: Set<String> = [
        "yes", "yeah", "yep", "yup", "sure", "confirm", "confirmed", "ok", "okay", "go", "ahead"
    ]
    private static let denyTokens: Set<String> = [
        "no", "nope", "nah", "cancel", "stop", "never", "dont", "don't", "not"
    ]
    private static let confirmPhrases: [String] = [
        "go ahead",
        "do it",
        "please do",
        "sounds good"
    ]
    private static let denyPhrases: [String] = [
        "don't do that",
        "do not",
        "never mind",
        "no thanks"
    ]

    public static func parse(_ text: String) -> ConfirmationDecision {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return .unclear }

        if confirmPhrases.contains(where: { normalized.contains($0) }) {
            return .confirmed
        }
        if denyPhrases.contains(where: { normalized.contains($0) }) {
            return .denied
        }

        let tokens = tokenize(normalized)
        let hasConfirm = !confirmTokens.intersection(tokens).isEmpty
        let hasDeny = !denyTokens.intersection(tokens).isEmpty

        switch (hasConfirm, hasDeny) {
        case (true, false):
            return .confirmed
        case (false, true):
            return .denied
        default:
            return .unclear
        }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokenize(_ text: String) -> Set<String> {
        let tokens = text.split { character in
            !(character.isLetter || character == "'")
        }
        return Set(tokens.map { $0.replacingOccurrences(of: "'", with: "") })
    }
}
