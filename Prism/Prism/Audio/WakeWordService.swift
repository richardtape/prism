//
//  WakeWordService.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import AVFoundation
import CoreML
import Foundation
import SoundAnalysis

/// Default model constants used by the wake-word pipeline.
enum WakeWordModelDefaults {
    static let modelName = "WakeWordClassifier"
    static let labels = ["prism"]
    static let cooldownSeconds: TimeInterval = 1.0
}

/// Wake-word detection result emitted by the SoundAnalysis pipeline.
struct WakeWordDetection: Sendable, Equatable {
    let label: String
    let confidence: Double
    let timestamp: Date
}

/// SoundAnalysis wrapper for streaming wake-word classification.
final class WakeWordService {
    struct Configuration: Sendable, Equatable {
        let targetLabels: [String]
        let minConfidence: Double
        let cooldownSeconds: TimeInterval

        static let `default` = Configuration(
            targetLabels: ["prism"],
            minConfidence: 0.6,
            cooldownSeconds: 1.0
        )
    }

    private let configuration: Configuration
    private let analysisQueue = DispatchQueue(label: "Prism.WakeWordService.Analysis")
    private var analyzer: SNAudioStreamAnalyzer?
    private var request: SNClassifySoundRequest?
    private var observer: WakeWordSoundObserver?
    private var lastDetectionTime: Date?

    /// Callback invoked when a wake-word detection occurs.
    var onDetect: ((WakeWordDetection) -> Void)?

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    /// Returns true when the bundled wake-word model exists on disk.
    static func isModelAvailable(named name: String, bundle: Bundle = .main) -> Bool {
        (try? WakeWordModelLoader.modelURL(named: name, bundle: bundle)) != nil
    }

    /// Loads a bundled Core ML sound classifier and returns a SoundAnalysis request.
    static func loadRequest(modelName: String, bundle: Bundle = .main) throws -> SNClassifySoundRequest {
        let url = try WakeWordModelLoader.modelURL(named: modelName, bundle: bundle)
        let model = try MLModel(contentsOf: url)
        return try SNClassifySoundRequest(mlModel: model)
    }

    /// Starts the streaming classifier with the given request and audio format.
    func start(request: SNClassifySoundRequest, format: AVAudioFormat) throws {
        stop()
        analyzer = SNAudioStreamAnalyzer(format: format)
        let observer = WakeWordSoundObserver(configuration: configuration) { [weak self] detection in
            self?.handle(detection)
        }
        self.observer = observer
        self.request = request
        try analyzer?.add(request, withObserver: observer)
    }

    /// Stops analysis and clears the current request.
    func stop() {
        if let request {
            analyzer?.remove(request)
        }
        analyzer = nil
        observer = nil
        request = nil
        lastDetectionTime = nil
    }

    /// Feeds an audio buffer into the analyzer.
    func process(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let analyzer else { return }
        analysisQueue.async {
            analyzer.analyze(buffer, atAudioFramePosition: time.sampleTime)
        }
    }

    private func handle(_ detection: WakeWordDetection) {
        if let lastDetectionTime {
            let elapsed = detection.timestamp.timeIntervalSince(lastDetectionTime)
            if elapsed < configuration.cooldownSeconds {
                return
            }
        }
        lastDetectionTime = detection.timestamp
        onDetect?(detection)
    }
}

private enum WakeWordModelLoader {
    enum LoadError: Error {
        case modelNotFound(String)
    }

    static func modelURL(named name: String, bundle: Bundle) throws -> URL {
        if let url = bundle.url(forResource: name, withExtension: "mlmodelc") {
            return url
        }
        if let url = bundle.url(forResource: name, withExtension: "mlmodel") {
            return url
        }
        throw LoadError.modelNotFound(name)
    }
}

private final class WakeWordSoundObserver: NSObject, SNResultsObserving {
    private let configuration: WakeWordService.Configuration
    private let onDetect: (WakeWordDetection) -> Void
    private let labelSet: Set<String>

    init(configuration: WakeWordService.Configuration, onDetect: @escaping (WakeWordDetection) -> Void) {
        self.configuration = configuration
        self.onDetect = onDetect
        self.labelSet = Set(configuration.targetLabels.map { $0.lowercased() })
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        guard let best = result.classifications.first else { return }

        let label = best.identifier.lowercased()
        guard labelSet.contains(label) else { return }
        let confidence = Double(best.confidence)
        guard confidence >= configuration.minConfidence else { return }

        let detection = WakeWordDetection(
            label: label,
            confidence: confidence,
            timestamp: Date()
        )
        onDetect(detection)
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        // Failures are handled by the caller when restarting the service.
        _ = error
    }
}
