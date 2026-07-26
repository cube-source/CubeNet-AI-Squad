# CubeNet AI Squad

![Version](https://img.shields.io/badge/version-4.0.0--alpha-blue)
![TF2](https://img.shields.io/badge/Game-Team%20Fortress%202-red)
![SourceMod](https://img.shields.io/badge/SourceMod-1.11%2B-orange)
![SourcePawn](https://img.shields.io/badge/Language-SourcePawn-yellow)
![SQLite](https://img.shields.io/badge/Database-SQLite-blue)
![Status](https://img.shields.io/badge/Status-Active%20Development-brightgreen)
![License](https://img.shields.io/github/license/cube-source/CubeNet-AI-Squad)

# Persistent AI Teammates for Team Fortress 2

CubeNet AI Squad is a modular AI framework for **Team Fortress 2 dedicated servers** built with **SourceMod and SourcePawn**.

The goal is to transform ordinary TF2 bots into persistent AI-controlled teammates with:

- Permanent identities
- Configurable personalities
- Long-term statistics
- Voice interactions
- Persistent progression
- Expandable AI behaviors

Unlike Valve's default bots, CubeNet AI Squad treats every bot as a unique member of the server community.

---

# Vision

Traditional TF2 bots are temporary entities created to fill empty player slots.

CubeNet AI Squad explores a different approach:

> What if bots were persistent players?

Each AI teammate can eventually have:

- A name
- A personality
- A history
- Statistics
- Preferred classes
- Relationships
- Strengths and weaknesses
- Unique behaviors

The long-term goal is to create an extensible AI ecosystem for TF2 servers.

---

# Project Goals

CubeNet AI Squad is built around these principles:

- Every bot should have an identity
- AI behavior should be configurable
- Systems should remain modular
- Server performance comes first
- Features should be documented
- New capabilities should extend the framework instead of replacing it

---

# Features

## Current Features

### Persistent Identities

Bots receive permanent profiles stored through SQLite.

Future profile data includes:

- Name
- Class preference
- Personality
- Skill level
- Statistics
- History

---

### Personality Framework

Bots are designed around configurable traits:

- Aggression
- Defense
- Teamwork
- Risk tolerance
- Objective focus

The goal is to make every AI teammate feel different.

---

### Statistics Tracking

Framework support for:

- Kills
- Deaths
- Assists
- Wins
- Losses
- Objectives

---

### Voice System

AI communication framework supporting:

- Spawn announcements
- Kill responses
- Death responses
- Objective events
- Future personality-driven dialogue

---

### AFK Replacement

Automatically replaces inactive players with AI teammates while maintaining team balance.

---

# Architecture

```text
                         Players
                            |
                            v

                 AFK Replacement Module
                  cubenet_ai_afk.sp

                            |
                            v

                  CubeNet AI Core Engine
                  cubenet_ai_core.sp

          +-----------------+----------------+
          |                 |                |
          v                 v                v

      Profiles       Personality        Statistics

          |                 |                |

          +-----------------+----------------+

                            |
                            v

                    Voice System
                 cubenet_ai_voice.sp

                            |
                            v

                    SQLite Database

                            |
                            v

                 Future AI Extensions
Modular Design

CubeNet AI Squad is intentionally divided into independent SourceMod modules.

This allows:

Easier development
Easier debugging
Selective feature installation
Future community extensions

Planned modules include:

AI Core
Profiles
Statistics
Personality
Voice
AFK Replacement
Navigation
Progression
Squad Intelligence
Repository Structure
CubeNet-AI-Squad/

src/
 ├── SourcePawn plugins
 └── shared include APIs

configs/
 ├── Bot rosters
 ├── Personality definitions
 └── Voice configuration

sql/
 └── Database schema and migrations

docs/
 └── Project documentation

tools/
 └── Development utilities

examples/
 └── Sample configurations

assets/
 └── Project artwork
Roadmap
Version 4.x — Foundation

Current development phase.

 Repository architecture
 Documentation framework
 Modular plugin layout
 Shared include system
Version 4.x — Persistence

Planned:

SQLite database integration
Persistent bot profiles
Statistics storage
Profile management
Version 5.x — Personality Engine

Planned:

Dynamic behavior modifiers
Individual play styles
Decision weighting
Version 6.x — Squad Intelligence

Planned:

Team coordination
Tactical decisions
Objective planning
Future Research

Long-term exploration:

Adaptive AI behavior
Persistent campaigns
Server-wide events
Advanced bot learning systems
Developer API

The framework is designed around shared APIs.

Future plugins should be able to register with the CubeNet AI ecosystem.

Example:

#include <cubenet_ai>

public void OnPluginStart()
{
    CubeNet_RegisterModule("Example");
}
Documentation
Document	Description
Architecture	System design and data flow
Database	SQLite structure
Personalities	AI behavior system
Voice System	Communication framework
AFK System	Replacement logic
Roadmap	Future development
Current Status

Version:

4.0.0-alpha

Status:

Active Development

The foundation architecture is currently being developed.

The next major milestones are:

Database persistence
AI profiles
Voice framework
Personality engine
Contributing

Contributions are welcome.

Areas needing help:

SourcePawn development
TF2 testing
Documentation
AI behavior design
Server testing

Please review:

CONTRIBUTING.md
CODE_OF_CONDUCT.md
SECURITY.md
License

CubeNet AI Squad is released under the MIT License.

See:

LICENSE
Created For

CubeNet Game Servers

Building the future of persistent AI teammates in Team Fortress 2.
