//
//  ConversationSessionTracker.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation
import PrismCore

/// Tracks user/assistant turns within a conversation window.
actor ConversationSessionTracker {
    private struct Session {
        let speakerID: UUID
        var turns: [MemorySessionSummary.Turn]
        let startedAt: Date
        var lastActivity: Date
    }

    private var currentSession: Session?

    func recordUserUtterance(_ text: String, speakerID: UUID?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let speakerID else { return }

        let now = Date()
        if var session = currentSession, session.speakerID == speakerID {
            session.turns.append(.init(userText: trimmed, assistantText: nil, timestamp: now))
            session.lastActivity = now
            currentSession = session
        } else {
            currentSession = Session(
                speakerID: speakerID,
                turns: [.init(userText: trimmed, assistantText: nil, timestamp: now)],
                startedAt: now,
                lastActivity: now
            )
        }
    }

    func recordAssistantResponse(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard var session = currentSession else { return }
        guard !session.turns.isEmpty else { return }

        var lastTurn = session.turns.removeLast()
        if lastTurn.assistantText == nil {
            lastTurn = .init(userText: lastTurn.userText, assistantText: trimmed, timestamp: lastTurn.timestamp)
        }
        session.turns.append(lastTurn)
        session.lastActivity = Date()
        currentSession = session
    }

    func closeSession() -> MemorySessionSummary? {
        guard let session = currentSession else { return nil }
        let summary = MemorySessionSummary(
            speakerID: session.speakerID,
            turns: session.turns,
            startedAt: session.startedAt,
            endedAt: session.lastActivity
        )
        currentSession = nil
        return summary
    }

    func reset() {
        currentSession = nil
    }

    func currentTurns() -> [MemorySessionSummary.Turn] {
        currentSession?.turns ?? []
    }
}
