# CubeNet AI Squad

![Version](https://img.shields.io/badge/version-4.0.0--alpha-blue)
![TF2](https://img.shields.io/badge/Game-Team%20Fortress%202-red)
![SourceMod](https://img.shields.io/badge/SourceMod-1.11%2B-orange)
![SQLite](https://img.shields.io/badge/Database-SQLite-blue)
![Status](https://img.shields.io/badge/Status-Active%20Development-brightgreen)
![License](https://img.shields.io/badge/License-MIT-yellow)

**Modular AI framework for Team Fortress 2 bots** featuring persistent identities, personalities, voice systems, statistics, and extensible SourceMod modules.

Unlike Valve’s default bots, every bot receives a permanent identity that survives map changes and server restarts.

---

## Features

- **Persistent Identities** – Fixed names & profiles stored in SQLite
- **Personality System** – Aggression, Defense, Teamwork, Risk, Objective focus
- **Statistics Tracking** – Kills, Deaths, Assists, Wins, Losses
- **Voice System** – Chat announcements on spawn / kill / death / objective
- **AFK Replacement** – Seamless bot takeover when players go idle

---

## Architecture
Player
│
▼
AFK Replacement          →  cubenet_ai_afk.sp
│
▼
Bot Manager              →  cubenet_ai_core.sp
│
├── Profiles
├── Statistics
└── Voices             →  cubenet_ai_voice.sp
│
▼
SQLite (ss_botmanager)
textFull details → [docs/architecture.md](docs/architecture.md)

---

## Quick Start

1. Compile the plugins (see [docs/INSTALL.md](docs/INSTALL.md))
2. Place `.smx` files in `addons/sourcemod/plugins/`
3. Copy configs into `addons/sourcemod/configs/`
4. Load order:
cubenet_ai_core
cubenet_ai_voice
cubenet_ai_afk
text**Full guide:** [docs/INSTALL.md](docs/INSTALL.md)

---

## Documentation

| Document | Description |
|----------|-------------|
| [Installation](docs/INSTALL.md) | Build, deploy & configure |
| [Architecture](docs/architecture.md) | Module overview & data flow |
| [Database](docs/database.md) | SQLite schema |
| [Personalities](docs/personalities.md) | Attribute system |
| [Voice System](docs/voice-system.md) | Chat voice lines |
| [AFK System](docs/afk-system.md) | Idle replacement |
| [Roadmap](docs/roadmap.md) | Version plan |
| [Future Features](docs/future-features.md) | Long-term vision |

---

## Repository Layout
src/                  SourcePawn plugins
configs/              Roster, voices, personalities
docs/                 Full documentation
sql/                  Schema & migrations
LICENSE
CHANGELOG.md
VERSION
text---

## Status

- **Version:** 4.0.0-alpha
- **License:** [MIT](LICENSE)
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)

---

Created for **CubeNet Game Servers**.
