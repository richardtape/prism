//
//  EnrollmentView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import PrismCore
import SwiftUI

/// Onboarding enrollment UI for capturing speaker samples.
struct EnrollmentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var coordinator = EnrollmentCoordinator()
    @State private var priorListeningState: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Speaker Enrollment")
                .font(.title3)

            switch coordinator.flowStep {
            case .intro:
                EnrollmentIntroView(onStart: coordinator.beginAddVoice)
            case .list:
                EnrollmentProfilesView(
                    profiles: coordinator.profiles,
                    onAdd: coordinator.beginAddVoice,
                    onDelete: coordinator.deleteProfile
                )
            case .name:
                EnrollmentNameView(
                    displayName: $coordinator.displayName,
                    statusText: coordinator.statusText,
                    onContinue: coordinator.confirmName,
                    onBack: coordinator.cancelAddVoice
                )
            case .samples:
                EnrollmentSampleView(
                    prompt: coordinator.currentPrompt,
                    promptIndex: coordinator.promptIndex,
                    totalPrompts: coordinator.totalPrompts,
                    isRecording: coordinator.isRecording,
                    sampleCount: coordinator.embeddings.count,
                    statusText: coordinator.statusText,
                    onRecord: coordinator.recordSample,
                    onStartOver: coordinator.restartSamples,
                    onBack: coordinator.cancelAddVoice
                )
            case .completion:
                EnrollmentCompletionView(
                    displayName: coordinator.displayName,
                    statusText: coordinator.statusText,
                    onContinue: coordinator.finishCompletion
                )
            }
        }
        .padding(.top, 8)
        .task {
            coordinator.loadProfiles()
        }
        .onAppear {
            pauseListening()
        }
        .onDisappear {
            coordinator.cancelRecordingIfNeeded()
            restoreListening()
        }
    }

    private func pauseListening() {
        guard priorListeningState == nil else { return }
        priorListeningState = appState.isListening
        appState.isListening = false
    }

    private func restoreListening() {
        guard let priorListeningState else { return }
        appState.isListening = priorListeningState
    }
}

private struct EnrollmentIntroView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enroll your voice so Prism can recognize who is speaking.")
                .foregroundStyle(.secondary)

            Button("Enroll Voice") {
                onStart()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct EnrollmentProfilesView: View {
    let profiles: [SpeakerProfile]
    let onAdd: () -> Void
    let onDelete: (SpeakerProfile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enrolled voices")
                .font(.headline)

            if profiles.isEmpty {
                Text("No voices enrolled yet.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(profiles, id: \.id) { profile in
                        HStack {
                            Text(profile.displayName)
                            Spacer()
                            Button("Delete") {
                                onDelete(profile)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .frame(minHeight: 180)
            }

            Button("Add Voice") {
                onAdd()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct EnrollmentNameView: View {
    @Binding var displayName: String
    let statusText: String
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        let isNameValid = !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        VStack(alignment: .leading, spacing: 12) {
            Text("What is your name?")
                .font(.headline)

            Text("This helps Prism label your voice.")
                .foregroundStyle(.secondary)

            TextField("e.g. Riley", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)

            HStack(spacing: 12) {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)

                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isNameValid)
            }

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EnrollmentSampleView: View {
    let prompt: String
    let promptIndex: Int
    let totalPrompts: Int
    let isRecording: Bool
    let sampleCount: Int
    let statusText: String
    let onRecord: () -> Void
    let onStartOver: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice sample \(min(promptIndex + 1, max(1, totalPrompts))) of \(max(1, totalPrompts))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(prompt)
                .font(.title3)

            Text("The microphone will activate while recording.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(isRecording ? "Recording..." : "Record Sample") {
                    onRecord()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRecording)

                Button("Start Over") {
                    onStartOver()
                }
                .buttonStyle(.bordered)
                .disabled(isRecording)

                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)
                .disabled(isRecording)

                Spacer()

                Text("Samples: \(sampleCount)/\(max(1, totalPrompts))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EnrollmentCompletionView: View {
    let displayName: String
    let statusText: String
    let onContinue: () -> Void

    var body: some View {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? "Your voice" : trimmed

        VStack(alignment: .leading, spacing: 12) {
            Text("Enrollment complete")
                .font(.headline)

            Text("\(resolvedName) is now enrolled.")
                .foregroundStyle(.secondary)

            Button("Continue") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    EnrollmentView()
        .environmentObject(AppState())
        .frame(width: 520)
}
