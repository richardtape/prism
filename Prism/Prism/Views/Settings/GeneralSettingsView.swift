//
//  GeneralSettingsView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import GRDB
import PrismCore
import SwiftUI

/// General settings placeholders for later configuration work.
struct GeneralSettingsView: View {
    @State private var isTranscriptLoggingEnabled = false
    @State private var statusText = ""
    @State private var showResetAlert = false

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

                GridRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset App Settings")
                        Text("Clears stored preferences and returns Prism to defaults.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Reset Settings") {
                        showResetAlert = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
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
        .alert("Reset Prism settings?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                Task { await resetAllSettings() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears stored preferences and will require reconfiguring Prism.")
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

    @MainActor
    private func resetAllSettings() async {
        do {
            let queue = try Database().queue
            try await queue.write { db in
                try db.execute(sql: "DELETE FROM settings")
                try db.execute(sql: "DELETE FROM memory_entries")
                try db.execute(sql: "DELETE FROM speaker_embeddings")
                try db.execute(sql: "DELETE FROM speaker_profiles")
            }
            if let configURL = try? ConfigStore.defaultLocation() {
                try? ConfigStore(fileURL: configURL).clear()
            }
            UserDefaults.standard.removeObject(forKey: "onboarding.hasShown")

            isTranscriptLoggingEnabled = false
            statusText = "Settings reset. Reopen onboarding if needed."
        } catch {
            statusText = "Unable to reset settings yet."
        }
    }
}

#Preview {
    GeneralSettingsView()
}
