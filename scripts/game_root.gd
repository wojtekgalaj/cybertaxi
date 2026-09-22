extends Node
## Root game runner: wires HUD to the level.

@onready var level: Node2D = $Level
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	hud.bind_level(level)
