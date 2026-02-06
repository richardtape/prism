//
//  ContentView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-05.
//

import PrismCore
import SwiftUI

/// Menu-bar panel content that surfaces app status and navigation affordances.
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            statusSection
            audioMeter
            Divider()
            transcriptSection
            Divider()
            responseSection
            Divider()
            actions
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(width: 320, alignment: .leading)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var header: some View {
        HStack {
            Text("Prism")
                .font(.headline)
            Spacer()
            Button {
                toggleListening()
            } label: {
                Image(systemName: appState.isListening ? "mic.fill" : "mic.slash.fill")
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .help(appState.isListening ? "Pause listening" : "Resume listening")
            .accessibilityLabel(appState.isListening ? "Pause listening" : "Resume listening")
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            StatusRow(label: "State", value: appState.assistantStatus.displayName)
            StatusRow(label: "Listening", value: appState.isListening ? "On" : "Paused")
            StatusRow(label: "Conversation", value: conversationStatusText)
            StatusRow(label: "Speaker", value: "--")
            StatusRow(label: "LLM", value: appState.llmStatusText)
        }
        .font(.subheadline)
    }

    private var audioMeter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Audio Level")
                .font(.caption)
                .foregroundStyle(.secondary)
            AudioLevelMeterView(level: appState.audioLevel)
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last Transcript")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let lastTranscript = appState.lastTranscript, !lastTranscript.isEmpty {
                Text(lastTranscript)
                    .font(.footnote)
                    .lineLimit(2)
            } else {
                Text("Waiting for speech...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !appState.statusMessage.isEmpty {
                Text(appState.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last Response")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let lastResponse = appState.lastResponse, !lastResponse.isEmpty {
                Text(lastResponse)
                    .font(.footnote)
                    .lineLimit(2)
            } else {
                Text("Waiting for response...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actions: some View {
        HStack {
            Button("Start Conversation") {
                appState.openConversationWindow()
            }
            .buttonStyle(.bordered)
            .disabled(appState.conversationState.isOpen)
            Spacer()
            SettingsLink {
                Text("Settings")
            }
        }
    }

    private func toggleListening() {
        // Phase 01+: allow skills or audio pipeline to drive this state.
        appState.isListening.toggle()
    }

    private var conversationStatusText: String {
        let state = appState.conversationState
        guard state.isOpen else { return "Closed" }
        let turns = "\(state.turnsUsed)/\(state.maxTurns)"
        if let remaining = state.timeRemaining() {
            return "Open (\(turns), \(Int(remaining))s)"
        }
        return "Open (\(turns))"
    }
}

private struct StatusRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 320)
}
