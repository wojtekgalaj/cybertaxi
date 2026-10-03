extends Node
## Loads the hand-painted district for the current level and wires the HUD.

const Catalog := preload("res://data/level_catalog.gd")

@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	var path := Catalog.scene_path_for(GameState.level)
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Missing district scene: %s" % path)
		return
	var level := packed.instantiate()
	level.name = "Level"
	add_child(level)
	move_child(level, 0)
	hud.bind_level(level)
