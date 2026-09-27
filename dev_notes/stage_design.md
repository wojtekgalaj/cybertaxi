# Stage design — new districts (tilemap)

Hand-authored levels live under `scenes/levels/`. The run loads them from `data/level_catalog.gd` in order (level 1 → index 0, then wraps).

Paint layouts with **TileMapLayer** nodes using `assets/tiles/district_tileset.tres` (16×16 tiles).

## Quick recipe

1. **Duplicate** `level_template.tscn` or an existing district (e.g. `district_01_rooftops.tscn`).
2. Name it clearly, e.g. `district_03_your_name.tscn`.
3. On the root `Level` node, set **`map_size`** to the playable bounds.
4. Select **`World/PlatformsLayer`** and paint platform tiles from the tileset:
   - **Single / left / mid / right** — compose short or long pads in a horizontal run
   - **Start** (gold top) — put on one cell of the spawn pad (that whole run becomes pad **A**)
5. Select **`World/HazardsLayer`** and paint **hazard** pylons / blocks the cab must avoid.
6. Leave **`World/Platforms`**, **`World/Hazards`**, **`World/Passengers`**, **`World/Decor`**, and **`World/Bounds`** empty — runtime fills those.
7. Keep a **`CyberCab`** under `World`.
8. Register the scene in **`data/level_catalog.gd`** → `LEVELS`.

```gdscript
const LEVELS: Array[String] = [
	"res://scenes/levels/district_01_rooftops.tscn",
	"res://scenes/levels/district_02_gauntlet.tscn",
	"res://scenes/levels/district_03_your_name.tscn",
]
```

## How tiles become gameplay

At level start, `TileLevelBuilder`:

1. Groups contiguous **horizontal** platform cells into pads (letters A, B, C…).
2. Spawns a landable top collider + dock + label per pad.
3. Spawns an **underside hazard** under every pad — flying into a pad from below fails the run.
4. Spawns avoid-hazards for every cell on `HazardsLayer`.

Tile art stays on the TileMapLayers; physics bodies are generated.

## Tileset roles (`district_tiles.png`)

| Atlas | Role | Use |
|-------|------|-----|
| (0,0) single | platform | 1-tile pad |
| (1,0) left | platform | Left cap of a run |
| (2,0) mid | platform | Middle of a long pad |
| (3,0) right | platform | Right cap |
| (1,1) start | start | Marks the spawn pad (any cell in that run) |
| (0,1) / (3,1) | hazard | Paint on `HazardsLayer` only |

Rebuild the `.tres` if you edit the PNG:

`Godot --headless --path . --script res://tools/build_district_tileset.gd`

Optional example-district regenerator: `tools/build_tile_districts.gd`.

## Node checklist

| Node | Role |
|------|------|
| `Level` (`level_controller.gd`) | Map size, fares, win/lose |
| `World/PlatformsLayer` | Paint landable pads |
| `World/HazardsLayer` | Paint pylons / no-fly tiles |
| `World/Platforms` | Runtime pad bodies (do not hand-place) |
| `World/Hazards` | Runtime underside + pylon areas |
| `World/Passengers` | Runtime spawns |
| `World/Decor` | Sky / buildings |
| `World/Bounds` | Walls from `map_size` |
| `World/CyberCab` | Player |

## Design tips

- Need **at least two pads** (two separate horizontal runs).
- Vary run length: 1 tile = tiny ledge, 6–8 tiles = long runway.
- Undersides are lethal — route dives around pads, not through them.
- Freefall (no thrust while falling) still regenerates fuel.
- Pylons and pads show on the minimap.

## Legacy note

Instance-based `hand_authored` platforms under `World/Platforms` still work if the tile layers are empty. Prefer tile painting for new districts.
