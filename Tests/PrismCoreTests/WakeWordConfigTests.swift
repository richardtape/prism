//
//  WakeWordConfigTests.swift
//  PrismCoreTests
//
//  Created by Rich Tape on 2026-02-07.
//

import XCTest
@testable import PrismCore

final class WakeWordConfigTests: XCTestCase {
    func testClamp01Bounds() {
        XCTAssertEqual(WakeWordConfig.clamp01(-1), 0)
        XCTAssertEqual(WakeWordConfig.clamp01(0.5), 0.5)
        XCTAssertEqual(WakeWordConfig.clamp01(2.0), 1)
    }
}
