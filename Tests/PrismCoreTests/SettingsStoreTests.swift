//
//  SettingsStoreTests.swift
//  PrismTests
//
//  Created by Rich Tape on 2026-02-06.
//

import GRDB
import XCTest
@testable import PrismCore

@MainActor
final class SettingsStoreTests: XCTestCase {
    private static let queue: DatabaseQueue = {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismSettingsStoreTests")
            .appendingPathExtension("sqlite")

        let queue = try? DatabaseQueue(path: databaseURL.path)
        try? queue?.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS settings (
                    key TEXT PRIMARY KEY NOT NULL,
                    value TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """)
        }
        return queue!
    }()

    private var store: SettingsStore {
        SettingsStore(queue: Self.queue)
    }

    override func setUp() async throws {
        try await super.setUp()
        try await Self.queue.write { db in
            try db.execute(sql: "DELETE FROM settings")
        }
    }

    func testWriteAndReadValue() throws {
        try store.writeValue("enabled", for: "logging.transcripts")

        let value = try store.readValue(for: "logging.transcripts")
        XCTAssertEqual(value, "enabled")
    }

    func testUpdateValueOverwritesExisting() throws {
        try store.writeValue("disabled", for: "logging.transcripts")
        try store.writeValue("enabled", for: "logging.transcripts")

        let value = try store.readValue(for: "logging.transcripts")
        XCTAssertEqual(value, "enabled")
    }
}
