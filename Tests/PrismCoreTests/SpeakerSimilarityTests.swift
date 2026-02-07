//
//  SpeakerSimilarityTests.swift
//  PrismCoreTests
//
//  Created by Rich Tape on 2026-02-07.
//

import XCTest
@testable import PrismCore

final class SpeakerSimilarityTests: XCTestCase {
    func testCosineSimilarityMatchesIdenticalVectors() {
        let vector: [Float] = [0.2, 0.4, 0.6]
        let similarity = CosineSimilarity.compute(vector, vector)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.0001)
    }

    func testCosineSimilarityOrthogonalVectors() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [0, 1, 0]
        let similarity = CosineSimilarity.compute(a, b)
        XCTAssertEqual(similarity, 0.0, accuracy: 0.0001)
    }

    func testMatchRespectsThresholdFallback() {
        let embedding = SpeakerEmbedding(vector: [1, 0, 0])
        let profile = SpeakerProfile(
            id: UUID(),
            displayName: "Casey",
            threshold: 0,
            embeddings: [SpeakerEmbedding(vector: [1, 0, 0])]
        )

        let service = SpeakerIDService(extractor: StubExtractor())
        let match = service.match(embedding: embedding, against: [profile], defaultThreshold: 0.8)

        XCTAssertNotNil(match)
        XCTAssertEqual(match?.threshold, 0.8, accuracy: 0.0001)
        XCTAssertEqual(match?.similarity, 1.0, accuracy: 0.0001)
    }

    private struct StubExtractor: SpeakerEmbeddingExtractor {
        func extractEmbedding(from frames: [AudioFrame]) async throws -> SpeakerEmbedding {
            SpeakerEmbedding(vector: [1, 0, 0])
        }
    }
}
