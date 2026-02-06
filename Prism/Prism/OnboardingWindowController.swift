//
//  OnboardingWindowController.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import AppKit
import SwiftUI

/// Manages the onboarding window lifecycle.
final class OnboardingWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: OnboardingView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Prism Onboarding"
        window.setContentSize(NSSize(width: 720, height: 460))
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
