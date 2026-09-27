extends RefCounted
class_name LevelCatalog
## Painted district scenes. Index 0 = GameState.level 1.
## Add new .tscn paths here after you design them in the editor.

const FALLBACK := "res://scenes/levels/level_template.tscn"

const LEVELS: Array[String] = [
	"res://scenes/levels/district_01_rooftops.tscn",
	"res://scenes/levels/district_02_gauntlet.tscn",
]


static func scene_path_for(level_number: int) -> String:
	if LEVELS.is_empty():
		return FALLBACK
	var idx := (maxi(level_number, 1) - 1) % LEVELS.size()
	return LEVELS[idx]
