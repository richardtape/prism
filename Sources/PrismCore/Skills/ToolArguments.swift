//
//  ToolArguments.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-08.
//

import Foundation

/// Convenience accessors for tool call argument payloads.
public struct ToolArguments {
    public let values: [String: JSONValue]

    public init(arguments: JSONValue) {
        self.values = arguments.objectValue ?? [:]
    }

    public func string(_ key: String) -> String? {
        guard let value = values[key] else { return nil }
        if case .string(let text) = value {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    public func bool(_ key: String) -> Bool? {
        guard let value = values[key] else { return nil }
        if case .bool(let flag) = value {
            return flag
        }
        return nil
    }
}
