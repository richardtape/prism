//
//  LLMToolDefinition.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Tool schema definition compatible with OpenAI tool specifications.
public struct LLMToolDefinition: Codable, Sendable, Equatable {
    public let type: String
    public let function: Function

    public struct Function: Codable, Sendable, Equatable {
        public let name: String
        public let description: String
        public let parameters: JSONValue

        public init(name: String, description: String, parameters: JSONValue) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
    }

    public init(type: String = "function", function: Function) {
        self.type = type
        self.function = function
    }
}
