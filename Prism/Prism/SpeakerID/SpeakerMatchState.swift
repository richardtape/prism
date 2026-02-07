//
//  SpeakerMatchState.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation
import PrismCore

/// Tracks whether an utterance produced a match or not.
enum SpeakerMatchState: Equatable {
    case matched(SpeakerMatch)
    case noMatch
}
