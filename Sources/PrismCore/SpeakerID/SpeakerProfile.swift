//
//  SpeakerProfile.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Stored speaker profile with enrollment embeddings.
public struct SpeakerProfile: Sendable, Equatable {
    public let id: UUID
    public let displayName: String
    public let threshold: Float
    public let embeddings: [SpeakerEmbedding]

    public init(id: UUID, displayName: String, threshold: Float, embeddings: [SpeakerEmbedding]) {
        self.id = id
        self.displayName = displayName
        self.threshold = threshold
        self.embeddings = embeddings
    }
}
