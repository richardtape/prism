//
//  AppState.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import Combine
import Foundation

/// Shared app-level state for menu-bar UI and control toggles.
@MainActor
final class AppState: ObservableObject {
    /// True when Prism is actively listening for audio input.
    @Published var isListening: Bool = true
}
