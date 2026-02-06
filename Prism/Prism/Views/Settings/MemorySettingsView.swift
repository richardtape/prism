//
//  MemorySettingsView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import SwiftUI

/// Memory settings placeholders for later configuration work.
struct MemorySettingsView: View {
    var body: some View {
        SettingsSectionContainer(title: "Memory") {
            Text("Memory settings placeholders will live here.")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MemorySettingsView()
}
