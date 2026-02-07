-- Speaker profiles and embeddings for Phase 03.

CREATE TABLE IF NOT EXISTS speaker_profiles (
    id TEXT PRIMARY KEY NOT NULL,
    display_name TEXT NOT NULL,
    threshold REAL NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS speaker_embeddings (
    id TEXT PRIMARY KEY NOT NULL,
    profile_id TEXT NOT NULL,
    vector_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(profile_id) REFERENCES speaker_profiles(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_speaker_embeddings_profile_id
    ON speaker_embeddings(profile_id);
