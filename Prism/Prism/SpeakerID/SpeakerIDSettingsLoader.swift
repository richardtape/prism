//
//  SpeakerIDSettingsLoader.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation
import PrismCore

/// Loads speaker ID settings from the SettingsStore.
struct SpeakerIDSettings {
    let matchThreshold: Float
}

struct SpeakerIDSettingsLoader {
    private let defaultThreshold: Float = 0.75

    func load() -> SpeakerIDSettings {
        do {
            let queue = try Database().queue
            let store = SettingsStore(queue: queue)
            let thresholdValue = try store.readValue(for: SettingsKeys.speakerIdMatchThreshold)
            let threshold = thresholdValue.flatMap(Float.init) ?? defaultThreshold
            return SpeakerIDSettings(matchThreshold: threshold)
        } catch {
            return SpeakerIDSettings(matchThreshold: defaultThreshold)
        }
    }
}
