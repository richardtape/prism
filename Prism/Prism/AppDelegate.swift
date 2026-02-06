//
//  AppDelegate.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import AppKit
import SwiftUI

/// App-level delegate responsible for accessory setup and the menu-bar status item.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var statusPanelController: StatusPanelController?
    private let onboardingWindowController = OnboardingWindowController()
    private let onboardingShownKey = "onboarding.hasShown"
    private let appState = AppState()
    private var onboardingObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if isRunningTests {
            return
        }

        // Accessory policy removes the Dock icon and main menu bar presence.
        NSApp.setActivationPolicy(.accessory)

        configureStatusPanel()
        configureStatusItem()
        registerOnboardingObserver()
        maybeShowOnboarding()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let onboardingObserver {
            NotificationCenter.default.removeObserver(onboardingObserver)
        }
    }

    private func configureStatusPanel() {
        let rootView = ContentView()
            .environmentObject(appState)
        statusPanelController = StatusPanelController(rootView: AnyView(rootView))
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Prism")
            button.action = #selector(togglePanel)
            button.target = self
        }

        statusItem = item
    }

    @objc private func togglePanel() {
        guard let button = statusItem?.button else { return }
        statusPanelController?.toggle(relativeTo: button)
    }

    private func registerOnboardingObserver() {
        onboardingObserver = NotificationCenter.default.addObserver(
            forName: .openOnboarding,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onboardingWindowController.show()
        }
    }

    private func maybeShowOnboarding() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: onboardingShownKey) else { return }

        onboardingWindowController.show()
        defaults.set(true, forKey: onboardingShownKey)
    }

    private var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil
    }
}

extension Notification.Name {
    static let openOnboarding = Notification.Name("Prism.openOnboarding")
}
