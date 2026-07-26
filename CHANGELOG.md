# Changelog

All notable changes to CubeNet AI Squad will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [4.0.0-alpha] - 2026-07-26

### Added
- Initial public repository structure
- `cubenet_ai_core.sp` – persistent bot identities, roster loading, SQLite storage, basic statistics, name protection
- `cubenet_ai_voice.sp` – event-driven chat voice lines (spawn / kill / death / objective)
- `cubenet_ai_afk.sp` – AFK detection, warning, bot takeover, and player restore system
- Example `ss_bot_roster.cfg` with eight sample squad members
- Example `ss_botvoices.cfg` with personality-flavoured lines
- Placeholder `personalities.cfg` for future use
- Full documentation set under `docs/`
- Installation guide, MIT license, and this changelog

### Notes
- Database is currently reset on every core plugin load (development behaviour)
- AFK system is functional but still under active polish
- Personality attributes are stored and exposed but not yet used to drive bot AI decisions
- Several modules and all shared includes remain empty placeholders for upcoming work
