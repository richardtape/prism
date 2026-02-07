//
//  MemorySessionSummary.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// A summarized session used to generate memory entries.
public struct MemorySessionSummary: Sendable, Equatable {
    public struct Turn: Sendable, Equatable {
        public let userText: String
        public let assistantText: String?
        public let timestamp: Date

        public init(userText: String, assistantText: String?, timestamp: Date) {
            self.userText = userText
            self.assistantText = assistantText
            self.timestamp = timestamp
        }
    }

    public let speakerID: UUID
    public let turns: [Turn]
    public let startedAt: Date
    public let endedAt: Date

    public init(speakerID: UUID, turns: [Turn], startedAt: Date, endedAt: Date) {
        self.speakerID = speakerID
        self.turns = turns
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
