//
//  SettingsStore.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation
import GRDB

/// Persists user settings in the SQLite settings table.
public final class SettingsStore {
    private let queue: DatabaseQueue

    public init(queue: DatabaseQueue) {
        self.queue = queue
    }

    /// Reads a setting value for the given key.
    public func readValue(for key: String) throws -> String? {
        try queue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM settings WHERE key = ?", arguments: [key])
        }
    }

    /// Writes a setting value for the given key, replacing any existing entry.
    public func writeValue(_ value: String, for key: String, date: Date = Date()) throws {
        let timestamp = ISO8601DateFormatter().string(from: date)
        try queue.write { db in
            try db.execute(
                sql: """
                INSERT INTO settings (key, value, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
                """,
                arguments: [key, value, timestamp]
            )
        }
    }
}
