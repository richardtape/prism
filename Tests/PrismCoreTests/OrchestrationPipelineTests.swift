//
//  OrchestrationPipelineTests.swift
//  PrismCoreTests
//
//  Created by Rich Tape on 2026-02-06.
//

import GRDB
import XCTest
@testable import PrismCore

final class OrchestrationPipelineTests: XCTestCase {
    private static let queue: DatabaseQueue = {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismOrchestrationTests")
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

    func testPipelineReturnsResponse() async throws {
        let registry = SkillRegistry(queue: Self.queue)
        let pipeline = OrchestrationPipeline(registry: registry)

        let input = OrchestrationInput(userText: "hello")
        let (response, tools) = try await pipeline.run(input: input)

        XCTAssertEqual(response.message, "Heard: hello")
        XCTAssertTrue(tools.isEmpty)
    }

    func testPipelineExecutesEnabledTool() async throws {
        let registry = SkillRegistry(queue: Self.queue)
        let mock = MockSkill(id: "create_note")
        registry.register(mock)

        let store = SettingsStore(queue: Self.queue)
        try store.writeValue("true", for: SkillRegistry.enabledKey(for: "create_note"))

        let pipeline = OrchestrationPipeline(registry: registry)
        let input = OrchestrationInput(userText: "create a note")
        let (_, tools) = try await pipeline.run(input: input)

        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools.first?.output.objectValue?["ok"], .bool(true))
    }

    private struct MockSkill: Skill {
        let id: String
        let metadata = SkillMetadata(name: "Mock", description: "Test")
        let toolSchema = LLMToolDefinition(function: .init(
            name: "create_note",
            description: "mock",
            parameters: .object(["type": .string("object")])
        ))

        func execute(call: ToolCall) async throws -> ToolResult {
            ToolResult(callID: call.id, output: .object(["ok": .bool(true)]))
        }
    }
}
