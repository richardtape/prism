//
//  ClosingPhraseDetectorTests.swift
//  PrismCoreTests
//
//  Created by Rich Tape on 2026-02-07.
//

import XCTest
@testable import PrismCore

final class ClosingPhraseDetectorTests: XCTestCase {
    func testExactClosingPhraseMatches() {
        let detector = ClosingPhraseDetector(phrases: ["thanks"])
        XCTAssertTrue(detector.matches("thanks"))
        XCTAssertTrue(detector.matches("Thanks!"))
    }

    func testClosingPhraseWithFillerMatches() {
        let detector = ClosingPhraseDetector(phrases: ["thanks"], fillerTokens: ["ok"])
        XCTAssertTrue(detector.matches("ok thanks"))
    }

    func testClosingPhraseWithFollowUpDoesNotMatch() {
        let detector = ClosingPhraseDetector(phrases: ["thanks"], fillerTokens: ["ok"])
        XCTAssertFalse(detector.matches("ok thanks and what color are those flowers"))
    }
}
