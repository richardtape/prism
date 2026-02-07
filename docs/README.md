# Prism Phase Docs

**Purpose**
This folder contains implementation-ready phase documents for building Prism, a native macOS menu-bar assistant. Each phase is intended to be executed by a junior developer with minimal ambiguity.

**How to Read and Execute These Plans**
1. Read `overview.md` to understand the entire project.
2. Read this readme, then the phase doc you are implementing.
3. Implement the steps in order.
4. After each major step, ask the user to run the Build/Run Gate as specified.
5. Log findings and update Risks/Open Questions as you discover new issues.

**Global Conventions**
- Each phase uses the same template sections for consistency.
- Build/Run Gate format: Clean (Cmd+Shift+K), Build (Cmd+B), Run (Cmd+R).
- Mermaid diagrams are included for data flow and lifecycle understanding.

**Project Overview**
- [Project Overview](overview.md)

**Phase Order**
- [Phase 00: Foundation](phase-00-foundation.md)
- [Phase 01: Audio Capture + STT + Conversation Window](phase-01-audio-stt.md)
- [Phase 02: LLM Orchestration + Tooling Core](phase-02-llm-orchestration.md)
- [Phase 03: Speaker ID + Enrollment + Memory](phase-03-speaker-id-memory.md)
- [Phase 04: Wake Word Hybrid](phase-04-wake-word.md)
- [Phase 05: Skills MVP](phase-05-skills-mvp.md)
- [Phase 06: Performance + Reliability](phase-06-performance-reliability.md)
- [Phase 07: Polish (Living Backlog)](phase-07-polish.md)
- [Phase 08: Speaker ID Model Training + Core ML Integration](phase-08-speaker-id-model.md)

**Phase Status**
- Phase 00: Foundation — Complete (February 6, 2026). See `phase-00-foundation.md` for adjustments and deviations.
- Phase 01–06: Pending.
- Phase 07: Polish — Active (living document; add items as discovered).
- Phase 08: Speaker ID Model — Draft (offline training + Core ML integration plan).

**Assumptions**
- macOS 26.2, Xcode 26.2, Apple Silicon Mac mini.
- SwiftUI-first UI with AppKit bridging only when necessary.
- No code changes outside what is called out in each phase.
