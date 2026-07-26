# Voice System

The voice system provides personality-flavoured chat announcements for bots. It is implemented in `cubenet_ai_voice.sp`.

## How It Works

1. The plugin listens for:
   - `player_spawn`
   - `player_death`
   - `teamplay_point_captured` (objective)

2. On a relevant event it looks up the bot’s clean name (the `[SS]` prefix is stripped if present).

3. It loads `addons/sourcemod/configs/ss_botvoices.cfg` (KeyValues).

4. It selects a random line under the matching bot → event section and prints it to chat in the form:
[SS]BotName: <chosen line>
text## Cooldowns

| Event type   | Cooldown          |
|--------------|-------------------|
| General voice| 190 seconds       |
| Kill voice   | 300 seconds       |
| Objective    | Random chance (1 in 5) |

These prevent spam while still giving bots a living presence.

## Config Format
"BotVoices"
{
"Parker"
{
"spawn"
{
"1" "Engineer on site."
"2" "Building up."
"3" "Ready to fortify."
}
"kill"
{
"1" "Target eliminated."
"2" "Nice try."
}
"death"
{
"1" "Down... but not out."
"2" "Rebuilding..."
}
"objective"
{
"1" "Point secured."
"2" "We hold the line."
}
}
}
textBot keys in the config must match the cleaned name that appears after the core assigns the profile (i.e. the `name` field from the roster, without any `[SS]` prefix the voice plugin may see).

## Detection Logic

A client is considered an “SS bot” if:

- It is a fake client, **and**
- Its current name contains the substring `[SS]`.

This is a temporary heuristic; a more robust shared API is planned.

## Testing
sm_botvoices_test <botname>
textForces a spawn-style voice line for the named bot (useful for verifying config).

## Future Plans

- Personality-specific voice packs.
- Actual voice (sound) files instead of (or in addition to) chat.
- Context-aware lines (revenge, domination, near-death, etc.).
- Shared include so other modules can trigger voices cleanly.
