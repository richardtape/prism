//
//  AppDelegate.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import AppKit
import Combine
import PrismCore
import SwiftUI

/// App-level delegate responsible for accessory setup and the menu-bar status item.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var statusPanelController: StatusPanelController?
    private let onboardingWindowController = OnboardingWindowController()
    private let onboardingShownKey = "onboarding.hasShown"
    private let appState = AppState()
    private var onboardingObserver: NSObjectProtocol?
    private var listeningObserver: AnyCancellable?
    private var audioPipelineController: AudioPipelineController?
    private var orchestrationController: OrchestrationController?
    private var llmConfigObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if isRunningTests {
            return
        }

        // Accessory policy removes the Dock icon and main menu bar presence.
        NSApp.setActivationPolicy(.accessory)

        configureStatusPanel()
        configureStatusItem()
        configureAudioPipeline()
        registerOnboardingObserver()
        registerLLMConfigObserver()
        appState.refreshLLMStatus()
        maybeShowOnboarding()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let onboardingObserver {
            NotificationCenter.default.removeObserver(onboardingObserver)
        }
        if let llmConfigObserver {
            NotificationCenter.default.removeObserver(llmConfigObserver)
        }
        listeningObserver?.cancel()
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

    private func configureAudioPipeline() {
        let settings = AudioSettingsLoader().load()
        let closingDetector = ClosingPhraseDetector(phrases: settings.closingPhrases)
        let conversationManager = ConversationManager(
            windowSeconds: settings.conversationWindowSeconds,
            maxTurns: settings.conversationMaxTurns,
            closingDetector: closingDetector
        )
        let registry = SkillRegistry(queue: (try? Database().queue))
        let orchestrationPipeline = OrchestrationPipeline(registry: registry)
        let orchestration = OrchestrationController(appState: appState, pipeline: orchestrationPipeline)
        orchestrationController = orchestration

        let pipeline = AudioPipelineController(
            appState: appState,
            settings: settings,
            conversationManager: conversationManager,
            orchestrationController: orchestration
        )
        audioPipelineController = pipeline

        appState.onOpenConversationWindow = { [weak self] in
            self?.audioPipelineController?.openConversationWindow()
        }

        listeningObserver = appState.$isListening
            .removeDuplicates()
            .sink { [weak self] isListening in
                if isListening {
                    self?.audioPipelineController?.start()
                } else {
                    self?.audioPipelineController?.stop()
                }
            }

        if appState.isListening {
            audioPipelineController?.start()
        }
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

    private func registerLLMConfigObserver() {
        llmConfigObserver = NotificationCenter.default.addObserver(
            forName: .llmConfigUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let appState = self?.appState else { return }
            Task { @MainActor in
                appState.refreshLLMStatus()
            }
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
    static let llmConfigUpdated = Notification.Name("Prism.llmConfigUpdated")
}
