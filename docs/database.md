# Database

CubeNet AI Squad uses SourceMod’s built-in SQLite support.

## Database Name
ss_botmanager
textThe database file is created automatically in the SourceMod data directory.

## Schema (current)

Created by `cubenet_ai_core.sp` on plugin start:

```sql
CREATE TABLE bots (
  id          INTEGER PRIMARY KEY,
  name        TEXT,
  class       TEXT,
  skill       INTEGER,
  style       TEXT,
  aggression  INTEGER,
  defense     INTEGER,
  teamwork    INTEGER,
  risk        INTEGER,
  objective   INTEGER,
  kills       INTEGER DEFAULT 0,
  deaths      INTEGER DEFAULT 0,
  assists     INTEGER DEFAULT 0,
  wins        INTEGER DEFAULT 0,
  losses      INTEGER DEFAULT 0
);
Current Behaviour (v4.0.0-alpha)

On every plugin load the core drops the bots table if it exists and recreates it.
All profiles from the roster are then inserted with zeroed statistics.
This is convenient for development but destructive. It will be replaced with proper “create-if-not-exists + migration” logic before any production release.

Data Lifecycle

Roster → in-memory BotProfile array + INSERT into bots.
Gameplay events update the in-memory counters.
Every 300 seconds and on OnMapEnd the counters are written back with:

SQLUPDATE bots SET kills=?, deaths=?, assists=? WHERE name=?;
Wins / losses are present in the schema but not yet updated by any event hooks.
Future Schema Ideas

Separate bot_stats history table for per-map or per-session records.
bot_memory or bot_events table for long-term learning data.
Soft-delete / archive flag instead of hard DROP.
Indexes on name and possibly class.

Manual Inspection
You can open the database with any SQLite tool (DB Browser for SQLite, sqlite3 CLI, etc.) once the server has run the core plugin at least once.
text---

### `docs/personalities.md`

```markdown
# Personality System

Every bot in CubeNet AI Squad carries a set of numeric personality attributes plus a free-form style string. These values are loaded from the roster config, stored in the database, and kept in memory for the lifetime of the server.

## Attributes

| Attribute    | Range (typical) | Meaning                                      |
|--------------|-----------------|----------------------------------------------|
| Aggression   | 0–100           | How eagerly the bot seeks fights             |
| Defense      | 0–100           | Preference for holding ground / protecting   |
| Teamwork     | 0–100           | Likelihood of sticking with or assisting allies |
| Risk         | 0–100           | Willingness to take dangerous plays          |
| Objective    | 0–100           | Focus on the map objective vs. fragging      |

In addition:

- **skill** – integer used as a rough skill tier (currently informational).
- **style** – short string label (e.g. `"Defensive"`, `"Aggressive"`, `"Support"`).

## Example Profile
Name:        Parker
Class:       Engineer
Style:       Defensive
Skill:       2
Aggression:  30
Defense:     95
Teamwork:    90
Risk:        20
Objective:   100
text## Current Usage (v4)

- Attributes are loaded and persisted.
- They are **not yet** used to drive actual bot decision-making.
- The values exist so that future modules (`cubenet_ai_personality.sp`, navigation, combat helpers, etc.) can read them and influence TF2 bot behaviour or custom logic.

## Planned Runtime Influence

Future versions will map the attributes to concrete behaviours, for example:

- High Aggression + low Defense → more aggressive push timings, less turtling.
- High Teamwork → prioritise healing / protecting teammates, stick closer to the group.
- High Objective → path toward control points / payload more aggressively.
- Style string may select different voice packs or animation preferences.

## Configuration

All values are defined in `configs/ss_bot_roster.cfg` under each bot’s KeyValues block. Defaults used by the loader if a key is missing are 50 for the five personality integers and 2 for skill.
