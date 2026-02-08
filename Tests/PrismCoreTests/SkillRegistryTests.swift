//
//  SkillRegistryTests.swift
//  PrismCoreTests
//
//  Created by Rich Tape on 2026-02-06.
//

import GRDB
import XCTest
@testable import PrismCore

final class SkillRegistryTests: XCTestCase {
    private static let queue: DatabaseQueue = {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismSkillRegistryTests")
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

    override func setUp() async throws {
        try await super.setUp()
        try await Self.queue.write { db in
            try db.execute(sql: "DELETE FROM settings")
        }
    }

    func testEnabledSkillsRespectSettings() throws {
        let registry = SkillRegistry(queue: Self.queue, permissionManager: MockPermissionManager())
        let skillA = MockSkill(id: "alpha")
        let skillB = MockSkill(id: "beta")

        registry.register(skillA)
        registry.register(skillB)

        let store = SettingsStore(queue: Self.queue)
        try store.writeValue("true", for: SkillRegistry.enabledKey(for: "alpha"))
        try store.writeValue("false", for: SkillRegistry.enabledKey(for: "beta"))

        let enabled = registry.enabledSkills()
        XCTAssertEqual(enabled.map { $0.id }, ["alpha"])
    }

    private struct MockPermissionManager: PermissionManaging {
        func status(for permission: SkillPermission) -> PermissionStatus {
            .authorized
        }

        func requestAccess(for permission: SkillPermission) async -> PermissionStatus {
            .authorized
        }
    }

    private struct MockSkill: Skill {
        let id: String
        let metadata = SkillMetadata(name: "Mock", description: "Test")
        let toolSchema = LLMToolDefinition(function: .init(
            name: "mock",
            description: "mock",
            parameters: .object(["type": .string("object")])
        ))

        func execute(call: ToolCall) async throws -> SkillResult {
            .ok(summary: "Mock")
        }
    }
}
