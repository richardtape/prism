//
//  MemoryCoordinator.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation
import GRDB
import PrismCore

/// Handles the memory agent lifecycle and persistence.
final class MemoryCoordinator {
    private let agent = MemoryAgent()
    private let memoryStore: MemoryStore
    private let settingsStore: SettingsStore

    init(queue: DatabaseQueue) {
        self.memoryStore = MemoryStore(queue: queue)
        self.settingsStore = SettingsStore(queue: queue)
    }

    func handleSessionSummary(_ summary: MemorySessionSummary) {
        guard isMemoryEnabled() else { return }

        Task {
            do {
                let entries = try await agent.run(summary: summary)
                for entry in entries {
                    try memoryStore.saveEntry(entry)
                }
            } catch {
                // Memory is best-effort for now.
            }
        }
    }

    private func isMemoryEnabled() -> Bool {
        do {
            let value = try settingsStore.readValue(for: SettingsKeys.memoryEnabled)
            return value == "true"
        } catch {
            return false
        }
    }
}
