<!-- fennara-agents-start -->
# Fennara MCP Guidelines

This project uses Fennara MCP for Godot-aware inspection, editing, runtime error capture, diagnostics, scene validation, screenshots, and project settings.

When working on Godot-specific files or behavior, always read `addons/fennara/ai/guidelines.md` first. This includes work involving `.tscn`, `.tres`, `.res`, `.gd`, `.cs`, `.gdshader`, `project.godot`, scenes, nodes, resources, shaders, project settings, gameplay, UI, animation, rendering, Fennara addon behavior, or Fennara MCP behavior.

The Fennara guidelines file explains which MCP tools to use, when to inspect before editing, how validation works, and which tool calls are mandatory before considering Godot work complete.
<!-- fennara-agents-end -->

---

# FriendSlop

Online multiplayer charades. One player acts out a word on a theater stage while the audience watches, reacts, and guesses via in-game voice chat.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Engine | Godot 4.7 (Forward Plus renderer) |
| Physics | Jolt Physics |
| Multiplayer | GodotSteam GDExtension v4.20 (`SteamMultiplayerPeer`) |
| Lobby system | GodotSteamKit v1.0.1 (lobby starters) |
| Steam App ID | 480 (Spacewar, development only) |

## Architecture

### Multiplayer Flow

```
Steamworks autoload (Steam init)
  -> Lobby Manager (host/join UI)
    -> Host: lobby_host creates Steam lobby
    -> Client: lobby_join browses/joins lobbies
  -> Lobby scene (player list, invite, start)
    -> Host: SteamMultiplayerPeer.host_with_lobby()
    -> Client: SteamMultiplayerPeer.connect_to_lobby()
  -> Scene change to main_stage.tscn
    -> game_manager.gd spawns players via MultiplayerSpawner
```

**Authority model:** Each player node is named by its peer ID string (e.g. `"1"`, `"2"`). Authority is set via `set_multiplayer_authority(int(name))` in the player controller's `_enter_tree()`. Only the owning peer processes input and enables their camera.

**Key files:**

| File | Role |
|------|------|
| `addons/godotsteamkit/autoloads/steamworks.gd` | Steam initialization, collects user/build/game data, stores `lobby_id` and `steam_id` |
| `addons/godotsteamkit/starters/lobbies/lobby_manager.gd` | Host/join panel orchestration, handles `+connect_lobby` command-line invite |
| `addons/godotsteamkit/starters/lobbies/lobby.gd` | In-lobby UI, creates `SteamMultiplayerPeer`, transitions to game scene |
| `scripts/game_manager.gd` | Spawns/despawns players via `MultiplayerSpawner` on the server |
| `scripts/proto_controller.gd` | Player controller, emote-driven gameplay (see below) |

### Scene Structure

```
scenes/
  main_stage.tscn          # Main game scene (the theater)
  game_manager.tscn        # Standalone manager (shares script with main_stage)
  player/
    proto_controller.tscn  # Player character
```

**main_stage.tscn** - The theater environment. Contains the stage platform (CSG), spotlight with volumetric beam shader, directional lighting, dark theater environment, a fixed camera, a container for spawned player instances, and a `MultiplayerSpawner`. The stage is a raised circular platform at approximately `(0, 0.5, 30)` with a CSG subtractor cutting away the back half.

**proto_controller.tscn** - The player character. A `CharacterBody3D` with a collision capsule, a 3D model (`AnimatedHuman`), and a `MultiplayerSynchronizer` for position/rotation replication. The controller is a **third/second person hybrid** — the camera observes the character from outside rather than from the character's eyes. See Player Controller below.

### Shaders

- **`shaders/spotlight_beam.gdshader`** - Volumetric cone beam for the stage spotlight. Rendered via a `CylinderMesh` with `ShaderMaterial` (additive alpha blend). Parameters: beam color, opacity, top/bottom radii, length, edge falloff, view falloff, glow strength.

## Gameplay Design

### Lobby Flow

