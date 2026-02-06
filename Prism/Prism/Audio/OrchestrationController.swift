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

    init(appState: AppState, pipeline: OrchestrationPipeline) {
        self.appState = appState
        self.pipeline = pipeline
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
                let input = OrchestrationInput(userText: trimmed)
                let (response, _) = try await pipeline.run(input: input)
                await MainActor.run {
                    appState.lastResponse = response.message
                    appState.assistantStatus = .listening
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
