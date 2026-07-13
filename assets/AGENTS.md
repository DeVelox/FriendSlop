# assets/

This folder contains raw source assets — 3D models, textures, audio, fonts, etc.

## Current Assets

| Asset | Description |
|-------|-------------|
| `AnimatedHuman.glb` | Humanoid character model with built-in animations (walk, jump, punch, working, death, etc.). Used by `proto_controller.tscn` for all player rendering. |

## Conventions

- Raw source assets live here. Imported/processed assets are managed by Godot's import system under `.godot/imported/`.
- When adding assets, consider organizing into subfolders if the count grows (e.g. `assets/models/`, `assets/audio/`).
- When adding significant assets, update this file.
