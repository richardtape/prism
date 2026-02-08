//
//  ClosingPhraseDetector.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Normalizes transcripts and detects configured closing phrases.
public struct ClosingPhraseDetector: Sendable, Equatable {
    public let phrases: [String]
    public let fillerTokens: Set<String>

    public init(phrases: [String], fillerTokens: [String] = []) {
        self.phrases = phrases.map(Self.normalize).filter { !$0.isEmpty }
        let tokens = fillerTokens
            .flatMap { Self.normalize($0).split(whereSeparator: { $0.isWhitespace }) }
            .map(String.init)
        self.fillerTokens = Set(tokens)
    }

    /// Returns true when the provided text matches a configured closing phrase.
    public func matches(_ text: String) -> Bool {
        let tokens = Self.tokenize(text)
        guard !tokens.isEmpty else { return false }

        for phrase in phrases {
            let phraseTokens = phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard let range = Self.findSubsequence(in: tokens, matching: phraseTokens) else { continue }
            var remaining = tokens
            remaining.removeSubrange(range)
            if remaining.isEmpty {
                return true
            }
            if !fillerTokens.isEmpty, remaining.allSatisfy({ fillerTokens.contains($0) }) {
                return true
            }
        }

        return false
    }

    /// Lowercases and trims punctuation/whitespace to make phrase checks consistent.
    public static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let trimmed = lowered.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        let collapsed = trimmed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed
    }

    private static func tokenize(_ text: String) -> [String] {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return [] }
        return normalized.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    private static func findSubsequence(in tokens: [String], matching phrase: [String]) -> Range<Int>? {
        guard !tokens.isEmpty, !phrase.isEmpty, tokens.count >= phrase.count else { return nil }
        let lastStart = tokens.count - phrase.count
        for index in 0...lastStart {
            if Array(tokens[index..<(index + phrase.count)]) == phrase {
                return index..<(index + phrase.count)
            }
        }
        return nil
    }
}
