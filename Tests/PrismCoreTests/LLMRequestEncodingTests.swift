//
//  LLMRequestEncodingTests.swift
//  PrismCoreTests
//
//  Created by Rich Tape on 2026-02-06.
//

import XCTest
@testable import PrismCore

final class LLMRequestEncodingTests: XCTestCase {
    func testJSONValueRoundTrip() throws {
        let value: JSONValue = .object([
            "name": .string("prism"),
            "count": .number(3),
            "flags": .array([.bool(true), .bool(false)]),
            "nested": .object(["ok": .null])
        ])

        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testLLMRequestEncodingUsesSnakeCaseKeys() throws {
        let tool = LLMToolDefinition(function: .init(
            name: "create_note",
            description: "Create a note",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object(["type": .string("string")])
                ])
            ])
        ))
        let message = LLMMessage(role: .user, content: "Hello")
        let request = LLMRequest(
            model: "gpt-test",
            messages: [message],
            tools: [tool],
            temperature: 0.3,
            maxTokens: 120,
            stream: true
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["max_tokens"])
        XCTAssertNil(json?["maxTokens"])
        XCTAssertEqual(json?["stream"] as? Bool, true)
    }
}
