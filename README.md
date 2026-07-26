# CubeNet AI Squad

![Version](https://img.shields.io/badge/version-4.0.0--alpha-blue)
![TF2](https://img.shields.io/badge/Game-Team%20Fortress%202-red)
![SourceMod](https://img.shields.io/badge/SourceMod-1.11%2B-orange)
![SQLite](https://img.shields.io/badge/Database-SQLite-blue)
![Status](https://img.shields.io/badge/Status-Active%20Development-brightgreen)
![License](https://img.shields.io/badge/License-MIT-yellow)

**Persistent AI personalities for Team Fortress 2 built on SourceMod.**

CubeNet AI Squad turns ordinary TF2 bots into persistent squad members with unique identities, personalities, statistics, voice interactions, and a foundation for future adaptive AI.

Unlike Valve’s default bots, every bot receives a permanent identity that survives map changes and server restarts.

---

## Features

### Persistent Bot Identities
- Fixed names and profiles loaded from config
- SQLite backend
- Role / class specializations
- Name protection (re-applied on spawn and name-change attempts)

### Personality System
Configurable attributes per bot:
- Aggression, Defense, Teamwork, Risk, Objective focus
- Combat style string

Example:
Name: Parker
Class: Engineer
Style: Defensive
Aggression: 30
Defense: 95
Teamwork: 90
Objective: 100
text### Statistics Tracking
Per-profile counters (auto-saved to SQLite every 5 minutes + on map end):
- Kills, Deaths, Assists, Wins, Losses

### Voice System
Chat-based announcements triggered by gameplay events (spawn, kill, death, objective).  
Configurable per-bot lines with cooldowns. Personality-specific voice packs planned.

### AFK Replacement
Detects idle human players, moves them to spectator, spawns a replacement bot, and restores the player (team, class, position) when they return.  
*Currently under active polish.*

---

## Architecture
┌──────────────┐
│    Player    │
└──────┬───────┘
│
▼
┌──────────────────┐
│ AFK Replacement  │  cubenet_ai_afk.sp
└──────┬───────────┘
│
▼
┌──────────────────┐
│   Bot Manager    │  cubenet_ai_core.sp
└──────┬───────────┘
│
├────────────┬────────────┐
▼            ▼            ▼
Profiles     Statistics     Voices
(cubenet_ai_voice.sp)
│            │            │
└────────────┴────────────┘
│
▼
┌─────────┐
│ SQLite  │
└─────────┘
textFull details: [docs/architecture.md](docs/architecture.md)

---

## Repository Layout
src/
cubenet_ai_core.sp          # Profiles, DB, stats, name protection
cubenet_ai_afk.sp           # AFK detection + replacement
cubenet_ai_voice.sp         # Event-driven voice lines
cubenet_ai_*.sp             # Future modules (placeholders)
include/                    # Shared headers (stubs)
configs/
ss_bot_roster.cfg           # Bot identities & attributes
ss_botvoices.cfg            # Voice lines
personalities.cfg           # Future personality templates
docs/
INSTALL.md                  # Full installation guide
architecture.md
database.md
personalities.md
voice-system.md
afk-system.md
roadmap.md
future-features.md
sql/
schema.sql
migrations/
examples/
tools/
LICENSE
CHANGELOG.md
VERSION
text---

## Quick Start

1. Compile the plugins (see [docs/INSTALL.md](docs/INSTALL.md)).
2. Place the `.smx` files in `addons/sourcemod/plugins/`.
3. Copy the example configs into `addons/sourcemod/configs/`.
4. Load in this order:
cubenet_ai_core
cubenet_ai_voice
cubenet_ai_afk
text5. Add bots normally (`tf_bot_add`). Core assigns persistent profiles from the roster.

**Full instructions:** [docs/INSTALL.md](docs/INSTALL.md)

---

## Documentation

| Document | Description |
|----------|-------------|
| [Installation](docs/INSTALL.md) | Build, deploy, and configure |
| [Architecture](docs/architecture.md) | Module overview and data flow |
| [Database](docs/database.md) | SQLite schema and lifecycle |
| [Personalities](docs/personalities.md) | Attribute system |
| [Voice System](docs/voice-system.md) | Chat voice lines and config |
| [AFK System](docs/afk-system.md) | Idle replacement behaviour |
| [Roadmap](docs/roadmap.md) | Version plan |
| [Future Features](docs/future-features.md) | Long-term vision |

---

## Current Status

- **Version:** 4.0.0-alpha (see [`VERSION`](VERSION))
- **Status:** Active development
- **License:** [MIT](LICENSE)

**v4 focus:** Persistent identities, SQLite, basic stats, voice framework, AFK replacement (stabilizing).

See [CHANGELOG.md](CHANGELOG.md) and [docs/roadmap.md](docs/roadmap.md) for details.

---

## Contributing

Contributions are welcome. Please open an issue first for larger changes.

See [CONTRIBUTING.md](CONTRIBUTING.md) (placeholder – to be expanded).

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for the full text.
MIT License
Copyright (c) 2026 CubeNet / cube-source
text---

Created for **CubeNet Game Servers**.
