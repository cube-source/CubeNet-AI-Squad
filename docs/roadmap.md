# Roadmap

## Version 4.x (current – alpha)

- [x] Persistent bot identities
- [x] SQLite profile storage
- [x] Basic statistics (kills / deaths / assists)
- [x] Voice framework (chat lines)
- [x] Initial AFK replacement system
- [ ] Remove destructive DB reset on every load
- [ ] Stable, production-ready AFK behaviour
- [ ] Proper shared includes and API surface
- [ ] Example configs and full documentation (this effort)

## Version 5

- Stable AFK replacement with better Bot Manager integration
- Runtime personality influence on bot decisions
- ConVar-driven configuration for all major timers and thresholds
- Richer statistics (wins/losses, per-class breakdowns, session history)
- Config validation and clearer error messages
- Name prefix / identity system that does not rely on string heuristics

## Version 6

- AI learning / simple memory of past encounters
- Squad-level tactics and leadership roles
- Dynamic difficulty adjustment
- Weapon and loadout preferences per personality
- Campaign / multi-map persistence of bot state
- Optional actual voice (sound) packs

## Longer Term

- Full adaptive combat learning
- Cross-server profile sharing (optional central service)
- Web or in-game dashboard for viewing squad statistics
- Integration with popular TF2 server plugins / frameworks
