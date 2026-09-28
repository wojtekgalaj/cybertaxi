extends StaticBody2D
## Landing pad. May be a single sprite pad or a tile-composed run.

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
	## Visuals come from the TileMapLayer; this body is physics + dock + label only.
	if sprite:
		sprite.visible = false
	var width_px := float(maxi(tile_span.x, 1) * tile_pixel_size)
	if collision and collision.shape is RectangleShape2D:
		var rect := (collision.shape as RectangleShape2D).duplicate() as RectangleShape2D
		rect.size = Vector2(width_px - 2.0, 8.0)
		collision.shape = rect
		collision.position = Vector2(0, -5)
	if dock:
		dock.position = Vector2(0, -10)
	if label:
		label.offset_left = -12
		label.offset_right = 12
		label.position = Vector2(-12, -30)
	_ensure_highlight(width_px)
	_ensure_light_occluder(width_px)


func _ensure_light_occluder(width_px: float) -> void:
	## Full pad body blocks light cones / PointLight2D shadows.
	var existing := get_node_or_null("LightOccluder2D")
	if existing:
		existing.queue_free()
	var occ := LightOccluder2D.new()
	occ.name = "LightOccluder2D"
	var poly := OccluderPolygon2D.new()
	var hw := width_px * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hw, -8), Vector2(hw, -8), Vector2(hw, 8), Vector2(-hw, 8)
	])
	occ.occluder = poly
	add_child(occ)


func _ensure_highlight(width_px: float) -> void:
	if _highlight == null:
		_highlight = Polygon2D.new()
		_highlight.name = "DestHighlight"
		_highlight.z_index = 2
		add_child(_highlight)
	var h := 3.0
	var w := width_px * 0.5
	_highlight.polygon = PackedVector2Array([
		Vector2(-w, -8), Vector2(w, -8), Vector2(w, -8 + h), Vector2(-w, -8 + h)
	])
	_highlight.color = Color(1.0, 0.4, 1.0, 0.0)


func set_destination_highlight(on: bool) -> void:
	is_destination_highlight = on
	_refresh_sprite()


func _refresh_sprite() -> void:
	if composed_from_tiles:
		if _highlight == null and tile_span.x > 0:
			_ensure_highlight(float(tile_span.x * tile_pixel_size))
		if _highlight:
			_highlight.color = Color(1.0, 0.45, 1.0, 0.85) if is_destination_highlight else Color(1, 1, 1, 0)
		return
	if sprite == null:
		return
	if is_destination_highlight:
		sprite.texture = preload("res://assets/sprites/platform_dest.png")
	else:
		sprite.texture = preload("res://assets/sprites/platform.png")


func get_dock_global() -> Vector2:
	return dock.global_position if dock else global_position + Vector2(0, -10)
