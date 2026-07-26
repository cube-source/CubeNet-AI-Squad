arkdown# Installation Guide

## Prerequisites

- Team Fortress 2 dedicated server
- Metamod:Source
- SourceMod 1.11 or newer (1.10 may work but is untested)
- Matching SourceMod compiler (`spcomp`)

No additional extensions are required for the current modules.

## Building the Plugins

From the repository root (or with correct include paths):

```bash
spcomp src/cubenet_ai_core.sp      -o plugins/cubenet_ai_core.smx
spcomp src/cubenet_ai_voice.sp     -o plugins/cubenet_ai_voice.smx
spcomp src/cubenet_ai_afk.sp       -o plugins/cubenet_ai_afk.smx
Place the resulting .smx files into your server’s
addons/sourcemod/plugins/ directory.
Configuration Files
Copy the example configs into addons/sourcemod/configs/:

























FileRequired byNotesss_bot_roster.cfgCoreDefines all bot identities and attributesss_botvoices.cfgVoiceChat lines per bot / eventpersonalities.cfg(future)Currently unused
You can freely edit the roster and voice files. The core will load whatever profiles exist under the "BotRoster" key.
Load Order
Recommended order (add to addons/sourcemod/configs/pluginlist.cfg or load manually):
textcubenet_ai_core
cubenet_ai_voice
cubenet_ai_afk
Core must be loaded first so the database and profile array are ready.
First Run

Start (or reload) the server.
You should see console messages similar to:text[SS] CubeNet AI Squad Core 4.0.0 Loaded
[SS] Fresh AI database created
[SS] Loaded N bot profiles
[SS] AFK Bot Takeover 3.0.0 loaded
Add bots with the normal TF2 command (tf_bot_add or your preferred method).
Core will assign the next sequential profile from the roster and lock the name.

Useful Commands






























CommandAccessDescriptionsm_botlistGenericList currently active bot profilessm_afkbot_force <player>GenericForce AFK replacement on a playersm_afkbot_statusGenericShow active replacementssm_botvoices_test <name>AnyoneForce a spawn voice line for testing
Database Location
SQLite database name: ss_botmanager
File is created automatically in the SourceMod data directory.
Important (v4.0.0-alpha): The core currently drops and recreates the bots table on every load. This is intentional for development and will be changed before any stable release.
Troubleshooting

No profiles loaded → Check that ss_bot_roster.cfg exists and is valid KeyValues.
Voices not appearing → Confirm the file is named exactly ss_botvoices.cfg and that bot names in the config match the cleaned roster names.
AFK not triggering → Verify the plugin is loaded and that the player is truly idle (no movement, buttons, or chat).
Names resetting → Core re-applies names on spawn; if another plugin is fighting over names, check load order and conflicting plugins.

Updating

Replace the .smx files.
Update configs only if the new version introduces new keys.
Restart the map or server (or reload the plugins in order).

text---

### `LICENSE`

```text
MIT License

Copyright (c) 2026 CubeNet / cube-source

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
