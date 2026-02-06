//
//  AudioSettingsLoader.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation
import PrismCore

/// Resolved audio-related settings used to configure the Phase 01 pipeline.
struct AudioSettings {
    let vadConfiguration: VADConfiguration
    let conversationWindowSeconds: TimeInterval
    let conversationMaxTurns: Int
    let closingPhrases: [String]
}

/// Loads audio settings from the SettingsStore with sensible defaults.
struct AudioSettingsLoader {
    private static let defaultClosingPhrases = [
        "thank you",
        "thanks",
        "cancel",
        "never mind",
        "stop",
        "that's all"
    ]

    func load() -> AudioSettings {
        let defaults = AudioSettings(
            vadConfiguration: .default,
            conversationWindowSeconds: 15,
            conversationMaxTurns: 5,
            closingPhrases: Self.defaultClosingPhrases
        )

        do {
            let queue = try Database().queue
            let store = SettingsStore(queue: queue)

            let threshold = try store.readValue(for: SettingsKeys.vadThreshold).flatMap(Float.init) ?? defaults.vadConfiguration.rmsThreshold
            let minSpeechFrames = try store.readValue(for: SettingsKeys.vadMinSpeechFrames).flatMap(Int.init) ?? defaults.vadConfiguration.minSpeechFrames
            let silenceFrames = try store.readValue(for: SettingsKeys.vadSilenceFrames).flatMap(Int.init) ?? defaults.vadConfiguration.silenceFrames

            let windowSeconds = try store.readValue(for: SettingsKeys.conversationWindowSeconds).flatMap(Double.init) ?? defaults.conversationWindowSeconds
            let maxTurns = try store.readValue(for: SettingsKeys.conversationMaxTurns).flatMap(Int.init) ?? defaults.conversationMaxTurns

            let phrases = try store.readValue(for: SettingsKeys.conversationClosingPhrases)
                .map { value in
                    value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                } ?? defaults.closingPhrases

            return AudioSettings(
                vadConfiguration: VADConfiguration(
                    rmsThreshold: threshold,
                    minSpeechFrames: max(1, minSpeechFrames),
                    silenceFrames: max(1, silenceFrames)
                ),
                conversationWindowSeconds: max(1, windowSeconds),
                conversationMaxTurns: max(1, maxTurns),
                closingPhrases: phrases.filter { !$0.isEmpty }
            )
        } catch {
            return defaults
        }
    }
}
