//
//  UnknownSpeakerPromptState.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Represents the current unknown speaker prompt state.
struct UnknownSpeakerPromptState: Identifiable {
    let id = UUID()
    let utteranceID: UUID
    let reason: String
}
