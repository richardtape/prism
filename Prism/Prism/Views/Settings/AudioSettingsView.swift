//
//  AudioSettingsView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import SwiftUI

/// Audio settings placeholders for later configuration work.
struct AudioSettingsView: View {
    var body: some View {
        SettingsSectionContainer(title: "Audio") {
            Text("Audio settings placeholders will live here.")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AudioSettingsView()
}
