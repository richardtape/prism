//
//  OrchestrationController.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation
import PrismCore

/// Bridges app state with the PrismCore orchestration pipeline.
final class OrchestrationController {
    private let appState: AppState
    private let pipeline: OrchestrationPipeline
    private let sessionTracker: ConversationSessionTracker?

    init(appState: AppState, pipeline: OrchestrationPipeline, sessionTracker: ConversationSessionTracker? = nil) {
        self.appState = appState
        self.pipeline = pipeline
        self.sessionTracker = sessionTracker
    }

    /// Handles a final transcript if the conversation window is open.
    func handleFinalTranscript(_ text: String) {
        guard appState.conversationState.isOpen else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task { @MainActor in
            appState.assistantStatus = .responding
            appState.lastResponse = nil
        }

        Task {
            do {
                let turns = await sessionTracker?.currentTurns() ?? []
                let input = OrchestrationInput(userText: trimmed, conversationTurns: turns)
                let (response, _) = try await pipeline.run(input: input)
                await MainActor.run {
                    appState.lastResponse = response.message
                    appState.assistantStatus = .listening
                }
                if let sessionTracker {
                    await sessionTracker.recordAssistantResponse(response.message)
                }
            } catch {
                await MainActor.run {
                    let mappedError = LLMErrorMapper.map(error)
                    appState.statusMessage = LLMErrorMapper.fallbackMessage(for: mappedError)
                    appState.assistantStatus = .listening
                }
            }
        }
    }
}
