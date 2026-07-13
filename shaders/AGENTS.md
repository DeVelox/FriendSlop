# shaders/

This folder contains Godot `.gdshader` files for visual effects.

## Shader Files

| Shader | Purpose |
|--------|---------|
| `spotlight_beam.gdshader` | Volumetric cone beam for the stage spotlight. Additive alpha blend rendered via a `CylinderMesh` with `ShaderMaterial`. Parameters: beam color, opacity, top/bottom radii, length, edge falloff, view falloff, glow strength. |

## Conventions

- Each shader is a standalone spatial/visual effect. Named descriptively for what it renders.
- Shaders are assigned to materials on nodes in scenes. The shader itself doesn't know which scene uses it.
- When adding a new shader, update this file.
