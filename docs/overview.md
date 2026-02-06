# Prism Overview

**Purpose**
This document provides a high-level view of the Prism macOS assistant, including architecture, goals, and how all phases fit together. Read this before starting any phase work.

**Product Summary**
Prism is a native macOS menu-bar assistant that runs 24x7 on a Mac mini. It listens continuously, detects a wake word anywhere in an utterance, transcribes speech, identifies the speaker, and uses an LLM to respond or execute skills via macOS APIs.

**Primary Goals**
- Native macOS feel, accessory app with menu-bar UI
- Low latency, responsive assistant (<1.5s to first response)
- Robust wake word detection and speaker identification
- Skill-based action system with permission gating
- Clear onboarding and settings for setup, permissions, and enrollment

**Non-Goals (for MVP)**
- Text-to-speech responses
- External plugin system for skills
- HomeKit, Calendar, Messages, Shortcuts integrations
- Cloud-based speech or speaker ID

**Target Environment**
- macOS 26.2
- Xcode 26.2
- Apple Silicon Mac mini

**High-Level Architecture**
- Menu-bar accessory app with a SwiftUI popover
- Continuous audio pipeline with async processing
- Hybrid wake word detection (acoustic + text)
- Multi-agent LLM orchestration
- Skill registry with explicit permissions
- Local persistence using SQLite (GRDB)

**Core Pipeline (Async)**
Mic -> AudioEngine -> VAD -> STT -> Speaker ID -> Wake Word -> LLM -> Action Plan -> Skills -> Response

**Key Subsystems**
- **UI Shell**: Menu bar icon, popover, settings, onboarding
- **Audio Pipeline**: Capture, VAD, STT, speaker ID, wake word detection
- **LLM Orchestration**: Router, Planner, Responder, Memory agent
- **Skills System**: WeatherKit, MusicKit, Reminders (MVP)
- **Persistence**: Settings, profiles, memory, logs

**Conversation Model**
- Wake word can appear anywhere in the utterance
- After a wake-word command, a follow-up window opens for 15 seconds
- Max 5 turns per session by default
- After each follow-up the window timer resets back to 15 seconds
- Closing phrases ("thank you", "cancel" etc.) end the session immediately
- Follow-ups only accepted for recognized speakers, if follow-up speaker isn't recognized, it prompts for who is speaking

**Speaker Identification**
- On-device embeddings model via Core ML
- Enrollment uses 10 scripted + 5 free samples
- Unknown speakers are prompted to identify or enroll

**Wake Word Strategy**
- Acoustic keyword spotting with SoundAnalysis + Create ML model
- Text-based fallback with alias list and normalization
- In-app calibration for sensitivity tuning

**LLM Strategy**
- OpenAI-compatible endpoint
- Bearer token auth
- Model discovery via `/v1/models` with manual override
- Streaming responses when supported

**Skills and Permissions**
- Skills are compiled in and registered at startup
- Each skill defines a typed tool schema
- Skills are only exposed when enabled and authorized
- Destructive actions require confirmation

**Data and Storage**
- SQLite via GRDB for profiles, memory, settings
- Config file for LLM endpoint and API key
- Transcript logging is opt-in and manual purge only

**Performance Targets**
- <1.5s from wake word to first response token
- Continuous listening with low CPU/memory drift

**Security and Privacy**
- Local-only processing by default
- No telemetry or external crash reporting
- Opt-in transcript logs, no audio storage
- Memory is editable and opt-out

**Coding Style**
- Well-documented, both inline and docblocks, code.
- Code comments are USEFUL not just 'describing' what the code is
- Files should be small and single-purpose.
- Create directory-level readme files which explain what the files in that directory does.

**Reading Order**
1. `overview.md` - this document
2. `README.md`
3. Phase document based on what you are working on

**Assumptions**
- Services are globally configured, memory is per-user
- Accessory app, no dock icon
- SwiftUI-first UI
