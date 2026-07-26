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
- Name protection

### Personality System
Configurable attributes per bot:
- Aggression, Defense, Teamwork, Risk, Objective focus
- Combat style string

### Statistics Tracking
- Kills, Deaths, Assists, Wins, Losses
- Auto-saved to SQLite

### Voice System
Chat announcements on spawn, kill, death, and objective events.

### AFK Replacement
Replaces idle players with AI bots and restores them when they return.  
*(Currently under active polish)*

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
textFull details: [docs/architecture.md](docs/architecture.md)

---

## Repository Layout
src/
cubenet_ai_core.sp
cubenet_ai_afk.sp
cubenet_ai_voice.sp
include/
configs/
ss_bot_roster.cfg
ss_botvoices.cfg
personalities.cfg
docs/
INSTALL.md
architecture.md
database.md
personalities.md
voice-system.md
afk-system.md
roadmap.md
future-features.md
sql/
LICENSE
CHANGELOG.md
VERSION
text---

## Quick Start

1. Compile the plugins (see [docs/INSTALL.md](docs/INSTALL.md))
2. Place `.smx` files in `addons/sourcemod/plugins/`
3. Copy configs into `addons/sourcemod/configs/`
4. Load order:
cubenet_ai_core
cubenet_ai_voice
cubenet_ai_afk
text**Full installation guide:** [docs/INSTALL.md](docs/INSTALL.md)

---

## Documentation

| Document | Description |
|----------|-------------|
| [Installation](docs/INSTALL.md) | Build, deploy, configure |
| [Architecture](docs/architecture.md) | Module overview |
| [Database](docs/database.md) | SQLite schema |
| [Personalities](docs/personalities.md) | Attribute system |
| [Voice System](docs/voice-system.md) | Chat voice lines |
| [AFK System](docs/afk-system.md) | Idle replacement |
| [Roadmap](docs/roadmap.md) | Version plan |
| [Future Features](docs/future-features.md) | Long-term vision |

---

## Status

- **Version:** 4.0.0-alpha
- **License:** [MIT](LICENSE)
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)

---

Created for **CubeNet Game Servers**.
