-- Memory entries for Phase 03.

CREATE TABLE IF NOT EXISTS memory_entries (
    id TEXT PRIMARY KEY NOT NULL,
    profile_id TEXT NOT NULL,
    body TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY(profile_id) REFERENCES speaker_profiles(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_memory_entries_profile_id
    ON memory_entries(profile_id);
