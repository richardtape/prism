//
//  EnrollmentCoordinator.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Combine
import Foundation
import PrismCore

/// Coordinates the enrollment flow and sample capture lifecycle.
@MainActor
final class EnrollmentCoordinator: ObservableObject {
    @Published var displayName: String = ""
    @Published private(set) var promptIndex: Int = 0
    @Published private(set) var session: EnrollmentSession
    @Published private(set) var isRecording = false
    @Published private(set) var statusText: String = ""
    @Published private(set) var embeddings: [SpeakerEmbedding] = []
    @Published private(set) var profiles: [SpeakerProfile] = []
    @Published private(set) var flowStep: EnrollmentFlowStep = .intro

    private let promptsProvider: @MainActor (String) -> [String]
    private let captureDuration: TimeInterval
    private let audioCaptureService = AudioCaptureService()
    private let speakerIDService: SpeakerIDService
    private let defaultThreshold: Float = 0.75
    private let minimumAverageRMS: Float = 0.005
    private var recordingTask: Task<Void, Never>?
    private var hasSavedProfile = false
    private var activePrompts: [String] = []

    init(
        extractor: SpeakerEmbeddingExtractor = StubSpeakerEmbeddingModel(),
        promptsProvider: @escaping @MainActor (String) -> [String] = EnrollmentPrompts.scriptedPrompts(for:),
        captureDuration: TimeInterval = 2.0
    ) {
        self.promptsProvider = promptsProvider
        self.captureDuration = captureDuration
        self.session = EnrollmentSession(promptIndex: 0, totalPrompts: 1)
        self.speakerIDService = SpeakerIDService(extractor: extractor)
    }

    var currentPrompt: String {
        guard !activePrompts.isEmpty else { return "" }
        if promptIndex >= activePrompts.count {
            return "Enrollment complete."
        }
        return activePrompts[promptIndex]
    }

    var totalPrompts: Int {
        activePrompts.count
    }

    var isComplete: Bool {
        session.isComplete
    }

    func loadProfiles() {
        do {
            let queue = try Database().queue
            let store = SpeakerProfileStore(queue: queue)
            profiles = try store.fetchProfiles()
            if flowStep == .intro || flowStep == .list {
                flowStep = profiles.isEmpty ? .intro : .list
            }
        } catch {
            statusText = "Unable to load enrolled voices yet."
            profiles = []
            flowStep = .intro
        }
    }

    func beginAddVoice() {
        displayName = ""
        promptIndex = 0
        embeddings = []
        activePrompts = []
        session = EnrollmentSession(promptIndex: 0, totalPrompts: 1)
        statusText = ""
        isRecording = false
        hasSavedProfile = false
        flowStep = .name
    }

    func cancelAddVoice() {
        recordingTask?.cancel()
        audioCaptureService.stop()
        isRecording = false
        statusText = ""
        flowStep = profiles.isEmpty ? .intro : .list
    }

    func confirmName() {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusText = "Enter a display name before continuing."
            return
        }

        activePrompts = promptsProvider(trimmed)
        promptIndex = 0
        embeddings = []
        session = EnrollmentSession(promptIndex: 0, totalPrompts: activePrompts.count)
        statusText = ""
        flowStep = .samples
    }

    func recordSample() {
        guard !isRecording else { return }
        guard flowStep == .samples else { return }
        guard promptIndex < activePrompts.count else { return }
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusText = "Enter a display name before recording."
            return
        }

        statusText = ""
        isRecording = true

        recordingTask?.cancel()
        recordingTask = Task { [weak self] in
            guard let self else { return }
            var frames: [AudioFrame] = []

            defer {
                audioCaptureService.stop()
                Task { @MainActor in
                    self.isRecording = false
                }
            }

            do {
                let stream = try await audioCaptureService.start()
                let start = Date()

                for await frame in stream {
                    frames.append(frame)
                    if Date().timeIntervalSince(start) >= captureDuration {
                        break
                    }
                }

                guard !frames.isEmpty else {
                    await MainActor.run {
                        self.statusText = "No audio captured. Try again."
                    }
                    return
                }

                let averageRMS = frames.reduce(0) { $0 + $1.rms } / Float(frames.count)
                guard averageRMS >= minimumAverageRMS else {
                    await MainActor.run {
                        self.statusText = "No speech detected. Check your microphone and try again."
                    }
                    return
                }

                let embedding = try await speakerIDService.extractEmbedding(from: frames)
                await MainActor.run {
                    self.embeddings.append(embedding)
                    self.advancePrompt()
                    self.statusText = "Sample captured."
                }
            } catch {
                await MainActor.run {
                    self.statusText = "Unable to record sample. Check microphone permission."
                }
            }
        }
    }

    func restart() {
        recordingTask?.cancel()
        audioCaptureService.stop()
        promptIndex = 0
        embeddings = []
        session = EnrollmentSession(promptIndex: 0, totalPrompts: max(1, activePrompts.count))
        statusText = ""
        isRecording = false
        hasSavedProfile = false
    }

    func restartSamples() {
        guard flowStep == .samples else { return }
        promptIndex = 0
        embeddings = []
        session = EnrollmentSession(promptIndex: 0, totalPrompts: max(1, activePrompts.count))
        statusText = ""
    }

    func cancelRecordingIfNeeded() {
        guard isRecording else { return }
        recordingTask?.cancel()
        audioCaptureService.stop()
        isRecording = false
        statusText = "Recording canceled."
    }

    private func advancePrompt() {
        promptIndex += 1
        if promptIndex >= activePrompts.count {
            session = EnrollmentSession(promptIndex: activePrompts.count, totalPrompts: activePrompts.count, result: .completed)
            persistProfileIfNeeded()
            flowStep = .completion
        } else {
            session = EnrollmentSession(promptIndex: promptIndex, totalPrompts: activePrompts.count)
        }
    }

    private func persistProfileIfNeeded() {
        guard session.isComplete, !hasSavedProfile else { return }
        hasSavedProfile = true

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Speaker" : trimmedName
        let threshold = loadThreshold()
        let profile = SpeakerProfile(id: UUID(), displayName: resolvedName, threshold: threshold, embeddings: embeddings)

        Task { [weak self] in
            guard let self else { return }
            do {
                let queue = try Database().queue
                let store = SpeakerProfileStore(queue: queue)
                try store.saveProfile(profile)
                await MainActor.run {
                    self.statusText = "Enrollment saved."
                }
            } catch {
                await MainActor.run {
                    self.statusText = "Unable to save enrollment yet."
                    self.hasSavedProfile = false
                }
            }
        }
    }

    func finishCompletion() {
        loadProfiles()
        flowStep = profiles.isEmpty ? .intro : .list
    }

    func deleteProfile(_ profile: SpeakerProfile) {
        do {
            let queue = try Database().queue
            let store = SpeakerProfileStore(queue: queue)
            try store.deleteProfile(id: profile.id)
            loadProfiles()
        } catch {
            statusText = "Unable to delete voice yet."
        }
    }

    private func loadThreshold() -> Float {
        do {
            let queue = try Database().queue
            let store = SettingsStore(queue: queue)
            if let value = try store.readValue(for: SettingsKeys.speakerIdMatchThreshold), let threshold = Float(value) {
                return threshold
            }
        } catch {
            return defaultThreshold
        }
        return defaultThreshold
    }
}
