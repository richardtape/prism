//
//  PermissionsChecklistView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import SwiftUI

/// Placeholder checklist for required permissions.
struct PermissionsChecklistView: View {
    @State private var items: [PermissionItem] = [
        PermissionItem(
            name: "Microphone",
            description: "Capture audio for wake word detection and dictation.",
            isEnabled: false
        ),
        PermissionItem(
            name: "Speech Recognition",
            description: "Transcribe speech to text for commands.",
            isEnabled: false
        ),
        PermissionItem(
            name: "Accessibility",
            description: "Control apps and UI elements for automation skills.",
            isEnabled: false
        ),
        PermissionItem(
            name: "Automation",
            description: "Send Apple Events to allowed apps when executing skills.",
            isEnabled: false
        ),
        PermissionItem(
            name: "Reminders",
            description: "Create and update reminders via the skills system.",
            isEnabled: false
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                ForEach($items) { $item in
                    SettingsToggleRow(
                        title: item.name,
                        subtitle: item.description,
                        isOn: $item.isEnabled
                    )
                    .onChange(of: item.isEnabled) { _, newValue in
                        // Phase 01+: request or open the OS-level permission prompt here.
                        // For now, the toggle is purely a UI stub and does not request access.
                        _ = newValue
                    }
                }
            }
        }
    }
}

private struct PermissionItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    var isEnabled: Bool
}

#Preview {
    PermissionsChecklistView()
        .padding()
}
