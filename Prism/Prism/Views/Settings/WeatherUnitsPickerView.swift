//
//  WeatherUnitsPickerView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-08.
//

import PrismCore
import SwiftUI

/// Picker for configuring the preferred temperature units used by WeatherKit.
struct WeatherUnitsPickerView: View {
    @State private var selectedUnits: WeatherUnits = .system
    @State private var statusText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Units")
                        Text("Choose how temperatures are displayed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Units", selection: $selectedUnits) {
                        ForEach(WeatherUnits.allCases, id: \.rawValue) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 560)

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            loadUnits()
        }
        .onChange(of: selectedUnits) { _, newValue in
            saveUnits(newValue)
        }
    }

    @MainActor
    private func loadUnits() {
        do {
            let queue = try Database().queue
            let store = SettingsStore(queue: queue)
            let loader = WeatherSettingsLoader(store: store, unitsKey: SettingsKeys.weatherUnits)
            selectedUnits = loader.loadUnits()
            statusText = ""
        } catch {
            statusText = "Unable to load weather unit preferences yet."
        }
    }

    @MainActor
    private func saveUnits(_ units: WeatherUnits) {
        do {
            let queue = try Database().queue
            let store = SettingsStore(queue: queue)
            try store.writeValue(units.rawValue, for: SettingsKeys.weatherUnits)
            statusText = ""
        } catch {
            statusText = "Unable to save weather unit preferences yet."
        }
    }
}

#Preview {
    WeatherUnitsPickerView()
        .padding()
}
