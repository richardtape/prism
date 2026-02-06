//
//  ConversationManager.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Snapshot describing the current conversation window state.
public struct ConversationState: Sendable, Equatable {
    public let isOpen: Bool
    public let turnsUsed: Int
    public let maxTurns: Int
    public let windowSeconds: TimeInterval
    public let lastActivity: Date?
    public let expiresAt: Date?

    public init(
        isOpen: Bool,
        turnsUsed: Int,
        maxTurns: Int,
        windowSeconds: TimeInterval,
        lastActivity: Date?,
        expiresAt: Date?
    ) {
        self.isOpen = isOpen
        self.turnsUsed = turnsUsed
        self.maxTurns = maxTurns
        self.windowSeconds = windowSeconds
        self.lastActivity = lastActivity
        self.expiresAt = expiresAt
    }

    public static func closed(windowSeconds: TimeInterval, maxTurns: Int) -> ConversationState {
        ConversationState(
            isOpen: false,
            turnsUsed: 0,
            maxTurns: maxTurns,
            windowSeconds: windowSeconds,
            lastActivity: nil,
            expiresAt: nil
        )
    }

    public func timeRemaining(from date: Date = Date()) -> TimeInterval? {
        guard let expiresAt else { return nil }
        return max(0, expiresAt.timeIntervalSince(date))
    }
}

/// Tracks the follow-up conversation window lifecycle and closing phrase behavior.
public actor ConversationManager {
    private let windowSeconds: TimeInterval
    private let maxTurns: Int
    private let closingDetector: ClosingPhraseDetector

    private var isOpen = false
    private var turnsUsed = 0
    private var lastActivity: Date?
    private var expiresAt: Date?
    private var expirationToken = UUID()
    private var expirationTask: Task<Void, Never>?

    private var stateContinuation: AsyncStream<ConversationState>.Continuation?
    public nonisolated let stateStream: AsyncStream<ConversationState>

    public init(windowSeconds: TimeInterval, maxTurns: Int, closingDetector: ClosingPhraseDetector) {
        self.windowSeconds = windowSeconds
        self.maxTurns = maxTurns
        self.closingDetector = closingDetector

        let initialState = ConversationState.closed(windowSeconds: windowSeconds, maxTurns: maxTurns)
        let stream = AsyncStream<ConversationState>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.stateStream = stream.stream
        self.stateContinuation = stream.continuation
        self.stateContinuation?.yield(initialState)
    }

    /// Returns a snapshot of the current conversation state.
    public func snapshot() -> ConversationState {
        ConversationState(
            isOpen: isOpen,
            turnsUsed: turnsUsed,
            maxTurns: maxTurns,
            windowSeconds: windowSeconds,
            lastActivity: lastActivity,
            expiresAt: expiresAt
        )
    }

    /// Opens the conversation window and resets the turn counter.
    public func openWindow() {
        isOpen = true
        turnsUsed = 0
        lastActivity = Date()
        scheduleExpiration(from: lastActivity)
        emitState()
    }

    /// Closes the conversation window and clears counters.
    public func closeWindow() {
        isOpen = false
        turnsUsed = 0
        lastActivity = nil
        expiresAt = nil
        expirationTask?.cancel()
        emitState()
    }

    /// Accepts a transcript event and updates window state when appropriate.
    public func acceptUtterance(event: TranscriptEvent) {
        guard event.isFinal else { return }

        if closingDetector.matches(event.text) {
            closeWindow()
            return
        }

        guard isOpen else { return }

        turnsUsed += 1
        lastActivity = event.timestamp

        if turnsUsed >= maxTurns {
            closeWindow()
            return
        }

        scheduleExpiration(from: event.timestamp)
        emitState()
    }

    private func scheduleExpiration(from date: Date?) {
        guard let date else { return }

        expirationTask?.cancel()
        expirationToken = UUID()
        let token = expirationToken
        let deadline = date.addingTimeInterval(windowSeconds)
        expiresAt = deadline

        expirationTask = Task { [weak self] in
            guard let self else { return }
            let delay = max(0, deadline.timeIntervalSinceNow)
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            await self.expireIfNeeded(token: token)
        }
    }

    private func expireIfNeeded(token: UUID) {
        guard token == expirationToken, isOpen else { return }
        closeWindow()
    }

    private func emitState() {
        stateContinuation?.yield(snapshot())
    }
}
