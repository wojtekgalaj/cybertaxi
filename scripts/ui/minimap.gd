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
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	for wall in data.get("walls", []):
		var rect: Rect2 = wall
		var origin := Vector2(rect.position.x * scale_v.x, rect.position.y * scale_v.y)
		var extent := Vector2(rect.size.x * scale_v.x, rect.size.y * scale_v.y)
		draw_rect(Rect2(origin, extent), Color(0.28, 0.4, 0.58, 0.95))
	for hpos in data.get("hazards", []):
		var hp: Vector2 = hpos * scale_v
		draw_rect(Rect2(hp - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), Color(1.0, 0.28, 0.38))
	for p in data.get("platforms", []):
		var pos: Vector2 = p.get("pos", Vector2.ZERO) * scale_v
		var is_dest: bool = p.get("dest", false)
		if is_dest:
			var ring_r := 5.0 + pulse * 2.0
			var ring_col := Color(1.0, 0.35, 0.95, 0.35 + pulse * 0.55)
			draw_arc(pos, ring_r, 0.0, TAU, 24, ring_col, 1.5, true)
			draw_circle(pos, 3.0, Color(1.0, 0.45, 1.0, 1.0))
			draw_circle(pos, 1.2, Color(1.0, 1.0, 1.0, 0.9))
			## Crosshair ticks so the pad reads as a nav target.
			var tick := 6.0 + pulse
			var tick_col := Color(1.0, 0.55, 1.0, 0.7 + pulse * 0.3)
			draw_line(pos + Vector2(-tick, 0), pos + Vector2(-3, 0), tick_col, 1.0)
			draw_line(pos + Vector2(3, 0), pos + Vector2(tick, 0), tick_col, 1.0)
			draw_line(pos + Vector2(0, -tick), pos + Vector2(0, -3), tick_col, 1.0)
			draw_line(pos + Vector2(0, 3), pos + Vector2(0, tick), tick_col, 1.0)
		else:
			draw_rect(Rect2(pos - Vector2(2, 1), Vector2(4, 2)), Color(0.4, 0.85, 1.0))
	for ppos in data.get("passengers", []):
		if ppos == null:
			continue
		var pp: Vector2 = ppos * scale_v
		draw_circle(pp, 1.5, Color(1.0, 0.85, 0.2))
	var cab: Vector2 = data.get("cab_pos", Vector2.ZERO) * scale_v
	draw_circle(cab, 2.5, Color(0.2, 1.0, 0.6))


func _process(_delta: float) -> void:
	queue_redraw()
