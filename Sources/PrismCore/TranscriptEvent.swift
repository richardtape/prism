//
//  TranscriptEvent.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Represents a streaming speech recognition update.
public struct TranscriptEvent: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool
    public let confidence: Double?
    public let timestamp: Date
    public let utteranceID: UUID

    public init(text: String, isFinal: Bool, confidence: Double?, timestamp: Date, utteranceID: UUID) {
        self.text = text
        self.isFinal = isFinal
        self.confidence = confidence
        self.timestamp = timestamp
        self.utteranceID = utteranceID
    }
}
