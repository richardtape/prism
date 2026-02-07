//
//  SpeakerMatchController.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation
import PrismCore

/// Resolves embeddings to known speaker profiles.
final class SpeakerMatchController {
    private let service: SpeakerIDService
    private let settings: SpeakerIDSettings
    private let store: SpeakerProfileStore

    init(extractor: SpeakerEmbeddingExtractor, settings: SpeakerIDSettings, store: SpeakerProfileStore) {
        self.service = SpeakerIDService(extractor: extractor)
        self.settings = settings
        self.store = store
    }

    func match(embedding: SpeakerEmbedding) throws -> SpeakerMatch? {
        let profiles = try store.fetchProfiles()
        guard !profiles.isEmpty else { return nil }
        return service.match(embedding: embedding, against: profiles, defaultThreshold: settings.matchThreshold)
    }
}