1. Player launches game -> `Steamworks` autoload initializes Steam
2. Player sees lobby manager with Host / Join / Exit buttons
3. **Host:** Clicks Host -> `lobby_host` creates a Steam lobby (visibility, max players)
4. **Client:** Clicks Join -> `lobby_join` browses lobby list (distance filter, search, open slots), picks one to join
5. Both see lobby scene: player list, Invite button (Steam overlay), chat, Leave
6. **Host configures round settings** (e.g. round time)
7. Host presses Start -> `SteamMultiplayerPeer.host_with_lobby(lobby_id)` -> scene changes to `main_stage.tscn`
8. Client connects via `SteamMultiplayerPeer.connect_to_lobby(lobby_id)` -> waits for `connected_to_server` signal -> same scene change
9. Host can invite friends anytime via Steam overlay (`activateGameOverlayInviteDialog`)
10. Supports `+connect_lobby <id>` command-line arg for Steam overlay join invites

### Player Controller

The controller (`proto_controller.gd`) is a **third/second person hybrid** designed around emote-based gameplay, not free-roaming movement. It is an enabler for the emote system.

- **Actor:** Can move freely within the stage area. Cannot leave the stage. Primary interaction is triggering emotes to act out words.
- **Audience:** Seated in fixed positions between the camera and stage. Cannot move. Primary interaction is triggering reaction emotes (clapping, throwing tomatoes, etc.).

