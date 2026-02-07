//
//  MemoryStoreTests.swift
//  PrismCoreTests
//
//  Created by Rich Tape on 2026-02-07.
//

import GRDB
import XCTest
@testable import PrismCore

final class MemoryStoreTests: XCTestCase {
    private var queue: DatabaseQueue!
    private var store: MemoryStore!

    override func setUp() async throws {
        try await super.setUp()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismMemoryTests")
            .appendingPathExtension("sqlite")
        queue = try DatabaseQueue(path: url.path)
        store = MemoryStore(queue: queue)

        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS memory_entries (
                    id TEXT PRIMARY KEY NOT NULL,
                    profile_id TEXT NOT NULL,
                    body TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """)
        }
    }

    func testCreateFetchAndDeleteEntry() async throws {
        let profileID = UUID()
        let entry = try store.createEntry(profileID: profileID, body: "User: hello")

        let fetched = try store.fetchEntries(profileID: profileID)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.body, "User: hello")

        try store.deleteEntry(id: entry.id)
        let remaining = try store.fetchEntries(profileID: profileID)
        XCTAssertTrue(remaining.isEmpty)
    }
}
