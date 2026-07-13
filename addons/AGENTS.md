# addons/

Third-party addons and GDExtensions. These are external dependencies — do not modify their source directly.

## Addons

| Addon | Purpose | Docs |
|-------|---------|------|
| `fennara/` | Godot-aware MCP tooling for AI agents. Provides scene inspection, editing, runtime diagnostics, validation, screenshots, and project settings access. | `addons/fennara/ai/guidelines.md` |
| `godotsteam/` | GodotSteam GDExtension. Provides the `Steam` singleton for Steam API access (lobby, voice, user data, overlays). | `addons/godotsteam/readme.md` |
| `godotsteamkit/` | GodotSteamKit. Higher-level lobby UI starters, custom nodes, autoloads, themes, and fonts built on top of GodotSteam. | Per-subfolder readmes under `addons/godotsteamkit/` |

## Conventions

- Never edit addon source files. If a fix is needed upstream, track it separately.
- When adding a new addon, update this file and `ARCHITECTURE.md`.
- Fennara has special significance — it's the tooling layer that enables AI-assisted development. Always follow its guidelines when working on Godot files.
