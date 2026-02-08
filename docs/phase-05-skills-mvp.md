# Phase 05: Skills MVP

**Overview**
Implement the first three skills (WeatherKit, MusicKit, Reminders) and wire permission gating into onboarding and settings.

**Status (as of Feb 8, 2026)**
Completed so far:
- Step 1: PermissionManager + skill enablement UI (onboarding + settings).
- Step 2: Weather skill + units + attribution.
- Step 3: Music skill + AirPlay route picker.
- Step 4: Reminders skill (EventKit CRUD with list/title clarification).
- Step 5: Destructive confirmation flow (remove from playlist only).
- Step 6: Skill result mapping + tool summaries + logging integration.

**Implementation Notes / Deviations**
- Music playlist editing (`addToPlaylist`/`removeFromPlaylist`) is stubbed to return an error on macOS because MusicKit library playlist editing APIs are unavailable on macOS. (To revisit if a viable AppleScript/MediaPlayer workaround is desired.)
- AirPlay route picker uses `AVRoutePickerView` without `prioritizesVideoDevices` (unavailable on macOS).
- Added a “Quit Prism” item in the menu bar popover to make permission reset testing feasible.
- Weather location permission handling on macOS uses `startUpdatingLocation()` to force prompts, plus debug logs for class/instance status. Added `NSLocationUsageDescription` for prompting reliability.
- Startup permission preflight now requests core + skill permissions sequentially (microphone, dictation, location, music, reminders).
- Skills settings now reflect OS permission state; toggles cannot disable OS-granted permissions (must be revoked in System Settings).
- Reset Settings clears settings, memory entries, speaker profiles/embeddings, LLM config, and onboarding flag.

**Scope**
In scope:
- WeatherKit skill with location permissions, current + minute + daily datasets
- MusicKit skill with Apple Music authorization and playback commands (ApplicationMusicPlayer)
- Reminders skill with EventKit authorization and CRUD
- Skill enable/disable and permission gating with status rows
- AirPlay route picker in onboarding, settings, and popover
- Speech-driven destructive confirmation (remove from playlist only)

Out of scope:
- HomeKit, Calendar, Messages, Shortcuts
- External plugin system

**Dependencies**
- WeatherKit
- CoreLocation (location permission)
- MusicKit
- EventKit (Reminders)
- SkillRegistry

**Design**
- Each skill is implemented behind the `Skill` protocol with a clear tool schema.
- Tool schemas are strict JSON with enumerated actions.
- Skills are only exposed to the LLM when enabled and when permission is granted.
- Skill execution returns a natural-language summary string for the LLM, plus structured data.
- Destructive actions (remove from playlist) require confirmation via conversation flow.

**Public Interfaces**
- `WeatherSkill` (current, minute, daily; free-form location)
- `MusicSkill` (play, pause, resume, skip, shuffle, addToPlaylist)
- `RemindersSkill` (create, update, remove, list, complete)
- `PermissionManager` (request, status, explanations)
- `SkillResult`/`ToolResult` (status, summary, data, errors)
- `PendingConfirmation` (destructive confirmation state)

**Implementation Steps**
1. Implement `PermissionManager` and wire toggles in onboarding and Settings > Skills (with status rows).
   - Done. Files added/updated:
     - `Sources/PrismCore/Skills/PermissionManager.swift`
     - `Sources/PrismCore/Skills/SkillRegistry.swift` (permission gating)
     - `Prism/Prism/Views/Settings/PermissionsChecklistView.swift`
     - `Prism/Prism/Views/Settings/SkillsSettingsView.swift`
     - `Prism/Prism/Persistence/Stores/SettingsKeys.swift` (skill enablement keys + weather units key)
     - `Sources/PrismCore/Diagnostics/PrismLogger.swift` (skillInfo logging)
     - Tests updated: `Tests/PrismCoreTests/SkillRegistryTests.swift`, `Tests/PrismCoreTests/OrchestrationPipelineTests.swift`
