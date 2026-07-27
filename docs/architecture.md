# System Architecture

The CubeNet AI framework is designed as a decoupled ecosystem of SourceMod plugins. Rather than building a monolithic plugin—which in the SourcePawn environment can lead to catastrophic server crashes upon single-point failures—we utilize a modular architecture. This allows us to iterate on specific systems (like the Voice engine or AFK logic) without risking the stability of the Core identity manager.

## High-Level Design
The system operates on a Core-and-Satellite model. The **Core Manager** acts as the single source of truth for bot identities and database state, while satellite modules hook into the core's data to provide behavioral layers.



## Module Specifications

| Module | Responsibility | Design Intent | Status |
| :--- | :--- | :--- | :--- |
|  | Roster, Identity, Persistence | Acts as the orchestrator. Manages the SQLite lifecycle and ensures bots maintain persistent identities across maps. | **Implemented** |
|  | Event-Driven Dialogue | Decouples chat logic from gameplay logic. Listens for core events to trigger personality-specific voice lines. | **Implemented** |
|  | Seamless Player Transition | Handles the hand-off between a human player and an AI replacement to maintain match balance without interrupting flow. | **Implemented** |
|  | Behavioral Modifiers | (Upcoming) Translates profile traits (Aggression, Bravery) into runtime behavior overrides. | *Planned* |
|  | Advanced Identity Logic | (Upcoming) Manages the relationship between bot archetypes and generated profiles. | *Planned* |
|  | Performance Telemetry | (Upcoming) Tracks longitudinal bot performance to feed into progression logic. | *Planned* |
|  | Spatial Intelligence | (Upcoming) Custom pathing helpers to reduce bot-like movement patterns. | *Planned* |
|  | Skill Evolution | (Upcoming) Allows bots to learn or evolve based on statistics and server history. | *Planned* |

## The Identity Lifecycle
To avoid common SourceMod race conditions—where a plugin attempts to modify a client before the engine has fully initialized their session—we implement a delayed assignment pipeline.



## Data Persistence Model
We utilize **SQLite** for its zero-configuration overhead and sufficient performance for the current scale. 

- **Caching Strategy:** To prevent frequent disk I/O from causing server stutter, the Core Manager loads the roster into an in-memory array upon startup. 
- **Write-Back Cycle:** Statistics are updated in memory and flushed to the database on a 5-minute heartbeat or during map transitions. This ensures data integrity while maintaining peak server FPS.

## Load Order & Dependencies
To ensure the data environment is ready before satellites attempt to access it, the following load order is mandatory:

1.  $\rightarrow$ *Initializes DB and Profile Array*
2.  $\rightarrow$ *Binds to Core Event Dispatcher*
3.  $\rightarrow$ *Registers Swap Request Hooks*

## Extension Points
The framework is built for growth. New modules can be integrated by:
1. Including  for shared constants.
2. Hooking into the Core's identity assignment events.
3. Utilizing the SQLite schema to store module-specific metadata without altering the core table structure.
