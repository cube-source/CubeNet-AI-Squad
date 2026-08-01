# Changelog

All notable changes to CubeNet AI Squad will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [4.2.1] - 2026-07-27

### Changed
- **AFK System Rewrite:** Shifted from spectator-swap pipeline to a **Same-Entity Possession** model. AI now drives the human client directly via .
- **Architecture Change:** Now requires the **CBaseNPC** extension for navmesh pathfinding and movement on Linux.
- **Platform Optimization:** Optimized for **Linux 32-bit** environments (CBaseNPC requirement).

### Added
- Unstuck logic and class-specific combat ranges.
- Basic Medic healing support and Engineer building/wrenching.
- Spy weapon slot support (WIP).
- , , and  commands for manual control.

### Known Issues
- Aim pitch bias still under tuning.
- Spy cloak reliability vs stock bots.
- Pathing can occasionally snag corners compared to native NextBots.

## [4.0.0-alpha] - 2026-07-26

### Added
- Initial public repository structure
-  – persistent bot identities, roster loading, SQLite storage
-  – event-driven chat voice lines
-  – original AFK detection and spectator-swap system
- Example configs and full documentation set
