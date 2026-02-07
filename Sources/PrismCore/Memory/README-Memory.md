# Memory

Core memory types and storage helpers for per-speaker memory entries.

**Purpose**
This module defines the data model and persistence APIs used to store and retrieve memory entries associated with a speaker profile.

**Contents**
- `MemoryEntry`: Immutable value type representing a single memory item.
- `MemorySessionSummary`: A compact session summary passed to the memory agent.
- `MemoryStore`: GRDB-backed CRUD operations for memory entries.

**Storage**
- SQLite table: `memory_entries` (migration: `Migration_003_MemoryEntries.sql`).
- Entries are keyed by `id` and associated with `profile_id`.

**Usage**
App-level code is expected to:
1. Build a `MemorySessionSummary` from a closed conversation.
2. Call `MemoryAgent` to generate entries.
3. Persist entries via `MemoryStore`.

This module does not perform any orchestration or UI work.
