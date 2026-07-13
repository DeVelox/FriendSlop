# scenes/

This folder contains all Godot `.tscn` scene files. Scenes are the visual and structural backbone of the game — they define what nodes exist, how they're arranged, and which scripts are attached.

## Scene Files

| Scene | Purpose |
|-------|---------|
| `main_stage.tscn` | The main game scene — the theater environment. Contains stage geometry, lighting, spotlight, camera, player spawn container, `MultiplayerSpawner`, and `RoundManager`. This is the scene loaded after lobby transition. |
| `game_hud.tscn` | In-game HUD overlay (CanvasLayer). Shows round timer, actor UI (player buttons to declare winner), and audience UI (emote buttons). |
| `round_manager.tscn` | Standalone `RoundManager` scene. Shares its script with the `RoundManager` node inside `main_stage.tscn`. |
| `player/proto_controller.tscn` | The player character. See `player/AGENTS.md` for details. |

## Conventions

- Scene files and their primary script share a name when possible (e.g. `game_hud.tscn` + `game_hud.gd`).
- Use Fennara MCP tools (`get_scene_tree`, `get_node_properties`) to inspect scenes before editing. See `addons/fennara/ai/guidelines.md`.
- When adding a new scene, also update this file and `ARCHITECTURE.md`.
