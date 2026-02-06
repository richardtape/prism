//
//  SettingsToggleRow.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import SwiftUI

/// Two-column row with aligned label text and a trailing toggle.
struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        GridRow {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

#Preview {
    Grid {
        SettingsToggleRow(
            title: "Example",
            subtitle: "Describes what this toggle controls.",
            isOn: .constant(false)
        )
    }
    .padding()
}
