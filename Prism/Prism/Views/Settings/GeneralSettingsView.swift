//
//  GeneralSettingsView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import PrismCore
import SwiftUI

/// General settings placeholders for later configuration work.
struct GeneralSettingsView: View {
    @State private var isTranscriptLoggingEnabled = false
    @State private var statusText = ""

    var body: some View {
        SettingsSectionContainer(title: "General") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
                SettingsToggleRow(
                    title: "Allow transcript logging",
                    subtitle: "Stores text transcripts locally when enabled. Audio is never stored.",
                    isOn: $isTranscriptLoggingEnabled
                )

                GridRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Onboarding")
                        Text("Reopen the setup flow to review permissions and enrollment.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Run Onboarding") {
                        NotificationCenter.default.post(name: .openOnboarding, object: nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await loadToggleState()
        }
        .onChange(of: isTranscriptLoggingEnabled) { _, newValue in
            Task { await saveToggleState(newValue) }
        }
    }

    @MainActor
    private func loadToggleState() async {
        do {
            let queue = try Database().queue
            let store = SettingsStore(queue: queue)
            let value = try store.readValue(for: SettingsKeys.transcriptLoggingEnabled)
            isTranscriptLoggingEnabled = (value == "true")
        } catch {
            statusText = "Unable to load logging preference yet."
        }
    }

    @MainActor
    private func saveToggleState(_ isEnabled: Bool) async {
        do {
            let queue = try Database().queue
            let store = SettingsStore(queue: queue)
            try store.writeValue(isEnabled ? "true" : "false", for: SettingsKeys.transcriptLoggingEnabled)
            statusText = ""
        } catch {
            statusText = "Unable to save logging preference yet."
        }
    }
}

#Preview {
    GeneralSettingsView()
}
