//
//  AudioPipelineController.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation
import PrismCore

/// Coordinates audio capture, VAD gating, STT, and conversation window updates.
final class AudioPipelineController {
    private let appState: AppState
    private let audioCaptureService: AudioCaptureService
    private let vadService: VADService
    private let sttService: STTService
    private let conversationManager: ConversationManager
    private let defaultConversationState: ConversationState
    private let orchestrationController: OrchestrationController?
    private let speakerIDController: SpeakerIDController?
    private let sessionTracker: ConversationSessionTracker?
    private let memoryCoordinator: MemoryCoordinator?

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
        self.sttService = STTService()
        self.conversationManager = conversationManager
        self.orchestrationController = orchestrationController
        self.speakerIDController = speakerIDController
        self.sessionTracker = sessionTracker
        self.memoryCoordinator = memoryCoordinator
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

        sttService.onError = { [weak self] message in
            Task { @MainActor in
                self?.appState.statusMessage = message
                self?.appState.assistantStatus = .paused
                self?.appState.isListening = false
            }
        }
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
                        await self.conversationManager.acceptUtterance(event: event)
                        if event.isFinal {
                            await MainActor.run {
                                self.appState.lastResponse = nil
                            }
                            let isConversationOpen = await MainActor.run { self.appState.conversationState.isOpen }
                            if isConversationOpen {
                                let speakerID = await MainActor.run { self.appState.currentSpeakerID }
                                await self.sessionTracker?.recordUserUtterance(event.text, speakerID: speakerID)
                                if await self.shouldHandleFinalTranscript(utteranceID: event.utteranceID) {
                                    self.orchestrationController?.handleFinalTranscript(event.text)
                                }
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
}
