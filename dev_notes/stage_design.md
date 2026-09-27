# Stage design — new districts

Hand-authored levels live under `scenes/levels/`. The run loads them from `data/level_catalog.gd` in order (level 1 → index 0, then wraps).

## Quick recipe

1. **Duplicate** an existing district scene (e.g. `district_01_rooftops.tscn`) or start from `level_template.tscn`.
2. Name it clearly, e.g. `district_03_your_name.tscn`.
3. On the root `Level` node:
   - Enable **`hand_authored`**
   - Set **`map_size`** to the playable bounds (cab is clamped to this)
   - Optionally tune `building_count` / `scatter_buildings` / `fill_sky`
4. Under **`World/Platforms`**, instance `scenes/platform.tscn` for each pad:
   - Position in the map
   - Set **`platform_id`** and **`label_text`** (usually the same letter)
   - Tick **`is_start`** on exactly one pad (cab spawns docked there)
5. Under **`World/Hazards`**, instance `scenes/hazard.tscn` for no-fly pylons the cab must avoid (touching one fails the run).
6. Leave **`World/Passengers`**, **`World/Decor`**, and **`World/Bounds`** empty — the level controller fills those at runtime.
7. Keep a **`CyberCab`** instance under `World` (position is overwritten by the start pad).
8. Register the scene in **`data/level_catalog.gd`** → `LEVELS` array.

```gdscript
const LEVELS: Array[String] = [
	"res://scenes/levels/district_01_rooftops.tscn",
	"res://scenes/levels/district_02_gauntlet.tscn",
	"res://scenes/levels/district_03_your_name.tscn",  # add here
]
```

## Node checklist

| Node | Role |
|------|------|
| `Level` (script: `level_controller.gd`) | Map size, hand-authored flag, fare logic |
| `World/Platforms` | Landing pads (hand-placed when `hand_authored`) |
| `World/Hazards` | Avoid group — red pylons |
| `World/Passengers` | Runtime spawns only |
| `World/Decor` | Sky / buildings (runtime unless you place your own and turn scatter off) |
| `World/Bounds` | Invisible walls from `map_size` |
| `World/CyberCab` | Player; start position comes from `is_start` pad |

## Design tips

- Need **at least two pads** so passengers have an origin and a destination.
- Spread pads enough that fuel + freefall regen matter; dive (no thrust while falling) recharges fuel.
- Pylons show on the minimap as red ticks — use them to shape routes, not just punish.
- Procedural layout still works if `hand_authored` is off (used by `level_template.tscn` / catalog fallback).

## Playtest

Open the project, hit Play from the main menu, and clear fares to advance. Catalog order is what you get each district; after the last entry it loops.