Build/Run Gate: Clean (Cmd+Shift+K), Build (Cmd+B), Run (Cmd+R).
2. Implement WeatherKit skill with location permission, current + minute + daily datasets, and free-form geocoding.
   - Add units setting (system default + override) and Weather attribution in Settings footer.
   - Done. Files added/updated:
     - `Sources/PrismCore/Skills/WeatherSkill.swift`
     - `Sources/PrismCore/Skills/WeatherLocationProvider.swift`
     - `Sources/PrismCore/Skills/WeatherUnits.swift`
     - `Prism/Prism/Views/Settings/WeatherUnitsPickerView.swift`
     - `Prism/Prism/Views/Settings/WeatherAttributionView.swift`
     - Entitlements: `Prism/Prism/Prism.entitlements` (WeatherKit + location/reminders/calendars)
     - Info.plist usage keys in `Prism/Prism.xcodeproj/project.pbxproj`
     - Registration: `Prism/Prism/AppDelegate.swift`
Build/Run Gate: Clean (Cmd+Shift+K), Build (Cmd+B), Run (Cmd+R).
3. Implement MusicKit skill with authorization and ApplicationMusicPlayer playback.
   - Library-first search, fallback to catalog.
   - Add AirPlay route picker in onboarding, Settings > Audio, and popover.
   - Done. Files added/updated:
     - `Sources/PrismCore/Skills/MusicSkill.swift`
     - `Prism/Prism/Views/AirPlayRoutePickerView.swift`
     - `Prism/Prism/Views/Onboarding/OnboardingView.swift`
     - `Prism/Prism/Views/Settings/AudioSettingsView.swift`
     - `Prism/Prism/ContentView.swift`
     - Registration: `Prism/Prism/AppDelegate.swift`
Build/Run Gate: Clean (Cmd+Shift+K), Build (Cmd+B), Run (Cmd+R).
4. Implement Reminders skill with EventKit authorization and CRUD.
   - Require list name or prompt for clarification (no default list).
   - Done. Files added/updated:
     - `Sources/PrismCore/Skills/RemindersSkill.swift`
     - Registration: `Prism/Prism/AppDelegate.swift`
Build/Run Gate: Clean (Cmd+Shift+K), Build (Cmd+B), Run (Cmd+R).
5. Implement destructive confirmation flow for remove-from-playlist only.
   - Done. Files added/updated:
     - `Sources/PrismCore/Orchestration/ConfirmationParser.swift`
     - `Sources/PrismCore/Orchestration/OrchestrationPipeline.swift`
     - `Sources/PrismCore/Skills/MusicSkill.swift` (pending confirmation)
Build/Run Gate: Clean (Cmd+Shift+K), Build (Cmd+B), Run (Cmd+R).
6. Ensure skill registry exposes only enabled and authorized skills.
   - Log skill inputs/outputs in Xcode debug log.
   - Done. Files added/updated:
     - `Sources/PrismCore/Skills/SkillResult.swift`
     - `Sources/PrismCore/Skills/Skill.swift`
     - `Sources/PrismCore/Skills/WeatherSkill.swift`
     - `Sources/PrismCore/Skills/RemindersSkill.swift`
     - `Sources/PrismCore/Skills/MusicSkill.swift`
     - `Sources/PrismCore/Skills/ToolArguments.swift`
     - `Sources/PrismCore/LLM/JSONValue.swift`
     - `Sources/PrismCore/Agents/ResponderAgent.swift`
     - `Sources/PrismCore/Orchestration/OrchestrationPipeline.swift`
     - `Prism/Prism/Views/Settings/PermissionsChecklistView.swift`
     - Tests updated: `Tests/PrismCoreTests/OrchestrationPipelineTests.swift`, `Tests/PrismCoreTests/SkillRegistryTests.swift`
Build/Run Gate: Clean (Cmd+Shift+K), Build (Cmd+B), Run (Cmd+R).

**Tests**
- Unit: skill gating by permission
- Integration: WeatherKit request with location permission
- Integration: MusicKit authorization and playback
- Integration: Reminders CRUD in selected list with clarification prompts
- UX: confirmation prompts for destructive actions (remove from playlist only)
- UX: AirPlay route picker placement (onboarding + settings + popover)

**Risks & Open Questions**
- Risk: Permission prompts can be confusing. Mitigation: add concise explanations in onboarding.
- Risk: Apple Music subscription differences. Mitigation: detect availability and show fallback messaging.
- Risk: AirPlay routing cannot be set programmatically. Mitigation: expose route picker and explain user control.

**Mermaid Diagram**
```mermaid
flowchart LR
  A["LLM Tool Call"] --> B["Skill Registry"]
  B --> C["Permission Check"]
  C --> D["Skill Execution"]
  D --> E["Result"]
  C --> F["Denied Response"]
```
