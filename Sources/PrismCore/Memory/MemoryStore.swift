//
//  MemoryStore.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation
import GRDB

/// GRDB store for per-speaker memory entries.
public final class MemoryStore {
    private let queue: DatabaseQueue
    private let dateFormatter = ISO8601DateFormatter()

    public init(queue: DatabaseQueue) {
        self.queue = queue
    }

    /// Creates a new memory entry and persists it.
    public func createEntry(profileID: UUID, body: String, date: Date = Date()) throws -> MemoryEntry {
        let entry = MemoryEntry(
            id: UUID(),
            profileID: profileID,
            body: body,
            createdAt: date,
            updatedAt: date
        )
        try saveEntry(entry)
        return entry
    }

    /// Inserts or updates a memory entry.
    public func saveEntry(_ entry: MemoryEntry) throws {
        let createdAt = dateFormatter.string(from: entry.createdAt)
        let updatedAt = dateFormatter.string(from: entry.updatedAt)

        try queue.write { db in
            try db.execute(
                sql: """
                INSERT INTO memory_entries (id, profile_id, body, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    body = excluded.body,
                    updated_at = excluded.updated_at
                """,
                arguments: [
                    entry.id.uuidString,
                    entry.profileID.uuidString,
                    entry.body,
                    createdAt,
                    updatedAt
                ]
            )
        }
    }

    /// Fetches memory entries for a profile.
    public func fetchEntries(profileID: UUID) throws -> [MemoryEntry] {
        try queue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, profile_id, body, created_at, updated_at
                FROM memory_entries
                WHERE profile_id = ?
                ORDER BY updated_at DESC
                """,
                arguments: [profileID.uuidString]
            )

            return rows.map { row in
                let idString: String = row["id"]
                let profileIDString: String = row["profile_id"]
                let body: String = row["body"]
                let createdAtString: String = row["created_at"]
                let updatedAtString: String = row["updated_at"]

                let id = UUID(uuidString: idString) ?? UUID()
                let profileID = UUID(uuidString: profileIDString) ?? UUID()
                let createdAt = dateFormatter.date(from: createdAtString) ?? Date()
                let updatedAt = dateFormatter.date(from: updatedAtString) ?? createdAt

                return MemoryEntry(
                    id: id,
                    profileID: profileID,
                    body: body,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            }
        }
    }

    /// Deletes a memory entry by id.
    public func deleteEntry(id: UUID) throws {
        try queue.write { db in
            try db.execute(sql: "DELETE FROM memory_entries WHERE id = ?", arguments: [id.uuidString])
        }
    }
}