The current prototype is based on a first-person prototyping controller (Brackeys' ProtoController) and needs to be reworked to match the intended third/second person hybrid design with restricted movement.

### Emotes

The core gameplay mechanic. Both actor and audience use emotes.

- **Actor:** Full range of emotes — gestures, poses, movements for acting out words. The actor cycles through emotes to convey the prompt.
- **Audience:** Limited reaction emotes — clapping, throwing tomatoes, facepalms, etc. Cosmetic/social only, no gameplay impact.

Emote system not yet implemented. See Roadmap.

### Round System

- **Turn selection:** Exhaustive pool. All players take a turn as the actor. Once everyone has acted, the pool resets. Server picks the next actor randomly from the remaining pool.
- **Round duration:** Timed. The round time is **configurable by the host during lobby setup**. Server-authoritative countdown.
- **Prompt source:** Built-in word bank (see Word Bank below). Random selection, no repeats within a session.

### Word Bank

Built-in list of charade prompts. Randomly selected for each round, no repeats within a session. Shown only to the actor (not the audience).

Current prompts (20):

**Gaming:**
1. Mario jumping on a Goomba
2. Link opening a treasure chest
3. Pac-Man eating pellets
4. Angry Birds launching from a slingshot
5. Minecraft mining a diamond ore
6. Tetris clearing four lines at once
7. Sonic collecting gold rings
8. Street Fighter performing a Hadouken
9. Portal placing a blue and orange portal
10. Guitar Hero shredding a guitar solo

**Movies / TV Shows:**
11. The Matrix - dodging bullets in slow motion
12. Jurassic Park - T-Rex breaking through the fence
13. Titanic - "I'm the king of the world" pose on a ship
14. The Lord of the Rings - throwing a ring into a volcano
15. Star Wars - lightsaber duel
16. Friends - the "We were on a break!" argument
17. The Office - Dwight's martial arts moves
18. Breaking Bad - putting on a hazmat suit
19. The Lion King - Rafiki holding up Simba on Pride Rock
20. Harry Potter - casting a spell with a wand

### Voice Chat & Guessing

Voice chat uses **Steam Voice** (`Steam` singleton voice APIs). The actor cannot speak during their turn — their mic is muted server-side. Audience members guess by speaking; a **speaking indicator** shows who is currently talking. The actor clicks on a player's avatar to declare the winner.

Key Steam Voice APIs (reference: https://godotsteam.com/tutorials/voice/):
- `Steam.startVoiceRecording()` / `Steam.stopVoiceRecording()` — toggle mic capture
- `Steam.getVoice()` — grab compressed voice buffer
- `Steam.decompressVoice(buffer, sample_rate)` — decode for playback
- `Steam.getVoiceOptimalSampleRate()` — get Steam's recommended sample rate
- `Steam.setInGameVoiceSpeaking(steam_id, is_speaking)` — suppress Steam client audio while in-game
- Voice data is sent to other peers via RPCs (`process_voice_data.rpc(buffer)`)
- Playback uses `AudioStreamGenerator` + `AudioStreamGeneratorPlayback` with a buffer of `PackedVector2Array` frames

GodotSteamKit also provides a voice custom node that may contain reusable functionality.

### Guessing

The actor cannot speak during their turn. Audience members guess verbally; the actor clicks on a player's avatar to declare the winner. A simple rounds-won tally tracks overall standings.

### Stage Layout

- **Actor:** Spawns under the spotlight on the stage platform (approximately `(0, 1, 30)`), facing the fixed camera.
- **Audience:** Spawns evenly distributed between the camera and the stage (roughly z=15 to z=25). Positioned so upper torso is visible but the actor takes up the largest portion of the frame.
- **Current prototype:** All players spawn at `(0, 0, 5)` — needs updating for the actor/audience split.

### Camera

Single fixed camera for the entire game. Located on `CameraMount` at position `(-20, 18, 10)`, FOV ~35 degrees, pointed at the spotlight/stage area. The audience is visible in the lower portion of the frame.

### Scoring

Not yet implemented. Current approach: the actor declares the winner each round. A simple rounds-won tally tracks overall standings. Team-based scoring is a future possibility.

## Code Conventions

### GDScript Style

Follow the [Godot GDScript style guide](https://docs.godotengine.org/en/stables/tutorials/scripting/gdscript/gdscript_styleguide.html):

- **Indentation:** Tabs (not spaces)
- **Line length:** ~100 characters max
- **Naming:**
  - `snake_case` for variables, functions, signals
  - `PascalCase` for classes, nodes, resources
  - `UPPER_SNAKE_CASE` for constants (e.g. `const PLAYER_SCENE`)
  - `_leading_underscore` for private methods
  - `@export` variables use `snake_case`
- **Type hints:** Use explicit return types and parameter types. Use `:=` only when the type is completely obvious.
- **Signals:** Use `signal name(param: Type)` declaration syntax
- **Comments:** Use `##` for doc comments on exports and public functions. Avoid unnecessary inline comments.
- **Scene paths:** Use forward-slash `res://` paths for cross-platform compatibility

### File Organization

```
scenes/          # .tscn scene files, organized by feature
scripts/         # .gd scripts, one per major system
shaders/         # .gdshader files
assets/          # Art, models, sounds
addons/          # Third-party addons (fennara, godotsteam, godotsteamkit)
export/          # Build output (gitignored)
```

- Scene files and their primary script should share a name when possible (e.g. `proto_controller.tscn` + `proto_controller.gd`)
- Keep scripts focused: one major system per script
- Use `@tool` scripts only for editor-side work; never attach them to runtime gameplay nodes

### Multiplayer Conventions

- **Server authority:** All game state changes go through the server. Clients send inputs, server validates and applies.
- **Peer IDs as node names:** Player nodes are named by their peer ID string (`str(id)`)
- **MultiplayerSynchronizer:** Used for position/rotation sync (`replication_mode=1` = always replicate)
- **Authority checks:** Always call `is_multiplayer_authority()` before processing input or enabling cameras
- **Signal connections:** Connect `multiplayer.peer_connected` and `multiplayer.peer_disconnected` in `_ready()`

## Current State

### Implemented

- Steam lobby system (create, browse, join, invite, chat, leave)
- `SteamMultiplayerPeer` connection (host + client)
- Player spawning via `MultiplayerSpawner`
- First-person prototyping controller (movement, look, sprint, freefly/noclip) — **needs rework to third/second person hybrid**
- `MultiplayerSynchronizer` for position/rotation replication
- Theater stage environment (floor, CSG platform, spotlight with volumetric beam shader)
- Fixed camera setup
- Steam user data collection (ID, username, language, VAC status, Steam Deck detection)
- Command-line lobby invite support (`+connect_lobby`)

### Not Yet Implemented

See Roadmap below.

## Roadmap

### Priority 1 - Core Game Loop

- [ ] Round manager: server-side state machine for actor selection, round timing, transitions
- [ ] Player controller rework: third/second person hybrid, restricted movement (actor on stage, audience seated)
- [ ] Actor/audience spawn positions: actor to stage center, audience distributed between camera and stage
- [ ] Exhaustive pool: track which players have acted, reset when all have gone
- [ ] Round timer: configurable by host in lobby, server-authoritative countdown
- [ ] Spotlight toggle: enable/disable spotlight effect between rounds
- [ ] Emote system: actor emotes (full range for acting), audience reactions (clapping, tomatoes, etc.)
- [ ] Actor declares round winner, rounds-won tally

### Priority 2 - Voice & Word System

- [ ] Voice chat: Steam Voice integration (recording, playback, RPC transport, speaking indicator)
- [ ] Actor muting: server-side enforcement — actor cannot transmit voice during their turn
- [ ] Word bank: built-in list of charade prompts (20 prompts, gaming + movies/TV)
- [ ] Prompt display: show the word to the actor only (not the audience)
- [ ] Word selection: random from the bank, no repeats within a session

### Priority 3 - Audience

- [ ] Audience seating: fixed positions between camera and stage
- [ ] Spectator UI: timer, current actor name, guess count
- [ ] Audience idle behavior while waiting

### Priority 4 - Scoring & Feedback

- [ ] Scoring system: TBD (possibility of teams)
- [ ] Score display: UI showing current scores
- [ ] Round results: show word, who guessed, time taken

### Priority 5 - Polish

- [ ] Main menu / lobby UI improvements
- [ ] Player avatars: Steam profile pictures on stage
- [ ] Audio: background music, sound effects
- [ ] UI overhaul: themed theater UI
- [ ] Network disconnect handling: graceful cleanup on drop
- [ ] Settings: volume, graphics, controls

## Development Practices

- **Git commits:** Commit as features are completed. Avoid committing too frequently (clutters history) but commit often enough that each working, testable feature is logged. One logical feature per commit is a good rule of thumb.
- **Update this file:** Keep AGENTS.md current as implementation progresses. Log progress updates, mark roadmap items done, and add any clarifications or decisions established during development.
- **Ask questions:** When requirements are ambiguous, ask clarifying questions during implementation rather than guessing. Use Context7 to look up Godot/Steam documentation if the user hasn't provided a reference already.

## Common Tasks

### Adding a New Input Action

1. Add the action in `project.godot` via the `project_settings` tool (under `[input]`)
2. Add validation in `proto_controller.gd:check_input_mappings()` if the controller should handle it
3. Reference it in the controller's `_unhandled_input()` or `_physics_process()`

### Adding a New Scene

1. Create `.tscn` in `scenes/` (organized by feature subfolder if needed)
2. Create corresponding `.gd` script in `scripts/` if needed
3. If multiplayer-spawnable, register it with `MultiplayerSpawner.add_spawnable_scene()`
4. If it needs networking, add a `MultiplayerSynchronizer` for synced properties

### Editing the Stage Environment

The stage is built with CSG nodes in `main_stage.tscn`. Use `get_scene_tree` and `get_node_properties` before editing. The spotlight beam is a `CylinderMesh` with a custom shader — see `shaders/spotlight_beam.gdshader`.

### Working with Steam Features

All Steam API calls go through the `Steam` singleton (provided by GodotSteam GDExtension). The `Steamworks` autoload (`addons/godotsteamkit/autoloads/steamworks.gd`) provides cached user data and the current `lobby_id`. Always check `Engine.has_singleton("Steam")` before calling Steam APIs.

Key Steam Voice APIs for voice chat implementation:
- `Steam.startVoiceRecording()` / `Steam.stopVoiceRecording()` — mic capture
- `Steam.getVoice()` — grab compressed buffer (check `written` field for v4.16+)
- `Steam.decompressVoice(buffer, sample_rate)` — decode to PCM
- `Steam.getVoiceOptimalSampleRate()` — recommended sample rate
- `Steam.setInGameVoiceSpeaking(steam_id, is_speaking)` — suppress Steam client audio
