//
//  UnknownSpeakerPromptView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import PrismCore
import SwiftUI

/// Prompts the user to identify an unknown speaker.
struct UnknownSpeakerPromptView: View {
    let profiles: [SpeakerProfile]
    let onSelect: (SpeakerProfile) -> Void
    let onEnrollNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who is speaking?")
                .font(.headline)

            Text("Select a known voice or enroll a new one.")
                .foregroundStyle(.secondary)

            if profiles.isEmpty {
                Text("No enrolled voices found.")
                    .foregroundStyle(.secondary)
            } else {
                List(profiles, id: \.id) { profile in
                    Button(profile.displayName) {
                        onSelect(profile)
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 180)
            }

            HStack {
                Button("Enroll New Voice") {
                    onEnrollNew()
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }
}

#Preview {
    UnknownSpeakerPromptView(
        profiles: [SpeakerProfile(id: UUID(), displayName: "Jordan", threshold: 0.8, embeddings: [])],
        onSelect: { _ in },
        onEnrollNew: {}
    )
}
