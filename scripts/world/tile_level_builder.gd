extends RefCounted
class_name TileLevelBuilder
## Reads TileMapLayer cells and builds Platform + Hazard nodes.
## Contiguous horizontal platform tiles → one pad. Underside of each pad is lethal.

const TILE := 16
const PlatformScene := preload("res://scenes/platform.tscn")
const HazardScene := preload("res://scenes/hazard.tscn")
const UndersideScript := preload("res://scripts/world/underside_hazard.gd")

const ROLE_PLATFORM := "platform"
const ROLE_START := "start"
const ROLE_HAZARD := "hazard"


static func build(
	platforms_layer: TileMapLayer,
	hazards_layer: TileMapLayer,
	platforms_root: Node2D,
	hazards_root: Node2D
) -> Dictionary:
	var out_platforms: Array[Node] = []
	var out_hazards: Array[Node] = []

	for c in platforms_root.get_children():
		c.queue_free()
	for c in hazards_root.get_children():
		c.queue_free()

	## Freeing is deferred; clear refs now and rebuild after a sync isn't available —
	## call after ensuring roots start empty, or remove_child immediately.
	while platforms_root.get_child_count() > 0:
		var n: Node = platforms_root.get_child(0)
		platforms_root.remove_child(n)
		n.free()
	while hazards_root.get_child_count() > 0:
		var n2: Node = hazards_root.get_child(0)
		hazards_root.remove_child(n2)
		n2.free()

	var platform_cells: Dictionary = {}
	if platforms_layer and platforms_layer.tile_set:
		for cell in platforms_layer.get_used_cells():
			var role := _cell_role(platforms_layer, cell)
			if role == ROLE_PLATFORM or role == ROLE_START or role == "":
				## Empty role still counts if atlas tile looks like platform row 0 / start.
				if role == "" and not _looks_like_platform(platforms_layer, cell):
					continue
				if role == ROLE_HAZARD:
					continue
				platform_cells[cell] = role if role != "" else ROLE_PLATFORM

	var runs := _horizontal_runs(platform_cells.keys())
	runs.sort_custom(func(a, b):
		var ay: int = a[0].y
		var by: int = b[0].y
		if ay == by:
			return a[0].x < b[0].x
		return ay < by
	)
	var start_run_idx := _find_start_run(runs, platform_cells)
	if start_run_idx > 0:
		var start_run: Array = runs[start_run_idx]
		runs.remove_at(start_run_idx)
		runs.insert(0, start_run)
		start_run_idx = 0
	var ids := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"]

	for i in runs.size():
		if i >= ids.size():
			break
		var run: Array = runs[i]
		var pad := _spawn_platform_from_run(run, platforms_layer, ids[i], i == start_run_idx)
		platforms_root.add_child(pad)
		out_platforms.append(pad)
		var under := _spawn_underside_hazard(run, platforms_layer, pad)
		hazards_root.add_child(under)
		out_hazards.append(under)

	if hazards_layer and hazards_layer.tile_set:
		for cell in hazards_layer.get_used_cells():
			var role := _cell_role(hazards_layer, cell)
			if role == ROLE_PLATFORM or role == ROLE_START:
				continue
			var h := _spawn_tile_hazard(cell, hazards_layer)
			hazards_root.add_child(h)
			out_hazards.append(h)

	return {"platforms": out_platforms, "hazards": out_hazards}


static func _looks_like_platform(layer: TileMapLayer, cell: Vector2i) -> bool:
	var atlas := layer.get_cell_atlas_coords(cell)
	## Row 0 = platform variants; (1,1)=start (2,1)=platform tint.
	return atlas.y == 0 or atlas == Vector2i(1, 1) or atlas == Vector2i(2, 1)


static func _cell_role(layer: TileMapLayer, cell: Vector2i) -> String:
	var src_id := layer.get_cell_source_id(cell)
	if src_id < 0 or layer.tile_set == null:
		return ""
	var atlas := layer.get_cell_atlas_coords(cell)
	var alt := layer.get_cell_alternative_tile(cell)
	var src: TileSetSource = layer.tile_set.get_source(src_id)
	if src is TileSetAtlasSource:
		var td: TileData = (src as TileSetAtlasSource).get_tile_data(atlas, alt)
		if td:
			var role: Variant = td.get_custom_data("role")
			if role != null and str(role) != "":
				return str(role)
	return ""


static func _horizontal_runs(cells: Array) -> Array:
	var by_row: Dictionary = {}
	for c in cells:
		var cell: Vector2i = c
		if not by_row.has(cell.y):
			by_row[cell.y] = []
		by_row[cell.y].append(cell.x)
	var runs: Array = []
	var row_ys: Array = by_row.keys()
	row_ys.sort()
	for y in row_ys:
		var xs: Array = by_row[y]
		xs.sort()
		var start_x: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size()):
			var x: int = xs[i]
			if x == prev + 1:
				prev = x
				continue
			runs.append(_make_run(start_x, prev, y))
			start_x = x
			prev = x
		runs.append(_make_run(start_x, prev, y))
	return runs


static func _make_run(x0: int, x1: int, y: int) -> Array:
	var cells: Array[Vector2i] = []
	for x in range(x0, x1 + 1):
		cells.append(Vector2i(x, y))
	return cells


static func _find_start_run(runs: Array, platform_cells: Dictionary) -> int:
	for i in runs.size():
		for cell in runs[i]:
			if platform_cells.get(cell, "") == ROLE_START:
				return i
	return 0 if not runs.is_empty() else -1


static func _spawn_platform_from_run(run: Array, layer: TileMapLayer, id: String, is_start: bool) -> Node:
	var pad: Node = PlatformScene.instantiate()
	pad.platform_id = id
	pad.label_text = id
	pad.is_start = is_start
	pad.composed_from_tiles = true
	var x0: int = run[0].x
	var x1: int = run[run.size() - 1].x
	pad.tile_span = Vector2i(x1 - x0 + 1, 1)
	pad.tile_pixel_size = TILE
	var left_center: Vector2 = layer.map_to_local(Vector2i(x0, run[0].y))
	var right_center: Vector2 = layer.map_to_local(Vector2i(x1, run[0].y))
	pad.position = Vector2((left_center.x + right_center.x) * 0.5, left_center.y)
	return pad


static func _spawn_underside_hazard(run: Array, layer: TileMapLayer, pad: Node) -> Area2D:
	var area := Area2D.new()
	area.name = "Underside_%s" % str(pad.platform_id)
	area.set_script(UndersideScript)
	var x0: int = run[0].x
	var x1: int = run[run.size() - 1].x
	var y: int = run[0].y
	var left_center: Vector2 = layer.map_to_local(Vector2i(x0, y))
	var right_center: Vector2 = layer.map_to_local(Vector2i(x1, y))
	area.position = Vector2((left_center.x + right_center.x) * 0.5, left_center.y)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var width_px := float((x1 - x0 + 1) * TILE)
	## Lower portion of the tiles — top ledge stays landable without overlapping.
	rect.size = Vector2(width_px - 2.0, 8.0)
	shape.shape = rect
	shape.position = Vector2(0, 5)
	area.add_child(shape)
	area.set_meta("underside_of", pad.platform_id)
	return area


static func _spawn_tile_hazard(cell: Vector2i, layer: TileMapLayer) -> Node:
	var h: Node = HazardScene.instantiate()
	h.position = layer.map_to_local(cell)
	## Hide sprite if the tilemap already draws the hazard art.
	if h.has_node("Sprite"):
		h.get_node("Sprite").visible = false
	return h
