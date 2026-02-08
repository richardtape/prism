//
//  AudioSettingsView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import PrismCore
import Speech
import SwiftUI

/// Audio settings for wake-word detection calibration.
struct AudioSettingsView: View {
    @State private var isWakeWordEnabled = true
    @State private var sensitivity: Double = 0.6
    @State private var minConfidence: Double = 0.6
    @State private var aliasesText: String = ""
    @State private var speechLocaleIdentifier: String = ""
    @State private var effectiveSpeechLocaleName: String = ""
    @State private var statusText = ""
    @State private var isLoading = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        SettingsSectionContainer(title: "Audio") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Speech Recognition")
                    .font(.headline)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Language")
                            Text("Select the speech recognition language for best accuracy.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Picker("Language", selection: $speechLocaleIdentifier) {
                            ForEach(speechLocaleOptions) { option in
                                Text(option.label).tag(option.id)
                                    .foregroundStyle(option.isAvailable ? .primary : .secondary)
                                    .disabled(!option.isAvailable)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: 560)

                if !effectiveSpeechLocaleName.isEmpty {
                    Text("Effective language: \(effectiveSpeechLocaleName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text("Wake Word")
                    .font(.headline)

                SettingsToggleRow(
                    title: "Enable wake word",
                    subtitle: "Listen continuously and open a session when the wake word is detected.",
                    isOn: $isWakeWordEnabled
                )

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sensitivity")
                            Text("Higher values trigger more easily in noisy rooms.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            Slider(value: $sensitivity, in: 0...1, step: 0.01)
                            Text(String(format: "%.2f", sensitivity))
                                .font(.caption.monospacedDigit())
                                .frame(width: 48, alignment: .trailing)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Min Confidence")
                            Text("Minimum classifier confidence required for a hit.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            Slider(value: $minConfidence, in: 0...1, step: 0.01)
                            Text(String(format: "%.2f", minConfidence))
                                .font(.caption.monospacedDigit())
                                .frame(width: 48, alignment: .trailing)
                        }
                    }

                    GridRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aliases")
                            Text("Comma-separated phrases that act as the wake word.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        TextField("prism, hey prism, okay prism", text: $aliasesText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .frame(maxWidth: 560)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Diagnostics")
                        .font(.subheadline)

                    Text("Acoustic model: \(modelAvailabilityText)")
                    Text("Text fallback: \(isWakeWordEnabled ? "Enabled" : "Disabled")")

                    if !isModelAvailable {
                        Text("Add the wake-word model to enable acoustic detection.")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)

                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("AirPlay Output")
                        .font(.headline)

                    Text("Choose an AirPlay device for audio playback.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    AirPlayRoutePickerView()
                        .frame(width: 28, height: 28)
                }
            }
        }
        .task {
            loadSettings()
        }
        .onChange(of: isWakeWordEnabled) { _, _ in
            scheduleSave()
        }
        .onChange(of: sensitivity) { _, _ in
            scheduleSave()
        }
        .onChange(of: minConfidence) { _, _ in
            scheduleSave()
        }
        .onChange(of: aliasesText) { _, _ in
            scheduleSave()
        }
        .onChange(of: speechLocaleIdentifier) { _, _ in
            scheduleSave()
        }
    }

    @MainActor
    private func loadSettings() {
        isLoading = true
        let wakeWordSettings = WakeWordSettingsLoader().load()
        let audioSettings = AudioSettingsLoader().load()
        isWakeWordEnabled = wakeWordSettings.isEnabled
        sensitivity = wakeWordSettings.sensitivity
        minConfidence = wakeWordSettings.minConfidence
        aliasesText = wakeWordSettings.aliases.joined(separator: ", ")
        speechLocaleIdentifier = audioSettings.sttLocaleIdentifier
        effectiveSpeechLocaleName = resolvedSpeechLocaleName(for: speechLocaleIdentifier)
        isLoading = false
    }

