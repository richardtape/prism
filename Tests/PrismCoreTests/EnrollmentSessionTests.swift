//
//  EnrollmentSessionTests.swift
//  PrismCoreTests
//
//  Created by Rich Tape on 2026-02-07.
//

import XCTest
@testable import PrismCore

final class EnrollmentSessionTests: XCTestCase {
    func testEnrollmentProgressCompletesWhenResultProvided() {
        let session = EnrollmentSession(promptIndex: 10, totalPrompts: 10, result: .completed)
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.progress, 1.0, accuracy: 0.0001)
    }

    func testEnrollmentProgressIsBounded() {
        let session = EnrollmentSession(promptIndex: 0, totalPrompts: 0)
        XCTAssertEqual(session.progress, 0.0, accuracy: 0.0001)
        XCTAssertFalse(session.isComplete)
    }

    func testEnrollmentProgressAdvancesWithPromptIndex() {
        let session = EnrollmentSession(promptIndex: 5, totalPrompts: 10)
        XCTAssertEqual(session.progress, 0.5, accuracy: 0.0001)
    }
}
