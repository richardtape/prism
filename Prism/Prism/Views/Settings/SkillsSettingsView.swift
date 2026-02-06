//
//  SkillsSettingsView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import SwiftUI

/// Skills settings placeholders for later configuration work.
struct SkillsSettingsView: View {
    var body: some View {
        SettingsSectionContainer(title: "Skills") {
            Text("Skill settings placeholders will live here.")
                .foregroundStyle(.secondary)

            PermissionsChecklistView()
                .padding(.top, 8)
        }
    }
}

#Preview {
    SkillsSettingsView()
}
