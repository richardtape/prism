//
//  VADServiceTests.swift
//  PrismCoreTests
//
//  Created by Rich Tape on 2026-02-06.
//

import XCTest
@testable import PrismCore

final class VADServiceTests: XCTestCase {
    func testSpeechStartAfterMinFrames() {
        let configuration = VADConfiguration(rmsThreshold: 0.5, minSpeechFrames: 3, silenceFrames: 2)
        let service = VADService(configuration: configuration)

        let silentFrame = makeFrame(rms: 0.1, index: 0)
        let loudFrame = makeFrame(rms: 0.6, index: 1)

        XCTAssertFalse(service.process(frame: silentFrame).didStartSpeech)
        XCTAssertFalse(service.process(frame: loudFrame).didStartSpeech)
        XCTAssertFalse(service.process(frame: loudFrame).didStartSpeech)
        XCTAssertTrue(service.process(frame: loudFrame).didStartSpeech)
    }

    func testSpeechEndsAfterSilenceFrames() {
        let configuration = VADConfiguration(rmsThreshold: 0.5, minSpeechFrames: 2, silenceFrames: 2)
        let service = VADService(configuration: configuration)

        let loudFrame = makeFrame(rms: 0.7, index: 0)
        let silentFrame = makeFrame(rms: 0.1, index: 1)

        _ = service.process(frame: loudFrame)
        _ = service.process(frame: loudFrame)
        XCTAssertTrue(service.process(frame: loudFrame).isSpeech)

        XCTAssertFalse(service.process(frame: silentFrame).didEndSpeech)
        XCTAssertTrue(service.process(frame: silentFrame).didEndSpeech)
    }

    private func makeFrame(rms: Float, index: Int) -> AudioFrame {
        AudioFrame(samples: [], rms: rms, timestamp: Date(), sampleRate: 16_000, frameIndex: index)
    }
}
