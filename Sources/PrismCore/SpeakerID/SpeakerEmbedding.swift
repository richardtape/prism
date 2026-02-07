//
//  SpeakerEmbedding.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Represents an extracted speaker embedding vector.
public struct SpeakerEmbedding: Sendable, Equatable {
    public let vector: [Float]
    public let createdAt: Date

    public init(vector: [Float], createdAt: Date = Date()) {
        self.vector = vector
        self.createdAt = createdAt
    }
}
