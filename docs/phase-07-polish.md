# Phase 07: Polish

**Overview**
This phase is a living backlog for polish work discovered during earlier phases. Items are added over time as real usage reveals UX gaps, reliability issues, or fit-and-finish opportunities.

**Scope**
In scope:
- UX refinements and small workflow improvements
- Reliability and quality-of-life fixes discovered during dogfooding
- Minor performance tweaks that do not change core architecture

Out of scope:
- New major features that belong in earlier phases
- Large architecture changes or redesigns

**Dependencies**
- None specific; each item should list its own dependencies if needed.

**Design**
- Keep each item small and focused.
- Prefer additive changes with minimal risk.
- Update this file as new polish tasks are discovered.

**Public Interfaces**
- No global changes by default. Each item documents any API impacts.

**Implementation Steps**
1. Upgrade enrollment to auto-record/auto-advance.
   - Use VAD to start recording when speech begins and stop on silence.
   - Auto-advance to the next prompt after a sample is captured.
   - Keep a short pre-roll so the first word is captured reliably.
   Build/Run Gate: Clean (Cmd+Shift+K), Build (Cmd+B), Run (Cmd+R).
2. Add active-state styling for the menu-bar status item when the popover is open.
   - Match native macOS behavior with a pill-shaped highlighted background behind the status item icon.
   - Ensure the highlight appears only while the popover is visible and resets when closed.
   Build/Run Gate: Clean (Cmd+Shift+K), Build (Cmd+B), Run (Cmd+R).
3. Rework permission toggle UX to keep Settings open and centralize first-run permissions in onboarding.
   - Keep Settings window open after permission prompts complete.
   - On first launch, defer all permission prompts until the onboarding flow guides the user step-by-step.
   Build/Run Gate: Clean (Cmd+Shift+K), Build (Cmd+B), Run (Cmd+R).

**Tests**
- Manual: enroll with low-volume speech, pauses, and quick successive prompts.
- Unit (optional): VAD start/stop triggers for enrollment capture.

**Risks & Open Questions**
- Risk: auto-advance might feel too fast for some users. Mitigation: allow a brief countdown or configurable delay.
- Risk: silence detection may cut off short utterances. Mitigation: tune VAD thresholds or add a minimum capture window.
