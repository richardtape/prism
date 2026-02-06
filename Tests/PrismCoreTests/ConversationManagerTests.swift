//
//  ConversationManagerTests.swift
//  PrismCoreTests
//
//  Created by Rich Tape on 2026-02-06.
//

import XCTest
@testable import PrismCore

final class ConversationManagerTests: XCTestCase {
    func testManualOpenAndMaxTurnsClosesWindow() async {
        let detector = ClosingPhraseDetector(phrases: ["stop"])
        let manager = ConversationManager(windowSeconds: 30, maxTurns: 2, closingDetector: detector)

        await manager.openWindow()
        XCTAssertTrue(await manager.snapshot().isOpen)

        await manager.acceptUtterance(event: makeEvent(text: "hello"))
        XCTAssertTrue(await manager.snapshot().isOpen)
        XCTAssertEqual(await manager.snapshot().turnsUsed, 1)

        await manager.acceptUtterance(event: makeEvent(text: "second"))
        XCTAssertFalse(await manager.snapshot().isOpen)
    }

    func testClosingPhraseEndsWindow() async {
        let detector = ClosingPhraseDetector(phrases: ["stop"])
        let manager = ConversationManager(windowSeconds: 30, maxTurns: 5, closingDetector: detector)

        await manager.openWindow()
        await manager.acceptUtterance(event: makeEvent(text: "please stop"))
        XCTAssertFalse(await manager.snapshot().isOpen)
    }

    func testWindowExpiresAfterInactivity() async {
        let detector = ClosingPhraseDetector(phrases: [])
        let manager = ConversationManager(windowSeconds: 0.05, maxTurns: 5, closingDetector: detector)

        await manager.openWindow()
        XCTAssertTrue(await manager.snapshot().isOpen)

        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(await manager.snapshot().isOpen)
    }

    private func makeEvent(text: String) -> TranscriptEvent {
        TranscriptEvent(text: text, isFinal: true, confidence: nil, timestamp: Date(), utteranceID: UUID())
    }
}
