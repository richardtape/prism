//
//  EnrollmentFlowStep.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation

/// Top-level steps for the enrollment carousel.
enum EnrollmentFlowStep: Equatable {
    case intro
    case list
    case name
    case samples
    case completion
}
