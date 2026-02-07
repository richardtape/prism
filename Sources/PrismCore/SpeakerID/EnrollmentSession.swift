//
//  EnrollmentSession.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Outcome of an enrollment session.
public enum EnrollmentResult: Sendable, Equatable {
    case completed
    case failed(reason: String)
}

/// Progress snapshot for a speaker enrollment session.
public struct EnrollmentSession: Sendable, Equatable {
    public let promptIndex: Int
    public let totalPrompts: Int
    public let progress: Double
    public let result: EnrollmentResult?

    public init(promptIndex: Int, totalPrompts: Int, result: EnrollmentResult? = nil) {
        self.promptIndex = promptIndex
        self.totalPrompts = max(1, totalPrompts)
        self.progress = min(max(Double(promptIndex) / Double(self.totalPrompts), 0), 1)
        self.result = result
    }

    public var isComplete: Bool {
        result != nil
    }
}
