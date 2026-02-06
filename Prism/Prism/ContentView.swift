//
//  ContentView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-05.
//

import SwiftUI

/// Menu-bar panel content that surfaces app status and navigation affordances.
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            statusSection
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
            StatusRow(label: "Listening", value: appState.isListening ? "On" : "Paused")
            StatusRow(label: "Speaker", value: "--")
            StatusRow(label: "LLM", value: "Not configured")
        }
        .font(.subheadline)
    }

    private var actions: some View {
        HStack {
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
