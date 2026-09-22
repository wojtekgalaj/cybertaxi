extends Control
## Corner radar of the district map.

@export var map_pixel_size: Vector2 = Vector2(96, 72)

var level: Node = null


func bind_level(level_node: Node) -> void:
	level = level_node
	custom_minimum_size = map_pixel_size
	size = map_pixel_size


func _draw() -> void:
	var bg := Color(0.05, 0.08, 0.14, 0.85)
	var border := Color(0.2, 1.0, 0.75, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 1.0)
	if level == null or not level.has_method("get_minimap_data"):
		return
	var data: Dictionary = level.get_minimap_data()
	var map_size: Vector2 = data.get("map_size", Vector2(1, 1))
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return
	var scale_v := Vector2(size.x / map_size.x, size.y / map_size.y)
	for p in data.get("platforms", []):
		var pos: Vector2 = p.get("pos", Vector2.ZERO) * scale_v
		var col := Color(1.0, 0.4, 0.9) if p.get("dest", false) else Color(0.4, 0.85, 1.0)
		draw_rect(Rect2(pos - Vector2(2, 1), Vector2(4, 2)), col)
	for ppos in data.get("passengers", []):
		if ppos == null:
			continue
		var pp: Vector2 = ppos * scale_v
		draw_circle(pp, 1.5, Color(1.0, 0.85, 0.2))
	var cab: Vector2 = data.get("cab_pos", Vector2.ZERO) * scale_v
	draw_circle(cab, 2.5, Color(0.2, 1.0, 0.6))


func _process(_delta: float) -> void:
	queue_redraw()
