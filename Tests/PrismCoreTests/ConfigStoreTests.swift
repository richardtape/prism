//
//  ConfigStoreTests.swift
//  PrismTests
//
//  Created by Rich Tape on 2026-02-06.
//

import XCTest
@testable import PrismCore

final class ConfigStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        let base = FileManager.default.temporaryDirectory
        tempDirectory = base.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    func testSaveAndLoadConfig() throws {
        let fileURL = tempDirectory.appendingPathComponent("config.json")
        let store = ConfigStore(fileURL: fileURL)
        let config = LLMConfig(endpoint: "http://localhost:8000", apiKey: "test-key")

        try store.save(config)
        let loaded = try store.load()

        XCTAssertEqual(loaded, config)
    }

    func testClearRemovesConfig() throws {
        let fileURL = tempDirectory.appendingPathComponent("config.json")
        let store = ConfigStore(fileURL: fileURL)
        let config = LLMConfig(endpoint: "http://localhost:8000", apiKey: "test-key")

        try store.save(config)
        try store.clear()

        let loaded = try store.load()
        XCTAssertNil(loaded)
    }
}
