//
//  VADService.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Configuration values for the simple RMS-based VAD gate.
public struct VADConfiguration: Sendable, Equatable {
    public let rmsThreshold: Float
    public let minSpeechFrames: Int
    public let silenceFrames: Int

    public init(rmsThreshold: Float, minSpeechFrames: Int, silenceFrames: Int) {
        self.rmsThreshold = rmsThreshold
        self.minSpeechFrames = minSpeechFrames
        self.silenceFrames = silenceFrames
    }

    public static let `default` = VADConfiguration(rmsThreshold: 0.02, minSpeechFrames: 3, silenceFrames: 8)
}

/// Outcome of a VAD evaluation for a single audio frame.
public struct VADResult: Sendable, Equatable {
    public let isSpeech: Bool
    public let didStartSpeech: Bool
    public let didEndSpeech: Bool

    public init(isSpeech: Bool, didStartSpeech: Bool, didEndSpeech: Bool) {
        self.isSpeech = isSpeech
        self.didStartSpeech = didStartSpeech
        self.didEndSpeech = didEndSpeech
    }
}

/// Simple stateful VAD implementation based on RMS thresholds and frame counts.
public final class VADService {
    private let configuration: VADConfiguration
    private var speechFrameCount = 0
    private var silenceFrameCount = 0
    private var inSpeech = false

    public init(configuration: VADConfiguration) {
        self.configuration = configuration
    }

    /// Resets the VAD state to its initial idle configuration.
    public func reset() {
        speechFrameCount = 0
        silenceFrameCount = 0
        inSpeech = false
    }

    /// Evaluates a frame and returns the VAD transition result.
    public func process(frame: AudioFrame) -> VADResult {
        let isAboveThreshold = frame.rms >= configuration.rmsThreshold
        if isAboveThreshold {
            speechFrameCount += 1
            silenceFrameCount = 0
        } else {
            silenceFrameCount += 1
            speechFrameCount = 0
        }

        var didStartSpeech = false
        var didEndSpeech = false

        if !inSpeech, speechFrameCount >= configuration.minSpeechFrames {
            inSpeech = true
            didStartSpeech = true
        }

        if inSpeech, silenceFrameCount >= configuration.silenceFrames {
            inSpeech = false
            didEndSpeech = true
            speechFrameCount = 0
        }

        return VADResult(isSpeech: inSpeech, didStartSpeech: didStartSpeech, didEndSpeech: didEndSpeech)
    }
}
