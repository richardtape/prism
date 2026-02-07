//
//  MemorySettingsView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import PrismCore
import SwiftUI

/// Memory settings and entry management UI.
struct MemorySettingsView: View {
    @State private var isMemoryEnabled = false
    @State private var statusText = ""
    @State private var profiles: [SpeakerProfile] = []
    @State private var selectedProfileID: UUID?
    @State private var entries: [MemoryEntry] = []

    var body: some View {
        SettingsSectionContainer(title: "Memory") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
                SettingsToggleRow(
                    title: "Enable memory",
                    subtitle: "Allow Prism to save per-speaker memory notes after conversations.",
                    isOn: $isMemoryEnabled
                )

                GridRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speaker")
                        Text("Choose which speaker's memories to view.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Speaker", selection: $selectedProfileID) {
                        Text("Select a speaker").tag(UUID?.none)
                        ForEach(profiles, id: \.id) { profile in
                            Text(profile.displayName).tag(UUID?.some(profile.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 560)

            if selectedProfileID == nil {
                Text("Select a speaker to view memory entries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if entries.isEmpty {
                Text("No memory entries yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(entries, id: \.id) { entry in
                        MemoryEntryEditor(entry: entry) { updated in
                            saveEntry(updated)
                        } onDelete: {
                            deleteEntry(entry)
                        }
                    }
                }
            }

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            loadSettings()
            loadProfiles()
        }
        .onChange(of: isMemoryEnabled) { _, newValue in
            saveMemoryEnabled(newValue)
        }
        .onChange(of: selectedProfileID) { _, _ in
            loadEntries()
        }
    }

    @MainActor
    private func loadSettings() {
        do {
            let queue = try Database().queue
            let store = SettingsStore(queue: queue)
            let value = try store.readValue(for: SettingsKeys.memoryEnabled)
            isMemoryEnabled = (value == "true")
        } catch {
            statusText = "Unable to load memory settings yet."
        }
    }

    @MainActor
    private func saveMemoryEnabled(_ isEnabled: Bool) {
        do {
            let queue = try Database().queue
            let store = SettingsStore(queue: queue)
            try store.writeValue(isEnabled ? "true" : "false", for: SettingsKeys.memoryEnabled)
            statusText = ""
        } catch {
            statusText = "Unable to save memory setting yet."
        }
    }

    @MainActor
    private func loadProfiles() {
        do {
            let queue = try Database().queue
            let store = SpeakerProfileStore(queue: queue)
            profiles = try store.fetchProfiles()
            if selectedProfileID == nil {
                selectedProfileID = profiles.first?.id
            }
            loadEntries()
        } catch {
            profiles = []
            entries = []
            statusText = "Unable to load speakers yet."
        }
    }

    @MainActor
    private func loadEntries() {
        guard let profileID = selectedProfileID else {
            entries = []
            return
        }
        do {
            let queue = try Database().queue
            let store = MemoryStore(queue: queue)
            entries = try store.fetchEntries(profileID: profileID)
        } catch {
            entries = []
            statusText = "Unable to load memory entries yet."
        }
    }

    @MainActor
    private func saveEntry(_ entry: MemoryEntry) {
        do {
            let queue = try Database().queue
            let store = MemoryStore(queue: queue)
            try store.saveEntry(entry)
            loadEntries()
        } catch {
            statusText = "Unable to save memory entry yet."
        }
    }

    @MainActor
    private func deleteEntry(_ entry: MemoryEntry) {
        do {
            let queue = try Database().queue
            let store = MemoryStore(queue: queue)
            try store.deleteEntry(id: entry.id)
            loadEntries()
        } catch {
            statusText = "Unable to delete memory entry yet."
        }
    }
}

private struct MemoryEntryEditor: View {
    @State private var content: String
    private let entry: MemoryEntry
    private let onSave: (MemoryEntry) -> Void
    private let onDelete: () -> Void

    init(entry: MemoryEntry, onSave: @escaping (MemoryEntry) -> Void, onDelete: @escaping () -> Void) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        _content = State(initialValue: entry.body)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $content)
                .frame(minHeight: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2))
                )

            HStack {
                Button("Save") {
                    let updated = MemoryEntry(
                        id: entry.id,
                        profileID: entry.profileID,
                        body: content,
                        createdAt: entry.createdAt,
                        updatedAt: Date()
                    )
                    onSave(updated)
                }
                .buttonStyle(.borderedProminent)

                Button("Delete") {
                    onDelete()
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("Updated \(formattedDate(entry.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    MemorySettingsView()
}
