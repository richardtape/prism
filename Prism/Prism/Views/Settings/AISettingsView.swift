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
    @State private var statusText = ""
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
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    }

    private var modelPicker: some View {
        Group {
            if endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Picker("Model", selection: $selectedModel) {
                    Text("Enter an AI Endpoint").tag("")
                }
                .disabled(true)
            } else {
                Picker("Model", selection: $selectedModel) {
                    Text("Choose Model").tag("")
                    ForEach(modelOptions, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            selectedModel = ""
            return
        }

        // Phase 02+: fetch models from the endpoint's /v1/models.
        // For now, provide placeholder options once an endpoint is present.
        modelOptions = ["placeholder-model-1", "placeholder-model-2"]
        if !modelOptions.contains(selectedModel) {
            selectedModel = ""
        }
    }

    private func loadConfig() {
        do {
            let fileURL = try ConfigStore.defaultLocation()
            let store = ConfigStore(fileURL: fileURL)
            guard let config = try store.load() else { return }
            endpoint = config.endpoint
            apiKey = config.apiKey
            selectedModel = config.model ?? ""
            refreshModels()
        } catch {
            statusText = "Unable to load config yet."
        }
    }

    private func saveConfigIfPossible() {
        do {
            let fileURL = try ConfigStore.defaultLocation()
            let store = ConfigStore(fileURL: fileURL)
            let config = LLMConfig(endpoint: endpoint, apiKey: apiKey, model: selectedModel)
            try store.save(config)
            statusText = ""
        } catch {
            statusText = "Unable to save config yet."
        }
    }
}

#Preview {
    AISettingsView()
}
