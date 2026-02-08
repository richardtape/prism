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
        let registry = SkillRegistry(queue: Self.queue, permissionManager: MockPermissionManager())
        let pipeline = OrchestrationPipeline(registry: registry)

        let input = OrchestrationInput(userText: "hello")
        let (response, tools) = try await pipeline.run(input: input)

        XCTAssertEqual(response.message, "Heard: hello")
        XCTAssertTrue(tools.isEmpty)
    }

    func testPipelineExecutesEnabledTool() async throws {
        let registry = SkillRegistry(queue: Self.queue, permissionManager: MockPermissionManager())
        let mock = MockSkill(id: "create_note")
        registry.register(mock)

        let store = SettingsStore(queue: Self.queue)
        try store.writeValue("true", for: SkillRegistry.enabledKey(for: "create_note"))

        let pipeline = OrchestrationPipeline(registry: registry)
        let input = OrchestrationInput(userText: "create a note")
        let (response, tools) = try await pipeline.run(input: input)

        XCTAssertEqual(response.message, "Mocked tool run.")
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools.first?.output.objectValue?["status"], .string("ok"))
        XCTAssertEqual(tools.first?.output.objectValue?["summary"], .string("Mocked tool run."))
    }

    func testPendingConfirmationFlow() async throws {
        let registry = SkillRegistry(queue: Self.queue, permissionManager: MockPermissionManager())
        let mock = ConfirmingSkill(id: "remove_item")
        registry.register(mock)

        let store = SettingsStore(queue: Self.queue)
        try store.writeValue("true", for: SkillRegistry.enabledKey(for: "remove_item"))

        let pipeline = OrchestrationPipeline(registry: registry)
        let firstInput = OrchestrationInput(userText: "create a note")
        let (firstResponse, _) = try await pipeline.run(input: firstInput)

        XCTAssertEqual(firstResponse.message, "Are you sure you want to remove this?")

        let secondInput = OrchestrationInput(userText: "yes")
        let (secondResponse, tools) = try await pipeline.run(input: secondInput)

        XCTAssertEqual(secondResponse.message, "Removed.")
        XCTAssertEqual(tools.first?.output.objectValue?["status"], .string("ok"))
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
            name: "create_note",
            description: "mock",
            parameters: .object(["type": .string("object")])
        ))

        func execute(call: ToolCall) async throws -> SkillResult {
            .ok(summary: "Mocked tool run.")
        }
    }

    private struct ConfirmingSkill: Skill {
        let id: String
        let metadata = SkillMetadata(name: "Confirming", description: "Test")
        let toolSchema = LLMToolDefinition(function: .init(
            name: "remove_item",
            description: "mock",
            parameters: .object(["type": .string("object")])
        ))

        func execute(call: ToolCall) async throws -> SkillResult {
            let args = ToolArguments(arguments: call.arguments)
            if args.bool("confirmed") == true {
                return .ok(summary: "Removed.")
            }
            return .pendingConfirmation(prompt: "Are you sure you want to remove this?")
        }
    }
}
