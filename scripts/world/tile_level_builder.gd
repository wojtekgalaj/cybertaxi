extends RefCounted
class_name TileLevelBuilder
## Turns painted TileMapLayer cells into pads, solid walls, and crash volumes.
## A horizontal run of platform/start tiles is one pad. Its top lip is the only
## safe surface; the underside is a hazard.

const PlatformScene := preload("res://scenes/platform.tscn")
const HazardScene := preload("res://scenes/hazard.tscn")
const UndersideScript := preload("res://scripts/world/underside_hazard.gd")

const ROLE_PLATFORM := "platform"
const ROLE_START := "start"
const ROLE_WALL := "wall"
const ROLE_HAZARD := "hazard"


static func build(
	tiles: TileMapLayer,
	platforms_root: Node2D,
	hazards_root: Node2D,
	walls_root: Node2D
) -> Dictionary:
	_clear(platforms_root)
	_clear(hazards_root)
	_clear(walls_root)

	var out_platforms: Array[Node] = []
	var out_hazards: Array[Node] = []
	var out_walls: Array[Node] = []
	if tiles == null or tiles.tile_set == null:
		return {"platforms": out_platforms, "hazards": out_hazards, "walls": out_walls}

	var tile := Vector2(tiles.tile_set.tile_size)
	var platform_cells: Dictionary = {}
	var wall_cells: Array[Vector2i] = []
	var hazard_cells: Array[Vector2i] = []

	for cell in tiles.get_used_cells():
		var role := _cell_role(tiles, cell)
		if role == ROLE_PLATFORM or role == ROLE_START:
			platform_cells[cell] = role
		elif role == ROLE_WALL:
			wall_cells.append(cell)
		elif role == ROLE_HAZARD:
			hazard_cells.append(cell)

	var runs := _horizontal_runs(platform_cells.keys())
	runs.sort_custom(func(a: Array, b: Array) -> bool:
		var ay: int = a[0].y
		var by: int = b[0].y
		if ay == by:
			return a[0].x < b[0].x
		return ay < by
	)
	var start_idx := _find_start_run(runs, platform_cells)
	if start_idx > 0:
		var start_run: Array = runs[start_idx]
		runs.remove_at(start_idx)
		runs.insert(0, start_run)

	for i in runs.size():
		var run: Array = runs[i]
		var pad := _spawn_platform(run, tiles, platforms_root, _pad_id(i), i == 0 and start_idx >= 0)
		out_platforms.append(pad)
		out_hazards.append(_spawn_underside(run, tiles, hazards_root, pad, tile.x))

	for cell in hazard_cells:
		out_hazards.append(_spawn_hazard(cell, tiles, hazards_root, tile.x))

	for block in _rects_from_cells(wall_cells):
		out_walls.append(_spawn_wall(block["origin"], block["size"], tiles, walls_root, tile))

	return {"platforms": out_platforms, "hazards": out_hazards, "walls": out_walls}


static func _clear(node: Node) -> void:
	if node == null:
		return
	while node.get_child_count() > 0:
		var child: Node = node.get_child(0)
		node.remove_child(child)
		child.free()


static func _pad_id(index: int) -> String:
	if index < 26:
		return char(65 + index)
	return "P%d" % index


static func _cell_role(layer: TileMapLayer, cell: Vector2i) -> String:
	var source_id := layer.get_cell_source_id(cell)
	if source_id < 0 or layer.tile_set == null:
		return ""
	var atlas := layer.get_cell_atlas_coords(cell)
	var alt := layer.get_cell_alternative_tile(cell)
	var source: TileSetSource = layer.tile_set.get_source(source_id)
	if source is TileSetAtlasSource:
		var data := (source as TileSetAtlasSource).get_tile_data(atlas, alt)
		if data:
			return str(data.get_custom_data("role"))
	return ""


static func _horizontal_runs(cells: Array) -> Array:
	var by_row: Dictionary = {}
	for c in cells:
		var cell: Vector2i = c
		if not by_row.has(cell.y):
			by_row[cell.y] = []
		by_row[cell.y].append(cell.x)
	var runs: Array = []
	var rows: Array = by_row.keys()
	rows.sort()
	for y in rows:
		var xs: Array = by_row[y]
		xs.sort()
		var start_x: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size()):
			var x: int = xs[i]
			if x == prev + 1:
				prev = x
				continue
			runs.append(_make_run(start_x, prev, int(y)))
			start_x = x
			prev = x
		runs.append(_make_run(start_x, prev, int(y)))
	return runs


