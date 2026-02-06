//
//  LLMStreamParserTests.swift
//  PrismCoreTests
//
//  Created by Rich Tape on 2026-02-06.
//

import XCTest
@testable import PrismCore

final class LLMStreamParserTests: XCTestCase {
    func testParsesTokenEvents() {
        let parser = LLMStreamParser()
        let lines = [
            "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}",
            "data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}",
            "data: [DONE]"
        ]

        let events = parser.parse(lines: lines)
        XCTAssertEqual(events, [.token("Hello"), .token(" world"), .done])
    }

    func testParsesToolCallEvents() {
        let parser = LLMStreamParser()
        let lines = [
            "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_1\",\"type\":\"function\",\"function\":{\"name\":\"ping\",\"arguments\":{\"value\":\"ok\"}}}]}}]}"
        ]

        let events = parser.parse(lines: lines)
        XCTAssertEqual(events.count, 1)
        guard case let .toolCall(call) = events.first else {
            XCTFail("Expected tool call event")
            return
        }
        XCTAssertEqual(call.function.name, "ping")
        XCTAssertEqual(call.function.arguments.objectValue?["value"], .string("ok"))
    }
}
