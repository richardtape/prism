//
//  SpeakerEmbeddingExtractor.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Abstraction for embedding extraction implementations.
public protocol SpeakerEmbeddingExtractor: Sendable {
    func extractEmbedding(from frames: [AudioFrame]) async throws -> SpeakerEmbedding
}
