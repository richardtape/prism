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

    private var audioTask: Task<Void, Never>?
    private var sttTask: Task<Void, Never>?
    private var conversationTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?
    private var isRunning = false

    init(appState: AppState, settings: AudioSettings, conversationManager: ConversationManager, orchestrationController: OrchestrationController? = nil) {
        self.appState = appState
        self.audioCaptureService = AudioCaptureService()
        self.vadService = VADService(configuration: settings.vadConfiguration)
        self.sttService = STTService()
        self.conversationManager = conversationManager
        self.orchestrationController = orchestrationController
        self.defaultConversationState = .closed(
            windowSeconds: settings.conversationWindowSeconds,
            maxTurns: settings.conversationMaxTurns
        )

        conversationTask = Task { [weak self] in
            guard let self else { return }
            for await state in conversationManager.stateStream {
                await MainActor.run {
                    self.appState.conversationState = state
                }
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
                            self.orchestrationController?.handleFinalTranscript(event.text)
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

                        if result.didStartSpeech {
                            try? sttService.startUtterance()
                            await MainActor.run {
                                self.appState.assistantStatus = .processing
                            }
                        }

                        if result.isSpeech {
                            sttService.appendAudioFrame(frame)
                        }

                        if result.didEndSpeech {
                            sttService.endUtterance()
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
        Task {
            await conversationManager.closeWindow()
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
}
