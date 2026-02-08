//
//  WakeWordTextDetector.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Result of a text-based wake-word match.
public struct WakeWordTextMatch: Sendable, Equatable {
    public let matchedAlias: String
    public let strippedText: String
    public let event: WakeWordEvent

    public init(matchedAlias: String, strippedText: String, event: WakeWordEvent) {
        self.matchedAlias = matchedAlias
        self.strippedText = strippedText
        self.event = event
    }
}

/// Text-based fallback that detects wake-word aliases in transcripts.
public struct WakeWordTextDetector: Sendable {
    private struct Alias: Sendable {
        let original: String
        let normalized: String
    }

    public let config: WakeWordConfig
    private let aliases: [Alias]

    public init(config: WakeWordConfig) {
        self.config = config
        self.aliases = config.aliases
            .map { Alias(original: $0, normalized: Self.normalize($0)) }
            .filter { !$0.normalized.isEmpty }
    }

    /// Returns a match when the text contains a wake-word alias.
    public func detect(in text: String, confidence: Double?, timestamp: Date = Date()) -> WakeWordTextMatch? {
        let normalizedText = Self.normalize(text)
        guard !normalizedText.isEmpty else { return nil }

        if let confidence, confidence < config.minConfidence {
            return nil
        }

        for alias in aliases {
            if containsAlias(normalizedText: normalizedText, alias: alias.normalized) {
                let stripped = strip(alias: alias.normalized, from: text)
                let event = WakeWordEvent(source: .text, confidence: confidence, timestamp: timestamp)
                return WakeWordTextMatch(matchedAlias: alias.original, strippedText: stripped, event: event)
            }
        }

        return nil
    }

    private func containsAlias(normalizedText: String, alias: String) -> Bool {
        if normalizedText == alias {
            return true
        }
        if normalizedText.hasPrefix(alias + " ") {
            return true
        }
        if normalizedText.hasSuffix(" " + alias) {
            return true
        }
        if normalizedText.contains(" " + alias + " ") {
            return true
        }
        return false
    }

    private func strip(alias: String, from text: String) -> String {
        let tokens = alias.split(separator: " ")
        let escaped = tokens.map { NSRegularExpression.escapedPattern(for: String($0)) }
        let pattern = "\\b" + escaped.joined(separator: "\\s+") + "\\b"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let stripped = regex?.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: " ") ?? text
        return clean(stripped)
    }

    private func clean(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }

    /// Lowercases and trims punctuation/whitespace to make alias checks consistent.
    public static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let trimmed = lowered.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        let collapsed = trimmed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed
    }
}
