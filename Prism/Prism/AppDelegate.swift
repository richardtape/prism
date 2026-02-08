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
    private let onboardingShownKey = "onboarding.hasShown"
    private let appState = AppState()
    private lazy var onboardingWindowController = OnboardingWindowController(appState: appState)
    private var onboardingObserver: NSObjectProtocol?
    private var listeningObserver: AnyCancellable?
    private var audioPipelineController: AudioPipelineController?
    private var orchestrationController: OrchestrationController?
    private var speakerIDController: SpeakerIDController?
    private var speakerMatchController: SpeakerMatchController?
    private var sessionTracker: ConversationSessionTracker?
    private var memoryCoordinator: MemoryCoordinator?
    private var llmConfigObserver: NSObjectProtocol?
    private var wakeWordConfigObserver: NSObjectProtocol?
    private var audioConfigObserver: NSObjectProtocol?

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
        registerWakeWordConfigObserver()
        registerAudioConfigObserver()
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
        if let wakeWordConfigObserver {
            NotificationCenter.default.removeObserver(wakeWordConfigObserver)
        }
        if let audioConfigObserver {
            NotificationCenter.default.removeObserver(audioConfigObserver)
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
        let wakeWordSettings = WakeWordSettingsLoader().load()
        let fillerTokens = Self.closingFillerTokens(using: wakeWordSettings)
        let closingDetector = ClosingPhraseDetector(
            phrases: settings.closingPhrases,
            fillerTokens: fillerTokens
        )
        let conversationManager = ConversationManager(
            windowSeconds: settings.conversationWindowSeconds,
            maxTurns: settings.conversationMaxTurns,
            closingDetector: closingDetector
        )
        let queue = try? Database().queue
        let registry = SkillRegistry(queue: queue)
        let orchestrationPipeline = OrchestrationPipeline(registry: registry)
        let sessionTracker = ConversationSessionTracker()
        self.sessionTracker = sessionTracker
        if let queue {
            memoryCoordinator = MemoryCoordinator(queue: queue)
        }
        let orchestration = OrchestrationController(appState: appState, pipeline: orchestrationPipeline, sessionTracker: sessionTracker)
        orchestrationController = orchestration

        let speakerIDController = SpeakerIDController(extractor: StubSpeakerEmbeddingModel())
        self.speakerIDController = speakerIDController
        if let queue {
            let speakerSettings = SpeakerIDSettingsLoader().load()
            let store = SpeakerProfileStore(queue: queue)
            speakerMatchController = SpeakerMatchController(
                extractor: StubSpeakerEmbeddingModel(),
                settings: speakerSettings,
                store: store
            )
        }

        speakerIDController.onEmbeddingExtracted = { [weak self] utteranceID, embedding in
            guard let self else { return }
            guard let matcher = self.speakerMatchController else { return }
            do {
                let match = try matcher.match(embedding: embedding)
                Task { @MainActor in
                    if let match, match.isAboveThreshold {
                        self.appState.currentSpeakerName = match.displayName
                        self.appState.currentSpeakerID = match.profileID
                        self.appState.currentSpeakerConfidence = match.similarity
                        self.appState.speakerMatchStates[utteranceID] = .matched(match)
                    } else if let match {
                        self.appState.currentSpeakerName = "Unknown"
                        self.appState.currentSpeakerID = nil
                        self.appState.currentSpeakerConfidence = match.similarity
                        self.appState.speakerMatchStates[utteranceID] = .matched(match)
                    } else {
                        self.appState.currentSpeakerName = "Unknown"
                        self.appState.currentSpeakerID = nil
                        self.appState.currentSpeakerConfidence = nil
                        self.appState.speakerMatchStates[utteranceID] = .noMatch
                    }
                }
            } catch {
                Task { @MainActor in
                    self.appState.currentSpeakerName = "Unknown"
                    self.appState.currentSpeakerID = nil
                    self.appState.currentSpeakerConfidence = nil
                    self.appState.speakerMatchStates[utteranceID] = .noMatch
                }
            }
        }

        let pipeline = AudioPipelineController(
            appState: appState,
            settings: settings,
            conversationManager: conversationManager,
            orchestrationController: orchestration,
            speakerIDController: speakerIDController,
            sessionTracker: sessionTracker,
            memoryCoordinator: memoryCoordinator
        )
        audioPipelineController = pipeline
        pipeline.updateWakeWordSettings(wakeWordSettings)

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

    private static func closingFillerTokens(using settings: WakeWordSettings) -> [String] {
        let acknowledgements = ["ok", "okay", "alright"]
        let aliasTokens = settings.aliases
            .flatMap { ClosingPhraseDetector.normalize($0).split(whereSeparator: { $0.isWhitespace }) }
            .map(String.init)
        return acknowledgements + aliasTokens
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

    private func registerWakeWordConfigObserver() {
        wakeWordConfigObserver = NotificationCenter.default.addObserver(
            forName: .wakeWordConfigUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let settings = WakeWordSettingsLoader().load()
                self.audioPipelineController?.updateWakeWordSettings(settings)
            }
        }
    }

    private func registerAudioConfigObserver() {
        audioConfigObserver = NotificationCenter.default.addObserver(
            forName: .audioConfigUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let settings = AudioSettingsLoader().load()
            self.audioPipelineController?.updateSTTLocale(identifier: settings.sttLocaleIdentifier)
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
    static let wakeWordConfigUpdated = Notification.Name("Prism.wakeWordConfigUpdated")
    static let audioConfigUpdated = Notification.Name("Prism.audioConfigUpdated")
}
