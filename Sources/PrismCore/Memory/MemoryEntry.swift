//
//  MemoryEntry.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Persistent memory entry associated with a speaker profile.
public struct MemoryEntry: Sendable, Equatable {
    public let id: UUID
    public let profileID: UUID
    public let body: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        profileID: UUID,
        body: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.profileID = profileID
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
