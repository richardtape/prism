//
//  Agent.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Agent contract for each stage of the orchestration pipeline.
public protocol Agent: Sendable {
    associatedtype Input
    associatedtype Output

    func run(input: Input) async throws -> Output
}
