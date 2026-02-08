//
//  WeatherUnits.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-08.
//

import Foundation

/// Temperature unit preferences for WeatherKit output.
public enum WeatherUnits: String, CaseIterable, Sendable {
    case system
    case metric
    case imperial

    public var displayName: String {
        switch self {
        case .system:
            return "System Default"
        case .metric:
            return "Metric (°C)"
        case .imperial:
            return "Imperial (°F)"
        }
    }
}

/// Loads Weather-specific preferences from the settings store.
public struct WeatherSettingsLoader {
    private let store: SettingsStore
    private let unitsKey: String

    public init(store: SettingsStore, unitsKey: String) {
        self.store = store
        self.unitsKey = unitsKey
    }

    public func loadUnits() -> WeatherUnits {
        (try? store.readValue(for: unitsKey))
            .flatMap(WeatherUnits.init(rawValue:)) ?? .system
    }
}
