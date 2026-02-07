//
//  MemoryAgent.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Memory agent that generates memory entries after a session completes.
public struct MemoryAgent {
    public init() {}

    public func run(summary: MemorySessionSummary) async throws -> [MemoryEntry] {
        let entries: [MemoryEntry] = summary.turns.compactMap { turn in
            let trimmed = turn.userText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            var body = "User: \(trimmed)"
            if let assistantText = turn.assistantText?.trimmingCharacters(in: .whitespacesAndNewlines), !assistantText.isEmpty {
                body += "\nAssistant: \(assistantText)"
            }

            return MemoryEntry(
                id: UUID(),
                profileID: summary.speakerID,
                body: body,
                createdAt: turn.timestamp,
                updatedAt: turn.timestamp
            )
        }

        return entries
    }
}
