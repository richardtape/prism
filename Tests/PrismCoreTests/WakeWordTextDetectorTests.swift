//
//  WakeWordTextDetectorTests.swift
//  PrismCoreTests
//
//  Created by Rich Tape on 2026-02-07.
//

import XCTest
@testable import PrismCore

final class WakeWordTextDetectorTests: XCTestCase {
    func testNormalizationCollapsesWhitespaceAndPunctuation() {
        let normalized = WakeWordTextDetector.normalize("  Hey, Prism!!  ")
        XCTAssertEqual(normalized, "hey prism")
    }

    func testDetectsAliasAnywhereAndStripsIt() {
        let config = WakeWordConfig(aliases: ["prism"], sensitivity: 0.6, minConfidence: 0.2)
        let detector = WakeWordTextDetector(config: config)

        let match = detector.detect(in: "Could you start a timer, Prism", confidence: 0.9)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.strippedText, "Could you start a timer")
        XCTAssertEqual(match?.event.source, .text)
    }

    func testDetectsAliasVariant() {
        let config = WakeWordConfig(aliases: ["prison"], sensitivity: 0.6, minConfidence: 0.2)
        let detector = WakeWordTextDetector(config: config)

        let match = detector.detect(in: "Prison open the notes app", confidence: 0.9)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.strippedText, "open the notes app")
    }

    func testConfidenceGateBlocksLowConfidence() {
        let config = WakeWordConfig(aliases: ["prism"], sensitivity: 0.6, minConfidence: 0.8)
        let detector = WakeWordTextDetector(config: config)

        let match = detector.detect(in: "Prism start a timer", confidence: 0.3)
        XCTAssertNil(match)
    }
}
