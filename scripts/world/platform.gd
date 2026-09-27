extends StaticBody2D
## Landing pad. May host waiting passengers and act as a destination.

@export var platform_id: String = "A"
@export var label_text: String = "A"
@export var is_start: bool = false ## Hand-authored: cab spawns docked here.

@onready var sprite: Sprite2D = $Sprite
@onready var label: Label = $Label
@onready var dock: Marker2D = $Dock

var is_destination_highlight: bool = false


func _ready() -> void:
	add_to_group("platforms")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if label:
		label.text = label_text
	_refresh_sprite()


func set_destination_highlight(on: bool) -> void:
	is_destination_highlight = on
	_refresh_sprite()


func _refresh_sprite() -> void:
	if is_destination_highlight:
		sprite.texture = preload("res://assets/sprites/platform_dest.png")
	else:
		sprite.texture = preload("res://assets/sprites/platform.png")


func get_dock_global() -> Vector2:
	return dock.global_position if dock else global_position + Vector2(0, -10)
