# Stage design — new districts (tilemap)

Districts live under `scenes/levels/` and load from `data/level_catalog.gd` (level 1 → index 0, then wraps).

**Pads, hazards, and lamps are painted on TileMapLayers.** Passengers spawn randomly. Batteries only recharge inside lamp light cones (blocked by pads/walls).

## Quick recipe

1. **Duplicate** `level_template.tscn` or an existing district.
2. Name it e.g. `district_03_your_name.tscn`.
3. On the root `Level` node set `map_size`, **Dimension** (`dimension_name`, `gravity`, `air_friction`, `inertia`), and optional `ambient_light`.
4. Paint **`World/PlatformsLayer`** — compose horizontal pad runs; gold **start** tile marks spawn (pad A).
5. Paint **`World/HazardsLayer`** — pylons to avoid.
6. Paint **`World/LightsLayer`** — lamp tiles; each becomes a downward light cone that charges batteries.
7. Leave `Platforms` / `Hazards` / `Lights` / `Passengers` / `Decor` / `Bounds` empty (runtime).
8. Register in `data/level_catalog.gd` → `LEVELS`.

## How tiles become gameplay

`TileLevelBuilder` groups platform runs into pads (with deadly undersides), spawns hazard areas, and spawns `LightSource` nodes from the lights layer. `CanvasModulate` darkens the district so cones matter.

Flight uses `QuadMotorPhysics` (4 rotors, tilt + inertia). Stick mixes motors; coasting keeps momentum.

## Tileset roles

| Atlas | Role |
|-------|------|
| row 0 singles/caps/mid | platform |
| (1,1) | start |
| (0,1) (3,1) | hazard |
| (0,2) | light |

Rebuild: `Godot --headless --path . --script res://tools/build_district_tileset.gd`  
Examples: `tools/build_tile_districts.gd`

## Design tips

- At least two pads; place lamps so routes require light stops.
- Pads occlude light — hide under a pad and you stop charging.
- Higher `inertia` = heavier quad feel.
