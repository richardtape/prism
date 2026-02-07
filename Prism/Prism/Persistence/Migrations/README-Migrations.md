# Migrations

SQL migrations for the Prism database. Files are applied in filename order.

**Note on updates**
- Add new migrations as new files (do not edit existing migrations once shipped).
- Phase 03 migrations include:
  - `Migration_002_SpeakerProfiles.sql`
  - `Migration_003_MemoryEntries.sql`