static func _make_run(x0: int, x1: int, y: int) -> Array:
	var cells: Array[Vector2i] = []
	for x in range(x0, x1 + 1):
		cells.append(Vector2i(x, y))
	return cells


static func _find_start_run(runs: Array, platform_cells: Dictionary) -> int:
	for i in runs.size():
		for cell in runs[i]:
			if str(platform_cells.get(cell, "")) == ROLE_START:
				return i
	return 0 if not runs.is_empty() else -1


static func _spawn_platform(run: Array, layer: TileMapLayer, root: Node2D, id: String, is_start: bool) -> Node:
	var pad: Node = PlatformScene.instantiate()
	pad.platform_id = id
	pad.label_text = id
	pad.is_start = is_start
	pad.composed_from_tiles = true
	var x0: int = run[0].x
	var x1: int = run[run.size() - 1].x
	var y: int = run[0].y
	pad.tile_span = Vector2i(x1 - x0 + 1, 1)
	pad.tile_pixel_size = layer.tile_set.tile_size.x
	var left_center: Vector2 = layer.map_to_local(Vector2i(x0, y))
	var right_center: Vector2 = layer.map_to_local(Vector2i(x1, y))
	var center := Vector2((left_center.x + right_center.x) * 0.5, left_center.y)
	pad.position = root.to_local(layer.to_global(center))
	root.add_child(pad)
	return pad


static func _spawn_underside(run: Array, layer: TileMapLayer, root: Node2D, pad: Node, tile_px: float) -> Area2D:
	var area := Area2D.new()
	area.name = "Underside_%s" % str(pad.platform_id)
	area.set_script(UndersideScript)
	var x0: int = run[0].x
	var x1: int = run[run.size() - 1].x
	var y: int = run[0].y
	var left_center: Vector2 = layer.map_to_local(Vector2i(x0, y))
	var right_center: Vector2 = layer.map_to_local(Vector2i(x1, y))
	var center := Vector2((left_center.x + right_center.x) * 0.5, left_center.y)
	area.position = root.to_local(layer.to_global(center))
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	## Red belly of the tile. The cyan lip above this stays landable.
	var width_px := float((x1 - x0 + 1) * tile_px)
	rect.size = Vector2(width_px - 2.0, 9.0)
	shape.shape = rect
	shape.position = Vector2(0, 3.5)
	area.add_child(shape)
	area.set_meta("underside_of", pad.platform_id)
	root.add_child(area)
	return area


static func _spawn_hazard(cell: Vector2i, layer: TileMapLayer, root: Node2D, tile_px: float) -> Node:
	var hazard: Node = HazardScene.instantiate()
	hazard.position = root.to_local(layer.to_global(layer.map_to_local(cell)))
	hazard.set_meta("tile_px", tile_px)
	root.add_child(hazard)
	return hazard


static func _spawn_wall(origin: Vector2i, size: Vector2i, layer: TileMapLayer, root: Node2D, tile: Vector2) -> StaticBody2D:
	var top_left := layer.map_to_local(origin) - tile * 0.5
	var rect_size := Vector2(size) * tile
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("walls")
	body.position = root.to_local(layer.to_global(top_left + rect_size * 0.5))
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = rect_size
	shape.shape = rect
	body.add_child(shape)
	body.set_meta("world_rect", Rect2(layer.to_global(top_left), rect_size))
	root.add_child(body)
	return body


static func _rects_from_cells(cells: Array) -> Array:
	var remaining: Dictionary = {}
	for c in cells:
		remaining[c] = true
	var rects: Array = []
	while not remaining.is_empty():
		var start: Vector2i = remaining.keys()[0]
		for key in remaining.keys():
			var cell: Vector2i = key
			if cell.y < start.y or (cell.y == start.y and cell.x < start.x):
				start = cell
		var width := 1
		while remaining.has(Vector2i(start.x + width, start.y)):
			width += 1
		var height := 1
		while true:
			var row_ok := true
			for dx in width:
				if not remaining.has(Vector2i(start.x + dx, start.y + height)):
					row_ok = false
					break
			if not row_ok:
				break
			height += 1
		for dy in height:
			for dx in width:
				remaining.erase(Vector2i(start.x + dx, start.y + dy))
		rects.append({"origin": start, "size": Vector2i(width, height)})
	return rects
