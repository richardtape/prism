//
//  WakeWordEvent.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Origin of a wake-word detection event.
public enum WakeWordSource: String, Sendable, Equatable {
    case acoustic
    case text
}

/// Event describing a wake-word detection.
public struct WakeWordEvent: Sendable, Equatable {
    public let source: WakeWordSource
    public let confidence: Double?
    public let timestamp: Date

    public init(source: WakeWordSource, confidence: Double?, timestamp: Date) {
        self.source = source
        self.confidence = confidence
        self.timestamp = timestamp
    }
}
