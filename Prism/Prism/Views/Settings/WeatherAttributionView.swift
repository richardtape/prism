//
//  WeatherAttributionView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-08.
//

import SwiftUI
#if canImport(WeatherKit)
import WeatherKit
#endif

/// Displays WeatherKit attribution text in Settings.
struct WeatherAttributionView: View {
    @State private var attributionText = "Weather data provided by Apple Weather."
    @State private var legalURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(attributionText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let legalURL {
                Link("Weather data sources and legal", destination: legalURL)
                    .font(.caption)
            }
        }
        .task {
            await loadAttribution()
        }
    }

    @MainActor
    private func loadAttribution() async {
        #if canImport(WeatherKit)
        if #available(macOS 13.0, *) {
            do {
                let attribution = try await WeatherService.shared.attribution
                attributionText = "Weather data provided by \(attribution.serviceName)."
                legalURL = attribution.legalPageURL
            } catch {
                attributionText = "Weather data provided by Apple Weather."
                legalURL = nil
            }
        }
        #endif
    }
}

#Preview {
    WeatherAttributionView()
        .padding()
}
