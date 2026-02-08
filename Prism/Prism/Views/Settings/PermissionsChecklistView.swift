//
//  PermissionsChecklistView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import AVFoundation
import PrismCore
import Speech
import SwiftUI

/// Permission checklist that can show core and skill-specific access requirements.
struct PermissionsChecklistView: View {
    let showCore: Bool
    let showSkills: Bool
    private let permissionManager: PermissionManaging

    @State private var coreStates: [CorePermissionState] = []
    @State private var skillStates: [SkillPermissionState] = []
    @State private var isUpdating = false
    @State private var statusText = ""

    init(
        showCore: Bool = true,
        showSkills: Bool = true,
        permissionManager: PermissionManaging = PermissionManager.shared
    ) {
        self.showCore = showCore
        self.showSkills = showSkills
        self.permissionManager = permissionManager
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showCore {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Core Permissions")
                        .font(.headline)

                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                        ForEach(coreStates) { state in
                            CorePermissionRow(state: state) { permission in
                                Task { await requestCorePermission(permission) }
                            }
                        }
                    }
                    .frame(maxWidth: 560)
                }
            }

            if showSkills {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Skill Permissions")
                        .font(.headline)

                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                        ForEach($skillStates) { $state in
                            SkillPermissionRow(
                                title: state.title,
                                subtitle: state.description,
                                status: state.status,
                                isOn: $state.isEnabled
                            )
                            .onChange(of: state.isEnabled) { _, newValue in
                                guard !isUpdating else { return }
                                Task { await handleSkillToggle(state.id, isEnabled: newValue) }
                            }
                        }
                    }
                    .frame(maxWidth: 560)
                }
            }

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await loadStates()
        }
    }

    @MainActor
    private func loadStates() async {
        coreStates = Self.buildCoreStates()
        skillStates = buildSkillStates()
    }

    @MainActor
    private func handleSkillToggle(_ permission: SkillPermission, isEnabled: Bool) async {
        guard let index = skillStates.firstIndex(where: { $0.id == permission }) else { return }
        isUpdating = true
        defer { isUpdating = false }

        if isEnabled {
            let status = await permissionManager.requestAccess(for: permission)
            skillStates[index].status = status
            let enabled = (status == .authorized)
            skillStates[index].isEnabled = enabled
            saveSkillEnabled(permission, isEnabled: enabled)
        } else {
            let status = permissionManager.status(for: permission)
            skillStates[index].status = status
            if status == .authorized {
                skillStates[index].isEnabled = true
                saveSkillEnabled(permission, isEnabled: true)
                statusText = "To revoke access, disable it in System Settings."
            } else {
                saveSkillEnabled(permission, isEnabled: false)
            }
        }
    }

    @MainActor
    private func buildSkillStates() -> [SkillPermissionState] {
        let descriptors = SkillPermissionState.descriptors
        var states: [SkillPermissionState] = []

        for descriptor in descriptors {
            let status = permissionManager.status(for: descriptor.permission)
            let enabled = (status == .authorized)
            saveSkillEnabled(descriptor.permission, isEnabled: enabled)
            states.append(
                SkillPermissionState(
                    id: descriptor.permission,
                    title: descriptor.title,
                    description: descriptor.description,
                    isEnabled: enabled,
                    status: status
                )
            )
        }

        return states
    }

    @MainActor
    private func saveSkillEnabled(_ permission: SkillPermission, isEnabled: Bool) {
        do {
            let queue = try Database().queue
            let store = SettingsStore(queue: queue)
            try store.writeValue(isEnabled ? "true" : "false", for: permission.settingsKey)
            statusText = ""
        } catch {
            statusText = "Unable to save skill settings yet."
        }
    }

    @MainActor
    private func requestCorePermission(_ permission: CorePermission) async {
        switch permission {
        case .microphone:
            _ = await requestMicrophoneAccess()
        case .speech:
            _ = await requestSpeechAccess()
        }
        coreStates = Self.buildCoreStates()
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechAccess() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func buildCoreStates() -> [CorePermissionState] {
        [
            CorePermissionState(
                permission: .microphone,
                title: "Microphone",
                description: "Capture audio for wake word detection and dictation.",
                status: mapAVStatus(AVCaptureDevice.authorizationStatus(for: .audio))
            ),
            CorePermissionState(
                permission: .speech,
                title: "Speech Recognition",
                description: "Transcribe speech to text for commands.",
                status: mapSpeechStatus(SFSpeechRecognizer.authorizationStatus())
            )
        ]
    }

    private static func mapAVStatus(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .unavailable
        }
    }

    private static func mapSpeechStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .unavailable
        }
    }
}

private struct CorePermissionState: Identifiable {
    let id = UUID()
    let permission: CorePermission
    let title: String
    let description: String
    let status: PermissionStatus
}

private struct SkillPermissionState: Identifiable {
    let id: SkillPermission
    let title: String
    let description: String
    var isEnabled: Bool
    var status: PermissionStatus

    static let descriptors: [SkillDescriptor] = [
        SkillDescriptor(
            permission: .weather,
            title: "Location",
            description: "Allow location access for local weather forecasts."
        ),
        SkillDescriptor(
            permission: .music,
            title: "Music",
            description: "Control Apple Music playback and playlists."
        ),
        SkillDescriptor(
            permission: .reminders,
            title: "Reminders",
            description: "Create and update reminders in specific lists."
        )
    ]
}

private struct SkillDescriptor {
    let permission: SkillPermission
    let title: String
    let description: String
}

private enum CorePermission {
    case microphone
    case speech
}

private struct CorePermissionRow: View {
    let state: CorePermissionState
    let onRequest: (CorePermission) -> Void

    var body: some View {
        GridRow {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.title)
                Text(state.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text(statusLabel(for: state.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Request") {
                    onRequest(state.permission)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func statusLabel(for status: PermissionStatus) -> String {
        switch status {
        case .authorized:
            return "Allowed"
        case .notDetermined:
            return "Not requested"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .unavailable:
            return "Unavailable"
        }
    }
}

private struct SkillPermissionRow: View {
    let title: String
    let subtitle: String
    let status: PermissionStatus
    @Binding var isOn: Bool

    var body: some View {
        GridRow {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .trailing, spacing: 4) {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)

                Text(statusLabel(for: status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func statusLabel(for status: PermissionStatus) -> String {
        switch status {
        case .authorized:
            return "Allowed"
        case .notDetermined:
            return "Not requested"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .unavailable:
            return "Unavailable"
        }
    }
}

private extension SkillPermission {
    var settingsKey: String {
        switch self {
        case .weather:
            return SettingsKeys.skillWeatherEnabled
        case .music:
            return SettingsKeys.skillMusicEnabled
        case .reminders:
            return SettingsKeys.skillRemindersEnabled
        }
    }
}

#Preview {
    PermissionsChecklistView()
        .padding()
}
