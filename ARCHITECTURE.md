# Architecture

## Folder Structure

```
FriendSlop/
├── scenes/          # .tscn scene files, organized by feature
│   └── player/      # Player-related scenes
├── scripts/         # .gd scripts, one per major system
├── shaders/         # .gdshader files
├── assets/          # Art, models, sounds
├── data/            # Game data (JSON files for topics, lists, packs)
│   ├── lists/       # Guessing lists (valid answers per topic)
│   └── packs/       # Guessing packs (curated word lists for performers)
├── addons/          # Third-party addons (fennara, godotsteam, godotsteamkit)
├── export/          # Build output (gitignored)
```

## What Each Folder Contains

| Folder | Contents | Conventions |
|--------|----------|-------------|
| `scenes/` | Godot `.tscn` scene files | Scene files and their primary script should share a name (e.g. `proto_controller.tscn` + `proto_controller.gd`). Subfolders group related scenes (e.g. `scenes/player/`). |
| `scripts/` | GDScript `.gd` files | One major system per script. Scripts are kept flat (no subfolders) since the project is still small. |
| `shaders/` | Godot `.gdshader` files | Each shader is a standalone spatial/visual effect. Named descriptively for what it renders. |
| `assets/` | Art, 3D models, audio | Raw source assets. Imported assets live under `.godot/imported/`. |
| `data/` | Game data (JSON) | Topics, guessing lists, and packs stored as JSON. Default data ships with game in `res://data/`. User-created data lives in `user://guessing/`. |
| `addons/` | Third-party GDExtensions and addons | Do not modify addon source directly. See `addons/AGENTS.md` for what each addon provides. |
| `export/` | Build output | Gitignored. Contains exported builds per platform. |

## Scene Architecture

The main game scene is `scenes/main_stage.tscn` — the theater environment. It contains:

- Stage platform (CSG geometry)
- Spotlight with volumetric beam shader
- Directional lighting and dark theater environment
- Fixed camera on a mount
- Player spawn container with `MultiplayerSpawner`
- `RoundManager` node

`scenes/game_hud.tscn` is a standalone HUD overlay (CanvasLayer) instanced by the game manager.

`scenes/round_manager.tscn` is a standalone manager scene that shares its script with the node inside `main_stage.tscn`.

`scenes/game_lobby.tscn` is the pre-game lobby scene. Shows current game settings (topics, lists, packs) and allows host to configure them before starting. For local play, this scene is shown after the lobby_manager creates the server.

`scenes/lobby_settings.tscn` is a popup settings panel that can be instanced into the game_lobby or other scenes. Provides UI for enabling/disabling topics, lists, and packs.

`scenes/player/proto_controller.tscn` is the player character — a `CharacterBody3D` with collision, a 3D model, and a `MultiplayerSynchronizer`.

## Multiplayer Authority Architecture

**Server (Peer 1):**
- Hosts the game, runs the `RoundManager` state machine
- Spawns and manages all player instances via `game_manager.gd`
- Validates and applies game state changes
- Uses direct function calls for RPCs to itself (avoids "RPC on yourself" errors)
- Emits authoritative signals that clients sync to

**Clients:**
- Receive state via RPC sync from server
- Only process input for their own authority-controlled player node
- Connect to `RoundManager` signals to gate input based on game state
- Do not run physics for non-authority nodes (audience members)

**Player Controller Authority:**
- Each player node sets authority via `set_multiplayer_authority(int(name))` where name is the peer ID
- Authority peers process their own input and physics
- Non-authority peers have `set_process(false)` and `set_physics_process(false)` called
- Audience members skip `_physics_process` via early return

## Creating New Folders

Before creating a new folder, ask: does an existing folder already serve this purpose? The project is intentionally kept flat at the top level.

New folders should be created when:

- A new **feature area** emerges that has its own scenes AND scripts (e.g. `scenes/player/` was created when player logic grew beyond a single scene)
- A new **asset category** is needed that doesn't fit `assets/` (e.g. `assets/audio/` if audio grows large)
- A new **data category** is needed (e.g. `data/` was created for game data like topics, lists, and packs)
- A new **addon or third-party dependency** is added (goes in `addons/`)

New folders must:

- Have a clear, singular purpose
- Be documented in this file and have their own `AGENTS.md`
- Not duplicate the purpose of an existing folder
