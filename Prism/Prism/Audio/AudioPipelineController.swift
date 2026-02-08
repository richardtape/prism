//
//  AudioPipelineController.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import AVFoundation
import Foundation
import PrismCore
import SoundAnalysis
import Speech

/// Coordinates audio capture, VAD gating, STT, and conversation window updates.
final class AudioPipelineController {
    private let appState: AppState
    private let audioCaptureService: AudioCaptureService
    private let vadService: VADService
    private var sttService: STTService
    private let conversationManager: ConversationManager
    private let defaultConversationState: ConversationState
    private let orchestrationController: OrchestrationController?
    private let speakerIDController: SpeakerIDController?
    private let sessionTracker: ConversationSessionTracker?
    private let memoryCoordinator: MemoryCoordinator?
    private var sttLocaleIdentifier: String
    private var wakeWordSettings: WakeWordSettings?
    private var wakeWordTextDetector: WakeWordTextDetector?
    private var wakeWordService: WakeWordService?
    private var wakeWordRequest: SNClassifySoundRequest?
    private var wakeWordAnalyzerRunning = false

    private var audioTask: Task<Void, Never>?
    private var sttTask: Task<Void, Never>?
    private var conversationTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?
    private var isRunning = false
    private var currentUtteranceID: UUID?
    private var currentUtteranceFrames: [AudioFrame] = []
    private var preRollFrames: [AudioFrame] = []
    private var preRollDuration: TimeInterval = 0
    private let preRollWindowSeconds: TimeInterval = 0.5

