extends Node
## Root game runner: loads the district for the current run level, wires HUD.

const DebugTweaksScene := preload("res://scenes/ui/debug_tweaks.tscn")

@onready var hud: CanvasLayer = $HUD

var level: Node2D = null
var debug_tweaks: CanvasLayer = null


func _ready() -> void:
	var path := LevelCatalog.scene_path_for(GameState.level)
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Missing level scene: %s" % path)
		packed = load(LevelCatalog.FALLBACK)
	level = packed.instantiate()
	level.name = "Level"
	add_child(level)
	move_child(level, 0)
	hud.bind_level(level)
	debug_tweaks = DebugTweaksScene.instantiate()
	add_child(debug_tweaks)
	debug_tweaks.bind_level(level)
