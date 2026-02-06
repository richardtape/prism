//
//  AudioCaptureService.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import AVFoundation
import Foundation
import PrismCore

/// Errors that can occur while starting the audio capture pipeline.
enum AudioCaptureError: Error {
    case permissionDenied
    case invalidFormat
    case failedToStartEngine
}

/// Captures microphone audio and emits frames for downstream processing.
final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private var continuation: AsyncStream<AudioFrame>.Continuation?
    private var audioStream: AsyncStream<AudioFrame>?
    private(set) var isRunning = false
    private var frameIndex = 0
    private var tapInstalled = false

    /// Callback for audio level updates in normalized 0...1 range.
    var onAudioLevel: ((Double) -> Void)?

    /// Starts capturing audio and returns a stream of audio frames.
    func start() async throws -> AsyncStream<AudioFrame> {
        if let audioStream, isRunning {
            return audioStream
        }

        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        guard granted else {
            throw AudioCaptureError.permissionDenied
        }

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: hardwareFormat.sampleRate, channels: 1) else {
            throw AudioCaptureError.invalidFormat
        }

        let frameDuration: TimeInterval = 0.02
        let bufferSize = AVAudioFrameCount(hardwareFormat.sampleRate * frameDuration)

        let stream = AsyncStream<AudioFrame>(bufferingPolicy: .bufferingNewest(6)) { continuation in
            self.continuation = continuation
        }
        audioStream = stream

        if !tapInstalled {
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
                self?.handle(buffer: buffer, time: time)
            }
            tapInstalled = true
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            continuation?.finish()
            continuation = nil
            audioStream = nil
            throw AudioCaptureError.failedToStartEngine
        }

        isRunning = true
        return stream
    }

    /// Stops audio capture and closes the stream.
    func stop() {
        guard isRunning else { return }
        engine.stop()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        continuation?.finish()
        continuation = nil
        audioStream = nil
        isRunning = false
        frameIndex = 0
    }

    private func handle(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData else { return }
        let channel = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var samples = [Float](repeating: 0, count: frameLength)
        samples.withUnsafeMutableBufferPointer { destination in
            destination.baseAddress?.update(from: channel, count: frameLength)
        }

        let rms = AudioCaptureService.calculateRMS(samples: samples)
        let normalizedLevel = min(max(Double(rms) * 4.0, 0), 1)
        onAudioLevel?(normalizedLevel)

        let frame = AudioFrame(
            samples: samples,
            rms: rms,
            timestamp: time.hostTime == 0 ? Date() : Date(),
            sampleRate: buffer.format.sampleRate,
            frameIndex: frameIndex
        )
        frameIndex += 1

        continuation?.yield(frame)
    }

    private static func calculateRMS(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        return sqrt(sum / Float(samples.count))
    }
}
