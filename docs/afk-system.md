# AFK Replacement System

Implemented in `cubenet_ai_afk.sp` (version 3.0.0 inside the plugin).

## Purpose

Keep the server full and the game flowing when human players go idle. An AFK player is temporarily replaced by an AI bot that continues playing. When the human returns, control is restored as seamlessly as possible.

## Timers (current defaults)

| Constant              | Value   | Meaning                          |
|-----------------------|---------|----------------------------------|
| `AFK_CHECK_INTERVAL`  | 10.0 s  | How often the check timer runs   |
| `AFK_WARNING_TIME`    | 180.0 s | Time before warning the player   |
| `AFK_TAKEOVER_TIME`   | 300.0 s | Time before actual replacement   |

## State Tracked per Player

- Last activity timestamp
- Whether a warning has been sent
- Whether the player is currently replaced
- The client index of the replacement bot
- Saved team, class, origin, angles, health, and name

## Flow

1. **Activity detection**
   - Any movement, buttons, impulse, or chat updates the activity timestamp.
   - If the player was replaced, activity immediately triggers a restore.

2. **Warning**
   - After 3 minutes of inactivity the player receives a chat warning.

3. **Takeover**
   - After 5 minutes the system:
     - Saves the player’s current state.
     - Moves the player to spectator (does **not** kill them).
     - Issues `tf_bot_add`.
     - Waits briefly, then associates the newest bot with the player.
     - Moves that bot onto the saved team.

4. **Restore**
   - On activity:
     - Kicks the replacement bot.
     - Returns the human to the original team.
     - Sets the original class and respawns.
     - Teleports the player to the bot’s last position (so the hand-off feels continuous).
     - Prints “Welcome back!”.

## Admin Commands
sm_afkbot_force <player>   – force an immediate replacement
sm_afkbot_status           – list currently replaced players
text## Known Limitations / Active Work

- Coupling with the core Bot Manager is still loose: the AFK plugin simply adds a generic bot; the core then assigns the next sequential profile.
- Position restoration depends on the bot still being alive and in a valid location.
- No graceful handling yet if the server is full or `tf_bot_add` fails.
- Debug logging is currently always on (`g_Debug = true`).

## Design Goals for Future Versions

- Tighter integration so the replacement bot re-uses the exact same profile / identity that would have been assigned.
- Optional “soft” takeover that keeps the player on the team but frozen / invisible.
- Configurable timers via ConVars.
- Support for players who disconnect while replaced.
