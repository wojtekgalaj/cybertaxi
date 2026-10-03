extends StaticBody2D
## Landing pad. Tile-built pads keep the art on the TileMapLayer and only
## collide along the top lip. The underside is a separate crash volume.

@export var platform_id: String = "A"
@export var label_text: String = "A"
@export var is_start: bool = false
@export var composed_from_tiles: bool = false
@export var tile_span: Vector2i = Vector2i(1, 1)
@export var tile_pixel_size: int = 16

@onready var sprite: Sprite2D = $Sprite
@onready var label: Label = $Label
@onready var dock: Marker2D = $Dock
@onready var collision: CollisionShape2D = $CollisionShape2D

var is_destination_highlight: bool = false
var _highlight: Polygon2D = null


func _ready() -> void:
	add_to_group("platforms")
	if sprite:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if label:
		label.text = label_text
	if composed_from_tiles:
		_apply_tile_composition()
	_refresh_sprite()


func _apply_tile_composition() -> void:
	if sprite:
		sprite.visible = false
	var width_px := float(maxi(tile_span.x, 1) * tile_pixel_size)
	if collision:
		var rect := RectangleShape2D.new()
		## Top lip only. one_way so a climb into the belly is not a landing.
		rect.size = Vector2(width_px - 2.0, 6.0)
		collision.shape = rect
		collision.position = Vector2(0, -5)
		collision.one_way_collision = true
	if dock:
		dock.position = Vector2(0, -12)
	if label:
		label.offset_left = -16
		label.offset_right = 16
		label.offset_top = -34
		label.offset_bottom = -20
		label.position = Vector2.ZERO
	_ensure_highlight(width_px)


func _ensure_highlight(width_px: float) -> void:
	if _highlight == null:
		_highlight = Polygon2D.new()
		_highlight.name = "DestHighlight"
		_highlight.z_index = 2
		add_child(_highlight)
	var half := width_px * 0.5
	_highlight.polygon = PackedVector2Array([
		Vector2(-half, -9),
		Vector2(half, -9),
		Vector2(half, -6),
		Vector2(-half, -6),
	])
	_highlight.color = Color(1, 1, 1, 0)


func set_destination_highlight(on: bool) -> void:
	is_destination_highlight = on
	_refresh_sprite()


func _refresh_sprite() -> void:
	if composed_from_tiles:
		if _highlight == null and tile_span.x > 0:
			_ensure_highlight(float(tile_span.x * tile_pixel_size))
		if _highlight:
			_highlight.color = Color(1.0, 0.45, 1.0, 0.9) if is_destination_highlight else Color(1, 1, 1, 0)
		return
	if sprite == null:
		return
	if is_destination_highlight:
		sprite.texture = preload("res://assets/sprites/platform_dest.png")
	else:
		sprite.texture = preload("res://assets/sprites/platform.png")


func get_dock_global() -> Vector2:
	return dock.global_position if dock else global_position + Vector2(0, -10)


func get_cab_rest_global() -> Vector2:
	return get_dock_global() + Vector2(0, -4)
