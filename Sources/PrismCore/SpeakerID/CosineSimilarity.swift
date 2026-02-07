//
//  CosineSimilarity.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Computes cosine similarity for embedding comparisons.
public enum CosineSimilarity {
    public static func compute(_ lhs: [Float], _ rhs: [Float]) -> Float? {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return nil }

        var dot: Float = 0
        var lhsNorm: Float = 0
        var rhsNorm: Float = 0

        for index in lhs.indices {
            let left = lhs[index]
            let right = rhs[index]
            dot += left * right
            lhsNorm += left * left
            rhsNorm += right * right
        }

        let denominator = sqrt(lhsNorm) * sqrt(rhsNorm)
        guard denominator > 0 else { return nil }
        return dot / denominator
    }
}
