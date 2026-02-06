//
//  AppState.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import Combine
import Foundation
import PrismCore

/// Shared app-level state for menu-bar UI and control toggles.
@MainActor
final class AppState: ObservableObject {
    /// High-level status representing the assistant's current activity.
    enum AssistantStatus: String {
        case listening
        case processing
        case responding
        case paused

        var displayName: String {
            switch self {
            case .listening:
                return "Listening"
            case .processing:
                return "Processing"
            case .responding:
                return "Responding"
            case .paused:
                return "Paused"
            }
        }
    }

    /// True when Prism is actively listening for audio input.
    @Published var isListening: Bool = true

    /// Current assistant status for UI display.
    @Published var assistantStatus: AssistantStatus = .listening

    /// Normalized audio level meter (0...1).
    @Published var audioLevel: Double = 0

    /// Current conversation window state.
    @Published var conversationState: ConversationState = .closed(windowSeconds: 15, maxTurns: 5)

    /// Most recent transcript update, if any.
    @Published var lastTranscript: String?

    /// Status text for errors or informational messages.
    @Published var statusMessage: String = ""

    /// Callback to open a conversation window manually.
    var onOpenConversationWindow: (() -> Void)?

    func openConversationWindow() {
        onOpenConversationWindow?()
    }
}