    private func scheduleSave() {
        guard !isLoading else { return }
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            saveSettings()
        }
    }

    @MainActor
    private func saveSettings() {
        do {
            let queue = try Database().queue
            let store = SettingsStore(queue: queue)

            let clampedSensitivity = WakeWordConfig.clamp01(sensitivity)
            let clampedConfidence = WakeWordConfig.clamp01(minConfidence)
            let aliases = WakeWordSettingsLoader.parseAliases(aliasesText)
            let normalizedAliasesText = aliases.joined(separator: ", ")
            let attemptedLabel = localeLabel(for: speechLocaleIdentifier) ?? speechLocaleIdentifier
            let validatedLocale = validatedLocaleIdentifier(speechLocaleIdentifier)

            if aliasesText != normalizedAliasesText {
                aliasesText = normalizedAliasesText
            }
            if speechLocaleIdentifier != validatedLocale {
                speechLocaleIdentifier = validatedLocale
                if !validatedLocale.isEmpty {
                    statusText = ""
                } else if !attemptedLabel.isEmpty {
                    statusText = "Speech recognition is unavailable for \(attemptedLabel). Using system default."
                } else {
                    statusText = "Speech recognition is unavailable for that language. Using system default."
                }
            }

            try store.writeValue(isWakeWordEnabled ? "true" : "false", for: SettingsKeys.wakeWordEnabled)
            try store.writeValue(String(format: "%.3f", clampedSensitivity), for: SettingsKeys.wakeWordSensitivity)
            try store.writeValue(String(format: "%.3f", clampedConfidence), for: SettingsKeys.wakeWordMinConfidence)
            try store.writeValue(normalizedAliasesText, for: SettingsKeys.wakeWordAliases)
            try store.writeValue(validatedLocale, for: SettingsKeys.sttLocaleIdentifier)

            NotificationCenter.default.post(name: .wakeWordConfigUpdated, object: nil)
            NotificationCenter.default.post(name: .audioConfigUpdated, object: nil)
            effectiveSpeechLocaleName = resolvedSpeechLocaleName(for: validatedLocale)
        } catch {
            statusText = "Unable to save wake-word settings yet."
        }
    }

    private var speechLocaleOptions: [SpeechLocaleOption] {
        var options: [SpeechLocaleOption] = [SpeechLocaleOption(id: "", label: "System Default")]
        let identifiers = Locale.preferredLanguages
            .map { $0.replacingOccurrences(of: "-", with: "_") }
            .filter { !$0.isEmpty }
            .uniqued()

        for identifier in identifiers {
            let locale = Locale(identifier: identifier)
            let recognizer = SFSpeechRecognizer(locale: locale)
            let isAvailable = recognizer?.supportsOnDeviceRecognition ?? false
            let baseLabel = locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
            let label = isAvailable ? baseLabel : "\(baseLabel) (Not on-device)"
            options.append(SpeechLocaleOption(id: identifier, label: label, isAvailable: isAvailable))
        }

        return options
    }

    private func validatedLocaleIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let locale = Locale(identifier: trimmed)
        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.supportsOnDeviceRecognition else {
            return ""
        }
        return trimmed
    }

    private func localeLabel(for identifier: String) -> String? {
        speechLocaleOptions.first { $0.id == identifier }?.label
    }

    private func resolvedSpeechLocaleName(for identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolution = SpeechLocaleResolver.resolveOnDeviceLocale(preferredIdentifier: trimmed)
        return resolution.displayName
    }

    private var isModelAvailable: Bool {
        WakeWordService.isModelAvailable(named: WakeWordModelDefaults.modelName)
    }

    private var modelAvailabilityText: String {
        isModelAvailable ? "Installed" : "Missing"
    }
}

private struct SpeechLocaleOption: Identifiable {
    let id: String
    let label: String
    var isAvailable: Bool = true
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

#Preview {
    AudioSettingsView()
        .frame(width: 640, height: 420)
}
