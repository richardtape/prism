//
//  AudioFrame.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// A lightweight audio frame used for VAD and speech pipeline processing.
public struct AudioFrame: Sendable, Equatable {
    public let samples: [Float]
    public let rms: Float
    public let timestamp: Date
    public let sampleRate: Double
    public let frameIndex: Int

    public init(samples: [Float], rms: Float, timestamp: Date, sampleRate: Double, frameIndex: Int) {
        self.samples = samples
        self.rms = rms
        self.timestamp = timestamp
        self.sampleRate = sampleRate
        self.frameIndex = frameIndex
    }
}
