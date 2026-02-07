//
//  SpeakerProfileStore.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation
import GRDB

/// GRDB store for speaker profiles and embeddings.
public final class SpeakerProfileStore {
    private let queue: DatabaseQueue
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let dateFormatter = ISO8601DateFormatter()

    public init(queue: DatabaseQueue) {
        self.queue = queue
    }

    /// Creates and persists a new speaker profile.
    public func createProfile(displayName: String, threshold: Float, embeddings: [SpeakerEmbedding]) throws -> SpeakerProfile {
        let profile = SpeakerProfile(id: UUID(), displayName: displayName, threshold: threshold, embeddings: embeddings)
        try saveProfile(profile)
        return profile
    }

    /// Inserts or updates a speaker profile and its embeddings.
    public func saveProfile(_ profile: SpeakerProfile, date: Date = Date()) throws {
        let timestamp = dateFormatter.string(from: date)
        try queue.write { db in
            try db.execute(
                sql: """
                INSERT INTO speaker_profiles (id, display_name, threshold, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    display_name = excluded.display_name,
                    threshold = excluded.threshold,
                    updated_at = excluded.updated_at
                """,
                arguments: [profile.id.uuidString, profile.displayName, profile.threshold, timestamp, timestamp]
            )

            try db.execute(
                sql: "DELETE FROM speaker_embeddings WHERE profile_id = ?",
                arguments: [profile.id.uuidString]
            )

            for embedding in profile.embeddings {
                let embeddingID = UUID().uuidString
                let vectorJSON = try encodeVector(embedding.vector)
                let createdAt = dateFormatter.string(from: embedding.createdAt)
                try db.execute(
                    sql: """
                    INSERT INTO speaker_embeddings (id, profile_id, vector_json, created_at)
                    VALUES (?, ?, ?, ?)
                    """,
                    arguments: [embeddingID, profile.id.uuidString, vectorJSON, createdAt]
                )
            }
        }
    }

    /// Fetches all profiles with their embeddings.
    public func fetchProfiles() throws -> [SpeakerProfile] {
        try queue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT id, display_name, threshold FROM speaker_profiles ORDER BY created_at ASC")
            return try rows.map { row in
                let idString: String = row["id"]
                let name: String = row["display_name"]
                let threshold: Double = row["threshold"]
                let embeddings = try fetchEmbeddings(for: idString, db: db)
                let id = UUID(uuidString: idString) ?? UUID()
                return SpeakerProfile(id: id, displayName: name, threshold: Float(threshold), embeddings: embeddings)
            }
        }
    }

    /// Fetches a single profile by id.
    public func fetchProfile(id: UUID) throws -> SpeakerProfile? {
        try queue.read { db in
            let row = try Row.fetchOne(db, sql: "SELECT id, display_name, threshold FROM speaker_profiles WHERE id = ?", arguments: [id.uuidString])
            guard let row else { return nil }
            let name: String = row["display_name"]
            let threshold: Double = row["threshold"]
            let embeddings = try fetchEmbeddings(for: id.uuidString, db: db)
            return SpeakerProfile(id: id, displayName: name, threshold: Float(threshold), embeddings: embeddings)
        }
    }

    /// Deletes a speaker profile and its embeddings.
    public func deleteProfile(id: UUID) throws {
        try queue.write { db in
            try db.execute(sql: "DELETE FROM speaker_embeddings WHERE profile_id = ?", arguments: [id.uuidString])
            try db.execute(sql: "DELETE FROM speaker_profiles WHERE id = ?", arguments: [id.uuidString])
        }
    }

    private func fetchEmbeddings(for profileID: String, db: Database) throws -> [SpeakerEmbedding] {
        let rows = try Row.fetchAll(
            db,
            sql: "SELECT vector_json, created_at FROM speaker_embeddings WHERE profile_id = ? ORDER BY created_at ASC",
            arguments: [profileID]
        )

        return rows.compactMap { row in
            let json: String = row["vector_json"]
            let createdAtString: String = row["created_at"]
            let vector = decodeVector(json)
            let createdAt = dateFormatter.date(from: createdAtString) ?? Date()
            guard !vector.isEmpty else { return nil }
            return SpeakerEmbedding(vector: vector, createdAt: createdAt)
        }
    }

    private func encodeVector(_ vector: [Float]) throws -> String {
        let data = try encoder.encode(vector)
        guard let json = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return json
    }

    private func decodeVector(_ json: String) -> [Float] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? decoder.decode([Float].self, from: data)) ?? []
    }
}
