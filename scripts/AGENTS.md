# scripts/

This folder contains all GDScript files. Each script handles one major system. Scripts are kept flat (no subfolders) since the project is still small.

## Script Files

| Script | System | Key Responsibilities |
|--------|--------|---------------------|
| `game_manager.gd` | Game orchestration | Server-side. Spawns/despawns players on connect/disconnect. Assigns actor vs audience positions. Manages spotlight state. |
| `game_hud.gd` | In-game UI | CanvasLayer overlay. Synced round timer, emote buttons for audience. All gated by round state. |
| `proto_controller.gd` | Player controller | Per-player CharacterBody3D. Role-based movement (actor only), emote input, animation playback and sync, stage boundary clamping, multiplayer authority setup. |
| `round_manager.gd` | Round state machine | Server-authoritative. State flow: WAITING -> CHOOSING_ACTOR -> ACTOR_READY -> IN_ROUND -> ROUND_END. Handles actor selection from exhaustive pool, timer countdowns, prompt picking from word bank, RPC sync to clients. |

## Conventions

- One major system per script. If a script is growing too large, consider splitting it — but only if the parts are truly independent.
- Scripts are referenced from their corresponding scene files. The scene owns the node tree; the script owns the logic.
- Server-authoritative logic uses direct function calls instead of `rpc_id` to itself. See `AGENTS.md` (root) for multiplayer conventions.
- When adding or renaming a script, update this file and `ARCHITECTURE.md`.
