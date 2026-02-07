# Memory

App-level coordination for session tracking and memory persistence.

**Purpose**
This folder owns the session lifecycle and wiring needed to trigger memory updates after a conversation closes.

**Contents**
- `ConversationSessionTracker`: Collects user/assistant turns during an open conversation window.
- `MemoryCoordinator`: Runs `MemoryAgent` and persists entries via `MemoryStore`.

**Lifecycle**
1. When a final transcript is accepted, the tracker records the user utterance.
2. When the responder finishes, the tracker records the assistant reply.
3. When the conversation window closes, the tracker emits a `MemorySessionSummary`.
4. `MemoryCoordinator` runs the memory agent and saves entries to SQLite.

**Settings**
- `memory.enabled` in the settings table gates whether memory is written.

**Notes**
- Memory is best-effort; failures should not interrupt the audio pipeline.
- UI for viewing/editing memory lives in Settings (Phase 03 Step 7).
