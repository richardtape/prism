//
//  SettingsWindowView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import SwiftUI

/// Root container for the Settings window tabs.
struct SettingsWindowView: View {
    @State private var selection: SettingsSection = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .frame(minWidth: 200)
        } detail: {
            SettingsDetailView(section: selection)
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

private struct SettingsDetailView: View {
    let section: SettingsSection

    var body: some View {
        switch section {
        case .general:
            GeneralSettingsView()
        case .audio:
            AudioSettingsView()
        case .skills:
            SkillsSettingsView()
        case .memory:
            MemorySettingsView()
        case .ai:
            AISettingsView()
        }
    }
}

#Preview {
    SettingsWindowView()
}
