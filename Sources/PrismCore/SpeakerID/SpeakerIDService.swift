//
//  SpeakerIDService.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Coordinates embedding extraction and matching logic.
public struct SpeakerIDService: Sendable {
    private let extractor: SpeakerEmbeddingExtractor

    public init(extractor: SpeakerEmbeddingExtractor) {
        self.extractor = extractor
    }

    /// Extracts an embedding for the supplied audio frames.
    public func extractEmbedding(from frames: [AudioFrame]) async throws -> SpeakerEmbedding {
        try await extractor.extractEmbedding(from: frames)
    }

    /// Placeholder match routine (implemented in Phase 03 Step 4).
    public func match(embedding: SpeakerEmbedding, against profiles: [SpeakerProfile], defaultThreshold: Float) -> SpeakerMatch? {
        guard !profiles.isEmpty else { return nil }

        var bestMatch: SpeakerMatch?

        for profile in profiles {
            let threshold = profile.threshold
            for candidate in profile.embeddings {
                guard let similarity = CosineSimilarity.compute(embedding.vector, candidate.vector) else { continue }
                if let currentBest = bestMatch {
                    if similarity > currentBest.similarity {
                        bestMatch = SpeakerMatch(profileID: profile.id, displayName: profile.displayName, similarity: similarity, threshold: threshold)
                    }
                } else {
                    bestMatch = SpeakerMatch(profileID: profile.id, displayName: profile.displayName, similarity: similarity, threshold: threshold)
                }
            }
        }

        guard let bestMatch else { return nil }
        let appliedThreshold = bestMatch.threshold > 0 ? bestMatch.threshold : defaultThreshold
        return SpeakerMatch(
            profileID: bestMatch.profileID,
            displayName: bestMatch.displayName,
            similarity: bestMatch.similarity,
            threshold: appliedThreshold
        )
    }
}
