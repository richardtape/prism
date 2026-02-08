//
//  WakeWordConfig.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Shared configuration used by wake-word detectors.
public struct WakeWordConfig: Sendable, Equatable {
    public let aliases: [String]
    public let sensitivity: Double
    public let minConfidence: Double

    public init(aliases: [String], sensitivity: Double, minConfidence: Double) {
        self.aliases = aliases
        self.sensitivity = Self.clamp01(sensitivity)
        self.minConfidence = Self.clamp01(minConfidence)
    }

    public static func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
