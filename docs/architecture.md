Markdown# Architecture

CubeNet AI Squad is a modular SourceMod plugin suite. Each major concern lives in its own plugin so features can be developed, enabled, or disabled independently while sharing a common identity and data model.

## High-Level Overview
┌─────────────────────┐
│   Human Players     │
└──────────┬──────────┘
│
┌──────────▼──────────┐
│  AFK Replacement    │  cubenet_ai_afk.sp
│  (idle detection &  │
│   seamless swap)    │
└──────────┬──────────┘
│
┌──────────▼──────────┐
│    Bot Manager      │  cubenet_ai_core.sp
│  (identity, roster, │
│   stats, name lock) │
└──────────┬──────────┘
┌───────────────────┼───────────────────┐
│                   │                   │
┌──────────▼──────────┐ ┌──────▼──────┐ ┌──────────▼──────────┐
│     Profiles        │ │ Statistics  │ │      Voices         │
│  (in-memory + DB)   │ │  (kills,    │ │  cubenet_ai_voice.sp│
│                     │ │   deaths…)  │ │                     │
└──────────┬──────────┘ └──────┬──────┘ └─────────────────────┘
│                   │
└─────────┬─────────┘
│
┌────────▼────────┐
│     SQLite      │
│  ss_botmanager  │
└─────────────────┘
text## Plugin Responsibilities

| Plugin                    | Role                                      | Status          |
|---------------------------|-------------------------------------------|-----------------|
| `cubenet_ai_core.sp`      | Roster loading, profile assignment, name protection, basic stats, SQLite | Implemented    |
| `cubenet_ai_voice.sp`     | Event-driven chat voice lines             | Implemented    |
| `cubenet_ai_afk.sp`       | AFK detection, bot takeover, player restore | Implemented (polish ongoing) |
| `cubenet_ai_personality.sp` | Runtime personality influence on bot behavior | Placeholder   |
| `cubenet_ai_profiles.sp`  | Advanced profile management               | Placeholder   |
| `cubenet_ai_statistics.sp`| Richer stats / leaderboards               | Placeholder   |
| `cubenet_ai_navigation.sp`| Custom navigation / pathing helpers       | Placeholder   |
| `cubenet_ai_progression.sp` | Skill growth / memory                     | Placeholder   |

## Data Flow

1. **Server start / plugin load**
   - Core opens (or recreates) the SQLite database.
   - Core loads `configs/ss_bot_roster.cfg` into an in-memory array of `BotProfile` structs.
   - Each profile is inserted into the `bots` table.

2. **Bot joins**
   - `OnClientPutInServer` → timer → `AssignProfile()`.
   - Next sequential profile from the roster is applied (name + attributes).
   - Name is locked and re-applied on spawn / name-change attempts.

3. **Gameplay events**
   - Death / heal events update in-memory kill / death / assist counters.
   - Voice plugin reacts to spawn, death, kill, and objective events and prints chat lines.
   - Stats are flushed to SQLite every 5 minutes and on map end.

4. **AFK path**
   - AFK plugin tracks last activity.
   - After warning threshold → takeover threshold, player is moved to spectator and a new bot is added.
   - Core assigns the next available profile to that bot.
   - On player activity the bot is kicked and the human is restored (team, class, position).

## Shared Concepts

- **BotProfile** – central data structure (name, class, skill, style, five personality integers, five stat counters).
- **Name protection** – continuous enforcement that a bot keeps its assigned identity.
- **Sequential assignment** – currently profiles are handed out in roster order. Future versions will support smarter matching (class preference, team balance, etc.).

## Load Order Recommendation
cubenet_ai_core
cubenet_ai_voice
cubenet_ai_afk
(any future modules)
textCore must load first so the database and profile array exist before other plugins try to use them.

## Extension Points

Future modules are expected to:

- Read personality values from the core profile array or database.
- Hook the same gameplay events or add new ones.
- Use the shared include headers (once populated) for constants, profile accessors, and debug helpers.
