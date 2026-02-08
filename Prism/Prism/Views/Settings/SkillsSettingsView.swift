//
//  SkillsSettingsView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import SwiftUI

/// Skills settings for enabling tool access and reviewing permission status.
struct SkillsSettingsView: View {
    var body: some View {
        SettingsSectionContainer(title: "Skills") {
            Text("Enable skills and grant access to the services Prism controls.")
                .foregroundStyle(.secondary)

            PermissionsChecklistView(showCore: false, showSkills: true)
                .padding(.top, 8)

            Divider()
                .padding(.vertical, 8)

            Text("Weather")
                .font(.headline)

            WeatherUnitsPickerView()

            WeatherAttributionView()
                .padding(.top, 4)
        }
    }
}

#Preview {
    SkillsSettingsView()
}
