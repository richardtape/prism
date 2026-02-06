//
//  STTService.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import AVFoundation
import Foundation
import PrismCore
import Speech

/// Errors encountered when configuring on-device speech recognition.
enum STTError: Error {
    case authorizationDenied
    case recognizerUnavailable
    case onDeviceUnavailable
}

/// Streaming Speech framework wrapper for live transcription.
final class STTService {
    private let recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var streamContinuation: AsyncStream<TranscriptEvent>.Continuation?
    private var stream: AsyncStream<TranscriptEvent>?
    private var currentUtteranceID = UUID()

    /// Optional handler invoked when speech recognition errors occur.
    var onError: ((String) -> Void)?

    init(locale: Locale = .current) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    /// Starts the transcript event stream and requests authorization when needed.
    func startStreaming() async throws -> AsyncStream<TranscriptEvent> {
        if let stream {
            return stream
        }

        let status = await requestAuthorization()
        guard status == .authorized else {
            throw STTError.authorizationDenied
        }

        guard let recognizer else {
            throw STTError.recognizerUnavailable
        }

        guard recognizer.supportsOnDeviceRecognition else {
            throw STTError.onDeviceUnavailable
        }

        let stream = AsyncStream<TranscriptEvent>(bufferingPolicy: .bufferingNewest(12)) { continuation in
            self.streamContinuation = continuation
        }
        self.stream = stream
        return stream
    }

    /// Begins a new utterance recognition request.
    func startUtterance() throws {
        guard let recognizer else {
            throw STTError.recognizerUnavailable
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.requiresOnDeviceRecognition = true
        recognitionRequest?.taskHint = .dictation

        currentUtteranceID = UUID()

        guard let recognitionRequest else { return }
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handle(result: result, error: error)
        }
    }

    /// Appends audio frames to the active utterance request.
    func appendAudioFrame(_ frame: AudioFrame) {
        guard let recognitionRequest else { return }
        guard !frame.samples.isEmpty else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: frame.sampleRate, channels: 1) else { return }

        let frameCount = AVAudioFrameCount(frame.samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        frame.samples.withUnsafeBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else { return }
            buffer.floatChannelData?.pointee.update(from: baseAddress, count: frame.samples.count)
        }

        recognitionRequest.append(buffer)
    }

    /// Ends the current utterance without tearing down the stream.
    func endUtterance() {
        recognitionRequest?.endAudio()
    }

    /// Stops streaming and cleans up recognition tasks.
    func stopStreaming() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        streamContinuation?.finish()
        streamContinuation = nil
        stream = nil
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error {
            onError?("Speech recognition error: \(error.localizedDescription)")
            return
        }

        guard let result else { return }
        let transcript = result.bestTranscription.formattedString
        let confidence = averageConfidence(from: result.bestTranscription)
        let event = TranscriptEvent(
            text: transcript,
            isFinal: result.isFinal,
            confidence: confidence,
            timestamp: Date(),
            utteranceID: currentUtteranceID
        )
        streamContinuation?.yield(event)
    }

    private func averageConfidence(from transcription: SFTranscription) -> Double? {
        let segments = transcription.segments
        guard !segments.isEmpty else { return nil }
        let total = segments.reduce(0.0) { $0 + Double($1.confidence) }
        return total / Double(segments.count)
    }

    private func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