    init(
        appState: AppState,
        settings: AudioSettings,
        conversationManager: ConversationManager,
        orchestrationController: OrchestrationController? = nil,
        speakerIDController: SpeakerIDController? = nil,
        sessionTracker: ConversationSessionTracker? = nil,
        memoryCoordinator: MemoryCoordinator? = nil
    ) {
        self.appState = appState
        self.audioCaptureService = AudioCaptureService()
        self.vadService = VADService(configuration: settings.vadConfiguration)
        let resolvedLocale = SpeechLocaleResolver.resolveOnDeviceLocale(preferredIdentifier: settings.sttLocaleIdentifier)
        self.sttLocaleIdentifier = resolvedLocale.identifier
        self.sttService = STTService(locale: resolvedLocale.locale)
        self.conversationManager = conversationManager
        self.orchestrationController = orchestrationController
        self.speakerIDController = speakerIDController
        self.sessionTracker = sessionTracker
        self.memoryCoordinator = memoryCoordinator
        if resolvedLocale.usedFallback {
            let appStateRef = appState
            Task { @MainActor in
                appStateRef.statusMessage = "Using on-device speech recognition for \(resolvedLocale.displayName)."
            }
        }
        self.defaultConversationState = .closed(
            windowSeconds: settings.conversationWindowSeconds,
            maxTurns: settings.conversationMaxTurns
        )

        conversationTask = Task { [weak self] in
            guard let self else { return }
            var wasOpen = false
            for await state in conversationManager.stateStream {
                await MainActor.run {
                    self.appState.conversationState = state
                }
                if wasOpen, !state.isOpen {
                    if let summary = await sessionTracker?.closeSession() {
                        memoryCoordinator?.handleSessionSummary(summary)
                    }
                }
                wasOpen = state.isOpen
            }
        }

        audioCaptureService.onAudioLevel = { [weak self] level in
            Task { @MainActor in
                self?.appState.audioLevel = level
            }
        }
        audioCaptureService.onAudioBuffer = { [weak self] buffer, time in
            self?.handleAudioBuffer(buffer, time: time)
        }

        configureSTTErrorHandler()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        Task { @MainActor in
            appState.assistantStatus = .listening
            appState.statusMessage = ""
            appState.lastTranscript = nil
            appState.conversationState = defaultConversationState
        }

        startupTask = Task { [weak self] in
            guard let self else { return }
            guard self.isRunning else { return }
            do {
                let stream = try await sttService.startStreaming()
                guard self.isRunning else { return }
                sttTask = Task { [weak self] in
                    guard let self else { return }
                    for await event in stream {
                        await MainActor.run {
                            self.appState.lastTranscript = event.text
                        }
                        var wakeWordMatch: WakeWordTextMatch?
                        if event.isFinal, let detector = self.wakeWordTextDetector {
                            wakeWordMatch = detector.detect(
                                in: event.text,
                                confidence: event.confidence,
                                timestamp: event.timestamp
                            )
                            if let match = wakeWordMatch {
                                await self.openWakeWordSession(for: match.event)
                            }
                        }

                        await self.conversationManager.acceptUtterance(event: event)

                        if event.isFinal {
                            if let match = wakeWordMatch {
                                await self.handleWakeWordTranscript(match.strippedText, utteranceID: event.utteranceID)
                            } else if await self.conversationManager.snapshot().isOpen {
                                await self.handleWakeWordTranscript(event.text, utteranceID: event.utteranceID)
                            }
                        }
                    }
                }

                let audioStream = try await audioCaptureService.start()
                guard self.isRunning else { return }
                audioTask = Task { [weak self] in
                    guard let self else { return }
                    for await frame in audioStream {
                        if Task.isCancelled { break }
                        let result = vadService.process(frame: frame)
                        appendPreRollFrame(frame)

                        if result.didStartSpeech {
                            let utteranceID = UUID()
                            currentUtteranceID = utteranceID
                            let preRollSnapshot = preRollFrames
                            currentUtteranceFrames = preRollSnapshot
                            try? sttService.startUtterance(utteranceID: utteranceID)
                            for preRollFrame in preRollSnapshot {
                                sttService.appendAudioFrame(preRollFrame)
                            }
                            await MainActor.run {
                                self.appState.assistantStatus = .processing
                            }
                        }

                        if result.isSpeech {
                            if !result.didStartSpeech {
                                sttService.appendAudioFrame(frame)
                                if currentUtteranceID != nil {
                                    currentUtteranceFrames.append(frame)
                                }
                            }
                        }

                        if result.didEndSpeech {
                            sttService.endUtterance()
                            if let utteranceID = currentUtteranceID {
                                speakerIDController?.processUtterance(id: utteranceID, frames: currentUtteranceFrames)
                            }
                            currentUtteranceID = nil
                            currentUtteranceFrames = []
                            await MainActor.run {
                                self.appState.assistantStatus = .listening
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if let error = error as? STTError {
                        switch error {
                        case .authorizationDenied:
                            self.appState.statusMessage = "Speech recognition permission is required."
                        case .recognizerUnavailable, .onDeviceUnavailable:
                            self.appState.statusMessage = "Speech recognition is unavailable on this device."
                        }
                    } else if let error = error as? AudioCaptureError {
                        switch error {
                        case .permissionDenied:
                            self.appState.statusMessage = "Microphone access is required to listen."
                        case .invalidFormat, .failedToStartEngine:
                            self.appState.statusMessage = "Unable to start the microphone capture session."
                        }
                    } else {
                        self.appState.statusMessage = "Unable to start the audio pipeline."
                    }
                    self.appState.assistantStatus = .paused
                    self.appState.isListening = false
                }
                self.stop()
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        audioTask?.cancel()
        audioTask = nil
        sttTask?.cancel()
        sttTask = nil
        startupTask?.cancel()
        startupTask = nil

        audioCaptureService.stop()
        sttService.stopStreaming()
        vadService.reset()
        speakerIDController?.cancelCurrentExtraction()
        wakeWordService?.stop()
        wakeWordAnalyzerRunning = false
        currentUtteranceID = nil
        currentUtteranceFrames = []
        preRollFrames = []
        preRollDuration = 0
        Task {
            await conversationManager.closeWindow()
        }
        Task {
            await sessionTracker?.reset()
        }

        Task { @MainActor in
            self.appState.assistantStatus = .paused
            self.appState.audioLevel = 0
            self.appState.conversationState = self.defaultConversationState
        }
    }

    func openConversationWindow() {
        Task {
            await conversationManager.openWindow()
        }
    }

    func updateSTTLocale(identifier: String) {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLocale = SpeechLocaleResolver.resolveOnDeviceLocale(preferredIdentifier: trimmed)

        if resolvedLocale.identifier == sttLocaleIdentifier {
            if resolvedLocale.usedFallback {
                Task { @MainActor in
                    appState.statusMessage = "Using on-device speech recognition for \(resolvedLocale.displayName)."
                }
            }
            return
        }

        sttLocaleIdentifier = resolvedLocale.identifier
        let wasRunning = isRunning
        if wasRunning {
            stop()
        }

        sttService = STTService(locale: resolvedLocale.locale)
        configureSTTErrorHandler()

        if wasRunning {
            start()
        }

        if resolvedLocale.usedFallback {
            Task { @MainActor in
                appState.statusMessage = "Using on-device speech recognition for \(resolvedLocale.displayName)."
            }
        }
    }

    func updateWakeWordSettings(_ settings: WakeWordSettings) {
        wakeWordSettings = settings

        if settings.isEnabled {
            let config = WakeWordConfig(
                aliases: settings.aliases,
                sensitivity: settings.sensitivity,
                minConfidence: settings.minConfidence
            )
            wakeWordTextDetector = WakeWordTextDetector(config: config)
            configureWakeWordService(with: settings)
            audioCaptureService.onAudioBuffer = { [weak self] buffer, time in
                self?.handleAudioBuffer(buffer, time: time)
            }
        } else {
            wakeWordTextDetector = nil
            wakeWordService?.stop()
            wakeWordService = nil
            wakeWordRequest = nil
            wakeWordAnalyzerRunning = false
            audioCaptureService.onAudioBuffer = nil
        }
    }

    private func shouldHandleFinalTranscript(utteranceID: UUID) async -> Bool {
        if let matchState = await MainActor.run(body: { appState.speakerMatchStates[utteranceID] }) {
            return await resolveMatchState(matchState, utteranceID: utteranceID)
        }

        try? await Task.sleep(nanoseconds: 150_000_000)
        if let matchState = await MainActor.run(body: { appState.speakerMatchStates[utteranceID] }) {
            return await resolveMatchState(matchState, utteranceID: utteranceID)
        }

        _ = await MainActor.run {
            appState.speakerMatchStates[utteranceID] = .noMatch
        }
        return await resolveMatchState(.noMatch, utteranceID: utteranceID)
    }

    private func resolveMatchState(_ matchState: SpeakerMatchState, utteranceID: UUID) async -> Bool {
        switch matchState {
        case .matched(let match):
            _ = await MainActor.run {
                appState.speakerMatchStates.removeValue(forKey: utteranceID)
            }
            if match.isAboveThreshold {
                return true
            }
            _ = await MainActor.run {
                if appState.unknownSpeakerPrompt == nil {
                    appState.unknownSpeakerPrompt = UnknownSpeakerPromptState(
                        utteranceID: utteranceID,
                        reason: "Speaker confidence below threshold."
                    )
                }
            }
            return false
        case .noMatch:
            _ = await MainActor.run {
                appState.speakerMatchStates.removeValue(forKey: utteranceID)
                if appState.unknownSpeakerPrompt == nil {
                    appState.unknownSpeakerPrompt = UnknownSpeakerPromptState(
                        utteranceID: utteranceID,
                        reason: "Unknown speaker detected."
                    )
                }
            }
            return false
        }
    }

    private func appendPreRollFrame(_ frame: AudioFrame) {
        preRollFrames.append(frame)
        preRollDuration += frameDuration(frame)

        while preRollDuration > preRollWindowSeconds, !preRollFrames.isEmpty {
            let removed = preRollFrames.removeFirst()
            preRollDuration -= frameDuration(removed)
        }
    }

    private func frameDuration(_ frame: AudioFrame) -> TimeInterval {
        guard frame.sampleRate > 0 else { return 0.02 }
        return Double(frame.samples.count) / frame.sampleRate
    }

    private func configureWakeWordService(with settings: WakeWordSettings) {
        let minConfidence = acousticMinConfidence(for: settings)
        let configuration = WakeWordService.Configuration(
            targetLabels: WakeWordModelDefaults.labels,
            minConfidence: minConfidence,
            cooldownSeconds: WakeWordModelDefaults.cooldownSeconds
        )

        wakeWordService = WakeWordService(configuration: configuration)
        wakeWordService?.onDetect = { [weak self] detection in
            guard let self else { return }
            let event = WakeWordEvent(
                source: .acoustic,
                confidence: detection.confidence,
                timestamp: detection.timestamp
            )
            Task {
                await self.openWakeWordSession(for: event)
            }
        }

        do {
            wakeWordRequest = try WakeWordService.loadRequest(modelName: WakeWordModelDefaults.modelName)
            wakeWordAnalyzerRunning = false
        } catch {
            wakeWordRequest = nil
            wakeWordService = nil
            wakeWordAnalyzerRunning = false
            Task { @MainActor in
                if self.appState.statusMessage.isEmpty {
                    self.appState.statusMessage = "Wake-word model unavailable. Text fallback still works."
                }
            }
        }
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard isRunning else { return }
        guard let settings = wakeWordSettings, settings.isEnabled else { return }
        guard let wakeWordService, let wakeWordRequest else { return }

        if !wakeWordAnalyzerRunning {
            do {
                try wakeWordService.start(request: wakeWordRequest, format: buffer.format)
                wakeWordAnalyzerRunning = true
            } catch {
                wakeWordAnalyzerRunning = false
                return
            }
        }

        wakeWordService.process(buffer: buffer, time: time)
    }

    private func openWakeWordSession(for event: WakeWordEvent) async {
        await conversationManager.openWindow()
        await sessionTracker?.reset()
        await MainActor.run {
            appState.lastResponse = nil
            appState.unknownSpeakerPrompt = nil
        }
    }

    private func handleWakeWordTranscript(_ text: String, utteranceID: UUID) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await MainActor.run {
            appState.lastResponse = nil
        }

        let speakerID = await MainActor.run { appState.currentSpeakerID }
        await sessionTracker?.recordUserUtterance(trimmed, speakerID: speakerID)

        if await shouldHandleFinalTranscript(utteranceID: utteranceID) {
            orchestrationController?.handleFinalTranscript(trimmed)
        }
    }

    private func acousticMinConfidence(for settings: WakeWordSettings) -> Double {
        let base = WakeWordConfig.clamp01(settings.minConfidence)
        let sensitivity = WakeWordConfig.clamp01(settings.sensitivity)
        let adjustment = (0.5 - sensitivity) * 0.2
        return WakeWordConfig.clamp01(base + adjustment)
    }

    private func configureSTTErrorHandler() {
        sttService.onError = { [weak self] message in
            Task { @MainActor in
                self?.appState.statusMessage = message
                self?.appState.assistantStatus = .paused
                self?.appState.isListening = false
            }
        }
    }
}
