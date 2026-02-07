//
//  StubSpeakerEmbeddingModel.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation
import PrismCore

/// Deterministic stub embedding extractor until a Core ML model is integrated.
struct StubSpeakerEmbeddingModel: SpeakerEmbeddingExtractor {
    private let embeddingSize: Int = 16

    func extractEmbedding(from frames: [AudioFrame]) async throws -> SpeakerEmbedding {
        let summary = summarize(frames: frames)
        let vector = buildVector(from: summary, length: embeddingSize)
        return SpeakerEmbedding(vector: vector)
    }

    private func summarize(frames: [AudioFrame]) -> (Float, Float, Float) {
        guard !frames.isEmpty else { return (0, 0, 0) }
        let rmsValues = frames.map { $0.rms }
        let mean = rmsValues.reduce(0, +) / Float(rmsValues.count)
        let variance = rmsValues.reduce(0, { $0 + pow($1 - mean, 2) }) / Float(rmsValues.count)
        let sampleRate = Float(frames.first?.sampleRate ?? 0)
        return (mean, variance, sampleRate)
    }

    private func buildVector(from summary: (Float, Float, Float), length: Int) -> [Float] {
        var vector: [Float] = []
        vector.reserveCapacity(length)

        let (mean, variance, sampleRate) = summary
        let seedValues: [Float] = [mean, variance, sampleRate / 48_000]

        for index in 0..<length {
            let seed = seedValues[index % seedValues.count]
            let value = sin(seed * Float(index + 1) * 3.14159)
            vector.append(value)
        }

        return vector
    }
}
