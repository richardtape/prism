//
//  SpeakerIDController.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation
import PrismCore

/// Manages per-utterance speaker ID embedding extraction.
final class SpeakerIDController {
    private let service: SpeakerIDService
    private var extractionTask: Task<Void, Never>?

    /// Callback invoked when an embedding is available for an utterance.
    var onEmbeddingExtracted: ((UUID, SpeakerEmbedding) -> Void)?

    init(extractor: SpeakerEmbeddingExtractor) {
        self.service = SpeakerIDService(extractor: extractor)
    }

    func processUtterance(id: UUID, frames: [AudioFrame]) {
        extractionTask?.cancel()
        extractionTask = Task { [service] in
            guard !frames.isEmpty else { return }
            do {
                let embedding = try await service.extractEmbedding(from: frames)
                await MainActor.run {
                    self.onEmbeddingExtracted?(id, embedding)
                }
            } catch {
                // Stub extractor should not fail; ignore for now.
            }
        }
    }

    func cancelCurrentExtraction() {
        extractionTask?.cancel()
        extractionTask = nil
    }
}
