# Installation & Deployment Guide

This guide provides the technical steps required to deploy the **CubeNet AI Squad** ecosystem to a Team Fortress 2 dedicated server.

## 🛠 Prerequisites

To ensure stability and compatibility, your server environment must meet the following requirements:

- **TF2 Dedicated Server**: Standard SteamCMD installation.
- **Metamod:Source**: The latest stable build.
- **SourceMod**: Version 1.11 or newer (1.10 may be compatible but is not officially validated).
- **Compiler**: A matching `spcomp` compiler to build the source files into `.smx` binaries.

---

## 📦 Building the Plugins

The project is provided as source code (`.sp`). You must compile these for your specific server architecture. From the repository root or using a local build environment:

```bash
# Build Core Module
spcomp src/cubenet_ai_core.sp -o plugins/cubenet_ai_core.smx

# Build Voice Module
spcomp src/cubenet_ai_voice.sp -o plugins/cubenet_ai_voice.smx

# Build AFK Takeover Module
spcomp src/cubenet_ai_afk.sp -o plugins/cubenet_ai_afk.smx
```

**Deployment Path:** 
Move the resulting `.smx` files to:  
`addons/sourcemod/plugins/`

---

## ⚙️ Configuration Management

The system relies on KeyValues (`.cfg`) files for identity and dialogue management. Copy the example configurations from the `/configs` directory to your server's config path.

**Config Path:** `addons/sourcemod/configs/`

| File | Module | Description |
| :--- | :--- | :--- |
| `ss_bot_roster.cfg` | **Core** | Defines bot identities, personality traits, and attribute weights. |
| `ss_botvoices.cfg` | **Voice** | Maps event triggers to specific dialogue lines per bot profile. |
| `personalities.cfg` | **Future** | Reserved for advanced behavioral logic (currently unused). |

---

## 🚀 Initialization & Load Order

To prevent race conditions during the identity assignment phase, plugins must be loaded in a specific sequence. If using `pluginlist.cfg`, ensure the following order:

1. `cubenet_ai_core` (Initializes DB and Profile Arrays)
2. `cubenet_ai_voice` (Binds voice profiles to Core identities)
3. `cubenet_ai_afk` (Manages human-to-bot transitions)

### First Run Verification
Upon server start, verify the console logs for the following initialization sequence:
- `[SS] CubeNet AI Squad Core 4.0.0 Loaded`
- `[SS] SQLite database initialized successfully`
- `[SS] Loaded N bot profiles from roster`
- `[SS] AFK Bot Takeover 3.0.0 loaded`

---

## ⌨️ Administrative Commands

| Command | Access | Description |
| :--- | :--- | :--- |
| `sm_botlist` | Generic | Displays a list of all currently active bot profiles and their assigned slots. |
| `sm_afkbot_force <player>` | Admin | Manually triggers an AFK replacement for the specified player. |
| `sm_afkbot_status` | Generic | Shows current active replacements and takeover durations. |
| `sm_botvoices_test <name>` | Admin | Triggers a sample spawn voice line for a specific bot identity. |

---

## 💾 Data Persistence

The system utilizes an **SQLite** backend for tracking bot statistics and persistence.
- **Database Name:** `ss_botmanager.sq3`
- **Location:** Created automatically in the SourceMod `data/` directory.
- **Logic:** The system uses `INSERT OR REPLACE` logic to ensure that bot stats persist across server restarts and map changes without duplicating entries.

---

## 🔍 Troubleshooting

| Issue | Potential Cause | Solution |
| :--- | :--- | :--- |
| **No profiles loaded** | Missing or malformed config | Verify `ss_bot_roster.cfg` is valid KeyValues syntax. |
| **Voices not playing** | Name mismatch | Ensure bot names in `ss_botvoices.cfg` match the cleaned roster names exactly. |
| **AFK not triggering** | Input detection | Ensure the player has zero input (movement, buttons, or chat) for the defined threshold. |
| **Names resetting** | Plugin conflict | Check if other plugins are attempting to force player names; adjust load order in `pluginlist.cfg`. |

---

## 🔄 Updating the System

1. **Binary Update**: Replace existing `.smx` files in the plugins folder.
2. **Config Migration**: Compare your current `.cfg` files with the updated examples to ensure no new required keys were added.
3. **Cycle**: Restart the map or execute `sm plugins reload` in the specified load order.
