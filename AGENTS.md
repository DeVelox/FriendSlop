<!-- fennara-agents-start -->
# Fennara MCP Guidelines

This project uses Fennara MCP for Godot-aware inspection, editing, runtime error capture, diagnostics, scene validation, screenshots, and project settings.

When working on Godot-specific files or behavior, always read `addons/fennara/ai/guidelines.md` first. This includes work involving `.tscn`, `.tres`, `.res`, `.gd`, `.cs`, `.gdshader`, `project.godot`, scenes, nodes, resources, shaders, project settings, gameplay, UI, animation, rendering, Fennara addon behavior, or Fennara MCP behavior.

The Fennara guidelines file explains which MCP tools to use, when to inspect before editing, how validation works, and which tool calls are mandatory before considering Godot work complete.
<!-- fennara-agents-end -->

---

# FriendSlop

Online multiplayer charades. Teams of players act through animations (mime) while opposing teams guess the word. See `DESIGN.md` for full gameplay design.

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Engine | Godot 4.7 (Forward Plus renderer) |
| Physics | Jolt Physics |
| Multiplayer | GodotSteam GDExtension v4.20 (`SteamMultiplayerPeer`) |
| Lobby system | GodotSteamKit v1.0.1 (lobby starters) |
| Steam App ID | 480 (Spacewar, development only) |

## Guiding Principles

- **Server authority:** All game state changes go through the server (peer 1). Clients send inputs, server validates and applies. See `ARCHITECTURE.md` for multiplayer conventions.
- **Read the code:** This file directs you to the right place — it does not replace reading the source. Always inspect the actual code before making changes.
- **Keep AGENTS.md current:** Whenever a change is made that affects the understanding of a folder's role, purpose, or conventions, the relevant `AGENTS.md` must be updated in the same changeset. Stale documentation is worse than no documentation.
- **Ask questions:** When requirements are ambiguous, ask clarifying questions during implementation rather than guessing.

## MD Structure

This repository uses a layered documentation system. Higher-level files are broad and structural; lower-level files are verbose and implementation-specific.

| File | Location | Purpose |
|------|----------|---------|
| `AGENTS.md` | Root | Project overview, tech stack, guiding principles, MD structure guide |
| `ARCHITECTURE.md` | Root | Folder structure, what each folder contains, rules for creating new folders |
| `DESIGN.md` | Root | Gameplay design — goals, mechanics, teams, packs, scoring, voice, pose system |
| `AGENTS.md` | Each subfolder | Role of that folder, important nuances, conventions specific to its contents |

**Rule of thumb:** Root files explain *what the project is and how it's organized*. Folder-level `AGENTS.md` files explain *what lives here and what to watch out for*. The deeper you go, the more specific the documentation gets.

## GDScript Style

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
- **Comments:** Use `##` for doc comments on exports and public functions. Reserve inline comments for non-obvious logic only — self-explanatory code needs no comments.
- **Scene paths:** Use forward-slash `res://` paths for cross-platform compatibility

## Multiplayer Conventions

- **Server authority:** Server-authoritative RPC calls use direct function calls instead of `rpc_id` to avoid "RPC on yourself" errors.
- **Peer IDs as node names:** Player nodes are named by their peer ID string (`str(id)`). Authority is set via `set_multiplayer_authority(int(name))` in `_enter_tree()`.
- **MultiplayerSynchronizer:** Used for position/rotation sync (`replication_mode=1` = always replicate). Audience members skip physics processing entirely for efficiency.
- **Authority checks:** Always call `is_multiplayer_authority()` before processing input or enabling cameras. Input processing is further gated by round state to prevent actions during prep time.
- **Signal connections:** Connect `multiplayer.peer_connected` and `multiplayer.peer_disconnected` in `_ready()`. Controllers also connect to `RoundManager` signals for input gating.

## Development Practices

- **Git commits:** One logical feature per commit. Commit when a working, testable feature is complete.
- **Fennara MCP:** When working on Godot files, follow the Fennara guidelines in `addons/fennara/ai/guidelines.md`. Use Fennara tools to inspect scenes and nodes before editing, and validate after changes.
