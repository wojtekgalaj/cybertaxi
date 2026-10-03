extends RefCounted
class_name LevelCatalog
## Hand-painted districts. Level 1 is index 0, then the list wraps.
## Duplicate scenes/levels/level_template.tscn, paint World/Tiles, and add the path here.

const LEVELS: Array[String] = [
	"res://scenes/levels/district_01.tscn",
]


static func scene_path_for(level_number: int) -> String:
	var idx := (maxi(level_number, 1) - 1) % LEVELS.size()
	return LEVELS[idx]
