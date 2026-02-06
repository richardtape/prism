//
//  SettingsSection.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Sidebar sections for the settings window.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case audio = "Audio"
    case skills = "Skills"
    case memory = "Memory"
    case ai = "AI"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .audio:
            return "waveform"
        case .skills:
            return "wrench.and.screwdriver"
        case .memory:
            return "brain.head.profile"
        case .ai:
            return "sparkles"
        }
    }
}
