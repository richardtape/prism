//
//  SettingsKeys.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Centralized keys for settings values stored in SQLite.
enum SettingsKeys {
    static let transcriptLoggingEnabled = "logging.transcripts.enabled"
    static let vadThreshold = "audio.vad.threshold"
    static let vadMinSpeechFrames = "audio.vad.minSpeechFrames"
    static let vadSilenceFrames = "audio.vad.silenceFrames"
    static let conversationWindowSeconds = "conversation.windowSeconds"
    static let conversationMaxTurns = "conversation.maxTurns"
    static let conversationClosingPhrases = "conversation.closingPhrases"
    static let speakerIdMatchThreshold = "speakerId.matchThreshold"
    static let memoryEnabled = "memory.enabled"
    static let skillsEnabledPrefix = "skills."
}
