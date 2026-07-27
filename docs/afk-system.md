# AFK Takeover & Player Replacement Logic

The AFK Replacement System, implemented in , is designed to maintain server population and match momentum when human players become inactive. Unlike simple kick timers, this system implements a seamless hand-off between a human user and an AI agent.

## Design Philosophy
The primary goal is **non-destructive replacement**. We aim to remove the idle player from the active gameplay loop without deleting their session or forcing a disconnect, allowing for an immediate and frictionless return to the game.

## The Replacement Pipeline

### 1. Activity Detection
The system monitors a suite of input vectors via . Activity is flagged if any of the following are detected:
- Movement (Velocity change/Input)
- Button presses (Jump, Attack, Use)
- Chat messages or Impulse commands
- Voice activity

### 2. The Transition Phase (The Swap)
When the  threshold is met, the system executes a precise sequence to ensure stability:
- **State Capture:** The player's current team, class, coordinates, and health are cached in memory.
- **Session Isolation:** The player is moved to the **Spectator Team**. We explicitly avoid killing the player, as that would trigger spawn events and potentially disrupt bot placement logic.
- **Agent Deployment:** The system issues a  command. 
- **Identity Association:** The most recently joined bot is tagged as the replacement for the specific human client index.

### 3. Restoration & Hand-off
Upon detection of new activity, the Restore sequence triggers:
- **Agent Termination:** The replacement bot is removed from the server.
- **Session Re-integration:** The human player is moved back to their cached team and class.
- **Spatial Alignment:** The player is teleported to the bot's final position. This creates a continuous feel, as if the player has simply woken up where their AI counterpart left off.

## Technical Constraints & Optimizations

| Parameter | Default | Engineering Justification |
| :--- | :--- | :--- |
|  | 10.0s | Balances CPU overhead with responsiveness. |
|  | 180.0s | Provides a grace period to prevent accidental takeovers. |
|  | 300.0s | Standard threshold for hard inactivity. |

## Current Implementation Notes
The system currently utilizes a heuristic-based association between the replacement bot and the human player. Future iterations aim to integrate directly with the Core AI Manager's profile system to ensure the replacement bot inherits the specific personality of the player it is replacing.
