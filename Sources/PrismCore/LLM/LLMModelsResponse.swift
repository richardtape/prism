//
//  LLMModelsResponse.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Model discovery response for OpenAI-compatible /v1/models.
struct LLMModelsResponse: Codable {
    struct Model: Codable {
        let id: String
    }

    let data: [Model]
}
