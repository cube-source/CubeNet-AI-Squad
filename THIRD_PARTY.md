# Third-Party Dependencies & Attributions

CubeNet AI Squad is licensed under the MIT License. However, it relies on external technologies and conceptual frameworks to achieve its functionality. This document ensures proper credit and clarifies the licensing boundaries of the project.

## 🛠 Required Dependencies

### CBaseNPC (TF2-DMB)
The AFK Possession system requires the **CBaseNPC** extension for navmesh access and NextBot-facing natives on Linux.
- **Repository:** https://github.com/TF2-DMB/CBaseNPC
- **Role:** Runtime dependency (Extension + Gamedata).
- **Licensing:** See the CBaseNPC upstream repository.
- **Note:** CBaseNPC is **not** bundled with CubeNet AI Squad. Users must install it from official upstream releases.

## 💡 Conceptual Influences

The following projects provided inspiration for the architectural approach of CubeNet:

- **PathFollower (Pelipoika):** The concept of "same-entity drive" (possessing the human client instead of swapping them) was inspired by PathFollower's Windows implementation. CubeNet reimplements this logic natively for Linux via CBaseNPC.
- **Community ebot / NextBot Patterns:** High-level AI behavior and path-costing ideas were informed by broader community discussions on TF2 bot intelligence.

---
*CubeNet AI Squad plugins are MIT-licensed. Third-party extensions and dependencies remain under their own respective licenses.*
