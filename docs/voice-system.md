# Event-Driven Dialogue System

The Voice System, implemented in `cubenet_ai_voice.sp`, provides bots with a living presence through personality-driven chat announcements. Rather than random spam, the system uses an event-driven architecture to trigger dialogue based on specific gameplay milestones.

## Technical Implementation

### 1. Event Hooking
The system binds to several critical SourceMod events:
- `player_spawn`: Triggers entry lines as the bot joins the fight.
- `player_death`: Triggers reaction lines upon elimination.
- `teamplay_point_captured`: Triggers objective-based dialogue.

### 2. Profile-Based Lookup
To ensure that a Defensive Engineer doesn't sound like an Aggressive Scout, the system performs a filtered lookup:
1. **Identity Stripping:** The system strips the `[SS]` prefix from the bot's name to find the base profile ID.
2. **KeyValues Ingestion:** It queries `configs/ss_botvoices.cfg`, which is structured as a nested KeyValues map (`Bot \u2192 Event \u2192 Line`).
3. **Weighted Randomization:** A random line is selected from the available pool for that specific bot and event, ensuring variety in dialogue.

## Anti-Spam & Cooldown Logic
To prevent the chat from becoming cluttered during high-action moments, we implemented a tiered cooldown system:

| Event Category | Cooldown | Design Justification |
| :--- | :--- | :--- |
| **General Dialogue** | 190s | Maintains a steady but unobtrusive presence. |
| **Kill/Combat Lines** | 300s | High-impact lines are rare to keep them feeling significant. |
| **Objective Logic** | Probability-based | Objective lines trigger on a 20% chance to avoid repetition on every capture. |

## Configuration Schema
The `ss_botvoices.cfg` file follows a strict hierarchy:
`BotName \u2192 EventType \u2192 LineID \u2192 Text`. 
This allows us to add new bots or modify existing personalities without touching the source code.

## Future Architecture Goals
- **Contextual Awareness:** Transitioning from simple event triggers to state-aware dialogue (e.g., reacting to being healed by a specific teammate).
- **Audio Integration:** Moving beyond chat text to integrate custom  files for true voice acting.
- **Shared API:** implementing a shared include (`cubenet_ai.inc`) so other modules can programmatically trigger bot voices.
