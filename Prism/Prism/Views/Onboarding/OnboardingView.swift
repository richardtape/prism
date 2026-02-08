//
//  OnboardingView.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import SwiftUI

/// Root onboarding container with placeholder steps for Phase 00.
struct OnboardingView: View {
    @State private var selectedStep: OnboardingStep = .welcome

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(minWidth: 680, minHeight: 420)
    }

    private var sidebar: some View {
        List(selection: $selectedStep) {
            ForEach(OnboardingStep.allCases) { step in
                Text(step.rawValue)
                    .tag(step)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedStep.rawValue)
                .font(.title2)

            switch selectedStep {
            case .welcome:
                Text("Welcome to Prism. This onboarding flow will guide you through setup.")
                    .foregroundStyle(.secondary)
            case .permissions:
                Text("Review the permissions Prism will need.")
                    .foregroundStyle(.secondary)
                PermissionsChecklistView()
                    .padding(.top, 8)
                Divider()
                    .padding(.vertical, 8)
                VStack(alignment: .leading, spacing: 8) {
                    Text("AirPlay Output")
                        .font(.headline)
                    Text("Select an AirPlay speaker for Apple Music playback.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AirPlayRoutePickerView()
                        .frame(width: 28, height: 28)
                }
            case .enrollment:
                EnrollmentView()
            }

            Spacer()
            HStack {
                Button("Back") {
                    moveSelection(direction: -1)
                }
                .disabled(selectedStep == OnboardingStep.allCases.first)

                Spacer()

                Button("Continue") {
                    moveSelection(direction: 1)
                }
                .disabled(selectedStep == OnboardingStep.allCases.last)
            }
        }
        .padding(20)
    }

    private func moveSelection(direction: Int) {
        guard let index = OnboardingStep.allCases.firstIndex(of: selectedStep) else { return }
        let newIndex = index + direction
        guard OnboardingStep.allCases.indices.contains(newIndex) else { return }
        selectedStep = OnboardingStep.allCases[newIndex]
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
