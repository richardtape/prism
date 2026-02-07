//
//  SpeakerMatch.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Result of comparing an embedding against stored profiles.
public struct SpeakerMatch: Sendable, Equatable {
    public let profileID: UUID
    public let displayName: String
    public let similarity: Float
    public let threshold: Float

    public init(profileID: UUID, displayName: String, similarity: Float, threshold: Float) {
        self.profileID = profileID
        self.displayName = displayName
        self.similarity = similarity
        self.threshold = threshold
    }

    public var isAboveThreshold: Bool {
        similarity >= threshold
    }
}
