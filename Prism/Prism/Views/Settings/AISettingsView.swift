//
//  AISettingsView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import PrismCore
import SwiftUI

/// AI settings placeholders for configuring the LLM endpoint and API key.
struct AISettingsView: View {
    private enum FocusField {
        case endpoint
        case apiKey
    }

    @State private var endpoint = ""
    @State private var apiKey = ""
    @State private var modelOptions: [String] = []
    @State private var selectedModel = ""
    private enum StatusKind {
        case none
        case success
        case error
    }

    @State private var statusText = ""
    @State private var statusKind: StatusKind = .none
    @State private var modelRefreshTask: Task<Void, Never>?
    @State private var statusResetTask: Task<Void, Never>?
    @State private var isFetchingModels = false
    @State private var isLoadingConfig = false
    @FocusState private var focusedField: FocusField?
    @State private var lastFocusedField: FocusField?

    var body: some View {
        SettingsSectionContainer(title: "AI") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("Endpoint URL")
                    TextField("https://api.example.com", text: $endpoint)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .endpoint)
                }

                GridRow {
                    Text("API Key")
                    SecureField("sk-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .apiKey)
                }

                GridRow {
                    Text("Model")
                    modelPicker
                }
            }
            .frame(maxWidth: 560)

            if !statusText.isEmpty {
                statusView
            }
        }
        .task {
            loadConfig()
        }
        .onChange(of: focusedField) { _, newValue in
            handleFocusChange(newValue)
        }
        .onChange(of: selectedModel) { _, _ in
            saveConfigIfPossible()
        }
        .onChange(of: endpoint) { _, _ in
            scheduleModelRefresh()
        }
        .onChange(of: apiKey) { _, _ in
            scheduleModelRefresh()
        }
    }

    private var statusView: some View {
        Group {
            if statusKind == .error {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(statusText)
                }
            } else {
                Text(statusText)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var modelPicker: some View {
        let normalizedSelection = Binding(
            get: { selectedModel.trimmingCharacters(in: .whitespacesAndNewlines) },
            set: { selectedModel = $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )

        let picker = Group {
            if endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let options = modelOptionsIncludingSelection()
                Picker("", selection: normalizedSelection) {
                    if normalizedSelection.wrappedValue.isEmpty {
                        Text("Enter an AI Endpoint").tag("")
                    } else {
                        Text(normalizedSelection.wrappedValue).tag(normalizedSelection.wrappedValue)
                    }
                    ForEach(options.filter { $0 != normalizedSelection.wrappedValue }, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Model")
                .disabled(true)
            } else {
                let options = modelOptionsIncludingSelection()
                Picker("", selection: normalizedSelection) {
                    Text(isFetchingModels ? "Loading models..." : "Choose Model").tag("")
                    ForEach(options, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Model")
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)

        return picker
    }

    private func modelOptionsIncludingSelection() -> [String] {
        let trimmed = selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !modelOptions.contains(trimmed) else { return modelOptions }
        return modelOptions + [trimmed]
    }

    private func handleFocusChange(_ newValue: FocusField?) {
        if let lastFocusedField, newValue != lastFocusedField {
            saveConfigIfPossible()
            if lastFocusedField == .endpoint {
                refreshModels()
            }
        }
        lastFocusedField = newValue
    }

    private func refreshModels() {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEndpoint.isEmpty else {
            modelOptions = []
            return
        }

        Task {
            await fetchModels()
        }
    }

    private func loadConfig() {
        isLoadingConfig = true
        do {
            let fileURL = try ConfigStore.defaultLocation()
            let store = ConfigStore(fileURL: fileURL)
            guard let config = try store.load() else { return }
            endpoint = config.endpoint
            apiKey = config.apiKey
            selectedModel = (config.model ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            statusText = "Unable to load config yet."
        }
        isLoadingConfig = false
    }

    private func scheduleModelRefresh() {
        guard !isLoadingConfig else { return }
        modelRefreshTask?.cancel()
        modelRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await fetchModels()
        }
    }

    @MainActor
    private func fetchModels() async {
        let trimmedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEndpoint.isEmpty else {
            modelOptions = []
            return
        }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            modelOptions = []
            statusText = "Enter an API key to fetch models."
            statusKind = .none
            return
        }

        do {
            isFetchingModels = true
            statusText = ""
            statusKind = .none
            let fileURL = try ConfigStore.defaultLocation()
            let store = ConfigStore(fileURL: fileURL)
            let client = LLMClient(configStore: store)
            let models = try await client.listModels(endpoint: trimmedEndpoint, apiKey: trimmedKey)
            modelOptions = models
            statusText = "AI models refreshed."
            statusKind = .success
            scheduleStatusReset()
        } catch {
            modelOptions = []
            statusText = "Unable to fetch models"
            statusKind = .error
            saveConfigIfPossible(suppressStatus: true)
        }
        isFetchingModels = false
    }

    @MainActor
    private func scheduleStatusReset() {
        statusResetTask?.cancel()
        statusResetTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if statusText == "AI models refreshed." {
                statusText = ""
                statusKind = .none
            }
        }
    }

    private func saveConfigIfPossible(suppressStatus: Bool = false) {
        do {
            let fileURL = try ConfigStore.defaultLocation()
            let store = ConfigStore(fileURL: fileURL)
            let trimmedModel = selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
            let config = LLMConfig(endpoint: endpoint, apiKey: apiKey, model: trimmedModel)
            try store.save(config)
            if !suppressStatus {
                statusText = ""
                statusKind = .none
            }
            NotificationCenter.default.post(name: .llmConfigUpdated, object: nil)
        } catch {
            if !suppressStatus {
                statusText = "Unable to save config yet."
                statusKind = .error
            }
        }
    }
}

#Preview {
    AISettingsView()
}
