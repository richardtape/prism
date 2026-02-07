//
//  EnrollmentPrompts.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Fixed prompts used during speaker enrollment.
enum EnrollmentPrompts {
    static func scriptedPrompts(for name: String) -> [String] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? "there" : trimmed

        return [
            "Hey Prism, my name is \(resolvedName).",
            "This is \(resolvedName).",
            "Prism, what's the weather today?",
            "Set a reminder for tomorrow at nine.",
            "Add milk to my shopping list.",
            "How long is my commute right now?",
            "Play a focus playlist.",
            "What's on my calendar this afternoon?",
            "Send a message to Alex: I'm running late.",
            "Turn on the living room lights."
        ]
    }
}
