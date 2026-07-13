# scenes/player/

This folder contains the player character scene. The player is the most complex node in the game — it handles movement, animation, emotes, and multiplayer authority.

## Scene

`proto_controller.tscn` — A `CharacterBody3D` with:
- Collision capsule
- 3D model (`AnimatedHuman`)
- `MultiplayerSynchronizer` for position/rotation replication (`replication_mode=1` = always replicate)
- Attached script: `scripts/proto_controller.gd`

## Important Nuances

- **Authority model:** Each player node is named by its peer ID string (e.g. `"1"`, `"2"`). Authority is set via `set_multiplayer_authority(int(name))` in `_enter_tree()`. Only the owning peer processes input and enables their camera.
- **Role-based controller:** The script handles both actor and audience roles. Actors can move on stage; audience members are stationary. Role is set via `is_actor` metadata by `game_manager.gd`.
- **Input gating:** Input processing is gated by round state — locked during ACTOR_READY (prep) and ROUND_END, unlocked during IN_ROUND.
- **Stage boundary:** Actor movement is clamped to the stage area. Audience members skip `_physics_process` entirely.
- **Animation:** Placeholder animations from AnimatedHuman. Walk/jump are automatic; numbered keys (1-4) trigger emotes.

## Conventions

- Use Fennara MCP tools to inspect the scene tree and node properties before editing.
- The controller script lives in `scripts/proto_controller.gd`, not alongside the scene.
- When modifying authority or spawn logic, also check `scripts/game_manager.gd` — it handles spawning and role assignment.
