//
//  WakeWordSettingsLoader.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation
import PrismCore

/// Resolved wake-word settings used by the hybrid detection pipeline.
struct WakeWordSettings: Sendable, Equatable {
    let isEnabled: Bool
    let sensitivity: Double
    let minConfidence: Double
    let aliases: [String]
}

/// Loads wake-word settings from the SettingsStore with sensible defaults.
struct WakeWordSettingsLoader {
    private static let defaultAliases = [
        "prism",
        "prison",
        "hey prism",
        "hi prism",
        "okay prism",
        "hey prison",
        "hi prison",
        "okay prison"
    ]

    private static let defaultSensitivity: Double = 0.6
    private static let defaultMinConfidence: Double = 0.6

    @MainActor
    func load() -> WakeWordSettings {
        let defaults = WakeWordSettings(
            isEnabled: true,
            sensitivity: Self.defaultSensitivity,
            minConfidence: Self.defaultMinConfidence,
            aliases: Self.defaultAliases
        )

        do {
            let queue = try Database().queue
            let store = SettingsStore(queue: queue)

            let isEnabled = (try store.readValue(for: SettingsKeys.wakeWordEnabled)) != "false"
            let sensitivity = try store.readValue(for: SettingsKeys.wakeWordSensitivity)
                .flatMap(Double.init) ?? defaults.sensitivity
            let minConfidence = try store.readValue(for: SettingsKeys.wakeWordMinConfidence)
                .flatMap(Double.init) ?? defaults.minConfidence
            let aliasesValue = try store.readValue(for: SettingsKeys.wakeWordAliases)

            let aliases = aliasesValue.map(Self.parseAliases) ?? defaults.aliases

            return WakeWordSettings(
                isEnabled: isEnabled,
                sensitivity: WakeWordConfig.clamp01(sensitivity),
                minConfidence: WakeWordConfig.clamp01(minConfidence),
                aliases: aliases
            )
        } catch {
            return defaults
        }
    }

    static func parseAliases(_ value: String) -> [String] {
        let items = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return items.isEmpty ? defaultAliases : items
    }

}
