# CubeNet AI Squad

![Version](https://img.shields.io/badge/version-4.0.0--alpha-blue)
![Game](https://img.shields.io/badge/Game-Team%20Fortress%202-red)
![SourceMod](https://img.shields.io/badge/SourceMod-1.11%2B-orange)
![SourcePawn](https://img.shields.io/badge/Language-SourcePawn-yellow)
![Database](https://img.shields.io/badge/Database-SQLite-blue)
![Status](https://img.shields.io/badge/Status-Active%20Development-brightgreen)
![License](https://img.shields.io/github/license/cube-source/CubeNet-AI-Squad)

# Persistent AI Teammates for Team Fortress 2

CubeNet AI Squad is a modular AI framework for **Team Fortress 2 dedicated servers** built with **SourceMod and SourcePawn**.

The goal of CubeNet AI Squad is to transform ordinary TF2 bots into persistent AI-controlled teammates with:

- Persistent identities
- Configurable personalities
- Long-term statistics
- Voice interactions
- Progression systems
- Expandable AI behaviors

Unlike Valve's default bots, CubeNet AI Squad treats every bot as a unique member of the server community.

---

# Project Vision

Traditional TF2 bots are temporary gameplay fillers. They spawn, fight, and disappear.

CubeNet AI Squad explores a different approach:

> What if bots were persistent players?

The long-term vision is to create AI teammates that have:

- Names
- Personalities
- Statistics
- History
- Preferred play styles
- Strengths and weaknesses
- Unique behaviors

The goal is not simply to make smarter bots.

The goal is to create a living AI ecosystem for Team Fortress 2 servers.

---

# Project Goals

CubeNet AI Squad is built around several core principles:

- Every bot should have an identity
- AI behavior should be configurable
- Systems should remain modular
- Server performance comes first
- Features should be documented
- New systems should extend the framework instead of replacing it

---

# Features

## Persistent Identities

Every AI bot receives a permanent profile.

Profiles are designed to store:

- Bot name
- Personality traits
- Preferred classes
- Statistics
- History
- Future progression data

---

## Personality System

Bots are designed around configurable behavior traits:

- Aggression
- Defense
- Teamwork
- Risk tolerance
- Objective focus
- Play style

The goal is to make every AI teammate feel different.

---

## Statistics Tracking

The framework supports persistent tracking of:

- Kills
- Deaths
- Assists
- Wins
- Losses
- Objectives
- Performance history

---

## Voice System

The voice framework provides AI communication events including:

- Spawn announcements
- Kill responses
- Death responses
- Objective notifications
- Future personality-driven dialogue

---

## AFK Replacement

Automatically replace inactive players with AI teammates while maintaining team balance.

The goal is to keep matches active without disrupting gameplay.

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

                   AI Core Framework
                  cubenet_ai_core.sp

        +-------------------+-------------------+
        |                   |                   |
        v                   v                   v

    Profiles          Statistics          Personalities

        |                   |                   |
        +-------------------+-------------------+
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

Full details:

Architecture Documentation

Modular Framework Design

CubeNet AI Squad is intentionally divided into independent SourceMod modules.

This provides:

Easier development
Easier debugging
Better server customization
Future community extensions
Cleaner long-term maintenance

Current and planned modules:

AI Core
Profiles
Statistics
Personality Engine
Voice System
AFK Replacement
Navigation
Progression
Squad Intelligence
Repository Structure
CubeNet-AI-Squad/

├── src/
│   ├── SourcePawn plugins
│   └── Shared include APIs
│
├── configs/
│   ├── Bot rosters
│   ├── Personality definitions
│   └── Voice configuration
│
├── sql/
│   ├── Database schema
│   └── Future migrations
│
├── docs/
│   └── Project documentation
│
├── tools/
│   └── Development utilities
│
├── examples/
│   └── Sample configurations
│
├── assets/
│   └── Project artwork
│
└── .github/
    └── GitHub automation
Current Modules
AI Core

The foundation framework.

Responsibilities:

Module communication
Shared APIs
Event handling
Configuration management
Common utilities
Profiles

Persistent AI identity system.

Future capabilities:

Individual bot history
Personality storage
Skill progression
Class preferences
Statistics

Persistent gameplay tracking.

Future capabilities:

Performance ranking
Historical records
Progression systems
Personality Engine

Behavior modification framework.

Future capabilities:

Different combat styles
Team behaviors
Decision weighting
Individual AI traits
Voice System

Communication framework.

Future capabilities:

Personality-based dialogue
Context awareness
Dynamic responses
Roadmap
Version 4.x — Foundation

Current development phase.

Completed:

Repository architecture
Documentation structure
Modular plugin layout
Shared include framework
Version 4.x — Persistence

Next milestone.

Planned:

SQLite profile database
Persistent bot identities
Statistics storage
Profile loading system
Version 5.x — Personality Engine

Planned:

Dynamic behaviors
Individual play styles
Decision modifiers
Version 6.x — Squad Intelligence

Planned:

Team coordination
Tactical behavior
Objective planning
Group decision making
Future Development

Long-term possibilities:

Persistent campaigns
AI rivalries
Server events
Advanced navigation
Adaptive behavior research
AI-driven game modes
Developer API

CubeNet AI Squad is designed as an extensible framework.

Future plugins should be able to register with the AI ecosystem.

Example:

#include <cubenet_ai>

public void OnPluginStart()
{
    CubeNet_RegisterModule("Example");
}
Quick Start
Requirements
Team Fortress 2 Dedicated Server
SourceMod 1.11+
SourcePawn compiler
Installation
Compile the SourcePawn plugins.
Copy compiled plugins:
addons/sourcemod/plugins/
Copy configuration files:
addons/sourcemod/configs/
Load modules:
cubenet_ai_core
cubenet_ai_voice
cubenet_ai_afk

Full installation documentation:

Installation Guide

Documentation
Document	Description
Architecture	System design and data flow
Database	SQLite structure
Personalities	AI behavior system
Voice System	Communication framework
AFK System	Player replacement logic
Roadmap	Development plans
Future Features	Long-term vision
Current Status

Version:

4.0.0-alpha

Status:

Active Development

Current focus:

Core framework
Persistent profiles
Database integration
AI module communication
Voice architecture
Contributing

Contributions are welcome.

Areas where help is valuable:

SourcePawn development
TF2 testing
Documentation
AI behavior design
Server testing

Please review:

CONTRIBUTING.md
CODE_OF_CONDUCT.md
SECURITY.md

before contributing.

License

CubeNet AI Squad is released under the MIT License.

See:

LICENSE

Created For

CubeNet Game Servers

Building the future of persistent AI teammates in Team Fortress 2.
