//
//  MemoryAgent.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Memory agent placeholder (no-op in Phase 02).
public struct MemoryAgent: Agent {
    public init() {}

    public func run(input: ResponseResult) async throws -> Bool {
        true
    }
}
