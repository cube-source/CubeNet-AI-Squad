# CubeNet AI Squad

![TF2](https://img.shields.io/badge/Game-Team%20Fortress%202-red)

![SourceMod](https://img.shields.io/badge/SourceMod-1.12-orange)

![SQLite](https://img.shields.io/badge/Database-SQLite-blue)

![Status](https://img.shields.io/badge/Status-Active%20Development-green)

![License](https://img.shields.io/badge/License-MIT-yellow)

Persistent AI personalities for Team Fortress 2 built on SourceMod.

CubeNet AI Squad transforms ordinary TF2 bots into persistent squad members with unique identities, personalities, statistics, voice interactions, and future learning capabilities.

Unlike Valve's default bots, CubeNet AI Squad gives every bot a permanent identity that survives map changes and server restarts while laying the groundwork for adaptive AI behavior.

---

## Current Features

### Persistent Bot Identities

- Fixed names
- Persistent profiles
- Custom personalities
- Role specializations
- SQLite database backend

### Personality System

Every bot contains configurable attributes including:

- Aggression
- Defense
- Teamwork
- Risk taking
- Objective focus
- Combat style

Example:

```
Name: Parker
Class: Engineer
Style: Defensive

Aggression: 30
Defense: 95
Teamwork: 90
Objective: 100
```

---

### Statistics Tracking

Each profile records:

- Kills
- Deaths
- Assists
- Wins
- Losses

Statistics are automatically saved to SQLite.

---

### Voice System

Dynamic voice events based on gameplay.

Examples:

- Spawn
- Kill
- Death
- Revenge
- Capture
- Defend

Future versions will support personality-specific voice packs.

---

### AFK Replacement

(Currently under active redevelopment)

Automatically replaces idle players with AI-controlled bots while preserving:

- Team
- Class
- Position
- Identity

Future versions will support seamless player rejoin.

---

## Architecture

```
          Player
             │
             ▼

      AFK Replacement

             │

             ▼

        Bot Manager

             │

   ┌─────────┼──────────┐

   ▼         ▼          ▼

Profiles  Statistics  Voices

             │

             ▼

          SQLite
```

---

## Project Goals

CubeNet AI Squad is designed to eventually support:

- Persistent AI memory
- Individual skill progression
- Team coordination
- Squad leadership
- Dynamic personalities
- Voice interaction
- Weapon preferences
- Adaptive combat learning
- Long-term statistics
- Campaign persistence

---

## Repository Layout

```
plugins/
    ss_botmanager.sp
    ss_botnames.sp
    ss_voice.sp
    ss_afkbot.sp

configs/
    ss_bot_roster.cfg

docs/

database/
```

---

## Requirements

See REQUIREMENTS.md

---

## Current Status

Current Release:

Version 4.x Development

Status:

Active Development

---

## Roadmap

Version 4

- Persistent identities
- SQLite profiles
- Statistics
- Voice framework

Version 5

- Stable AFK replacement
- Better Bot Manager integration
- Personality improvements

Version 6

- AI learning
- Squad tactics
- Dynamic difficulty
- Memory system

---

## License

MIT License

---

Created for CubeNet Game Servers
