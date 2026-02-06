//
//  OnboardingStep.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Enumerates the onboarding steps used for the Phase 00 scaffolding.
enum OnboardingStep: String, CaseIterable, Identifiable {
    case welcome = "Welcome"
    case permissions = "Permissions"
    case enrollment = "Enrollment"

    var id: String { rawValue }
}
