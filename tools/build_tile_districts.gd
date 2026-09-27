extends SceneTree
## Builds tileset + example tilemap districts.
## Godot --headless --path . --script res://tools/build_tile_districts.gd

const TILESET_PATH := "res://assets/tiles/district_tileset.tres"
const TILE_PNG := "res://assets/tiles/district_tiles.png"
const LVL_SCRIPT := "res://scripts/world/level_controller.gd"
const CAB_SCENE := "res://scenes/cyber_cab.tscn"

## Atlas coords
const T_SINGLE := Vector2i(0, 0)
const T_LEFT := Vector2i(1, 0)
const T_MID := Vector2i(2, 0)
const T_RIGHT := Vector2i(3, 0)
const T_HAZARD := Vector2i(0, 1)
const T_START := Vector2i(1, 1)
const T_BLOCK := Vector2i(3, 1)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _ensure_tileset():
		quit(1)
		return
	_write_district(
		"res://scenes/levels/district_01_rooftops.tscn",
		Vector2(1100, 720),
		_district_01_platforms(),
		_district_01_hazards()
	)
	_write_district(
		"res://scenes/levels/district_02_gauntlet.tscn",
		Vector2(1200, 800),
		_district_02_platforms(),
		_district_02_hazards()
	)
	_write_template()
	print("Tile districts ready.")
	quit(0)


func _ensure_tileset() -> bool:
	var tex: Texture2D = load(TILE_PNG)
	if tex == null:
		push_error("Missing %s" % TILE_PNG)
		return false
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_custom_data_layer(0)
	ts.set_custom_data_layer_name(0, "role")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	var roles := {
		T_SINGLE: "platform",
		T_LEFT: "platform",
		T_MID: "platform",
		T_RIGHT: "platform",
		T_HAZARD: "hazard",
		T_START: "start",
		Vector2i(2, 1): "platform",
		T_BLOCK: "hazard",
	}
	for coords in roles.keys():
		src.create_tile(coords)
	ts.add_source(src, 0)
	## Custom data requires the atlas source to already belong to the TileSet.
	for coords in roles.keys():
		var td: TileData = src.get_tile_data(coords, 0)
		td.set_custom_data("role", roles[coords])
	var err := ResourceSaver.save(ts, TILESET_PATH)
	if err != OK:
		push_error("Save tileset failed: %s" % err)
		return false
	print("Saved ", TILESET_PATH)
	return true


func _paint_run(layer: TileMapLayer, x0: int, x1: int, y: int, start: bool = false) -> void:
	var width := x1 - x0 + 1
	for x in range(x0, x1 + 1):
		var atlas := T_MID
		if width == 1:
			atlas = T_START if start else T_SINGLE
		elif x == x0:
			atlas = T_START if start else T_LEFT
		elif x == x1:
			atlas = T_RIGHT
		else:
			atlas = T_MID
		if start and x == x0 and width > 1:
			atlas = T_START
		layer.set_cell(Vector2i(x, y), 0, atlas)


func _district_01_platforms() -> Array:
	## Each entry: [x0, x1, y, is_start]
	return [
		[6, 9, 32, true], ## short start
		[22, 28, 18, false], ## long
		[40, 43, 30, false],
		[52, 58, 12, false], ## long high
		[30, 34, 8, false],
	]


func _district_01_hazards() -> Array:
	## Each: [x, y]
	return [[16, 24], [34, 22], [46, 18], [20, 14], [48, 28]]


func _district_02_platforms() -> Array:
	return [
		[4, 8, 40, true],
		[4, 8, 12, false],
		[34, 40, 26, false], ## long mid
		[64, 68, 10, false],
		[64, 68, 42, false],
		[34, 42, 6, false], ## very long top
	]


func _district_02_hazards() -> Array:
	var cells: Array = []
	for y in range(16, 36):
		cells.append([16, y])
		cells.append([54, y])
	for x in [28, 30, 44, 46]:
		cells.append([x, 18])
		cells.append([x, 34])
	cells.append([37, 16])
	cells.append([37, 36])
	return cells


func _write_district(path: String, map_size: Vector2, platform_runs: Array, hazard_cells: Array) -> void:
	var root := Node2D.new()
	root.name = "Level"
	root.set_script(load(LVL_SCRIPT))
	root.set("hand_authored", true)
	root.set("map_size", map_size)
	root.set("building_count", 12)
	root.set("scatter_buildings", true)

	var world := Node2D.new()
	world.name = "World"
	root.add_child(world)
	world.owner = root

	for child_name in ["Decor", "Platforms", "Hazards", "Passengers", "Bounds"]:
		var n := Node2D.new()
		n.name = child_name
		world.add_child(n)
		n.owner = root

	var ts: TileSet = load(TILESET_PATH)
	var plat_layer := TileMapLayer.new()
	plat_layer.name = "PlatformsLayer"
	plat_layer.tile_set = ts
	plat_layer.z_index = -1
	world.add_child(plat_layer)
	plat_layer.owner = root

	var haz_layer := TileMapLayer.new()
	haz_layer.name = "HazardsLayer"
	haz_layer.tile_set = ts
	haz_layer.z_index = -1
	world.add_child(haz_layer)
	haz_layer.owner = root

	for run in platform_runs:
		_paint_run(plat_layer, int(run[0]), int(run[1]), int(run[2]), bool(run[3]))
	for cell in hazard_cells:
		haz_layer.set_cell(Vector2i(int(cell[0]), int(cell[1])), 0, T_HAZARD)

	var cab: Node = (load(CAB_SCENE) as PackedScene).instantiate()
	cab.name = "CyberCab"
	world.add_child(cab)
	cab.owner = root

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed %s" % path)
		return
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("save failed %s: %s" % [path, err])
		return
	print("Saved ", path)


func _write_template() -> void:
	var root := Node2D.new()
	root.name = "Level"
	root.set_script(load(LVL_SCRIPT))
	root.set("map_size", Vector2(1100, 720))
	root.set("platform_count", 5)
	root.set("building_count", 16)
	var world := Node2D.new()
	world.name = "World"
	root.add_child(world)
	world.owner = root
	for child_name in ["Decor", "Platforms", "Hazards", "Passengers", "Bounds"]:
		var n := Node2D.new()
		n.name = child_name
		world.add_child(n)
		n.owner = root
	var ts: TileSet = load(TILESET_PATH)
	var plat_layer := TileMapLayer.new()
	plat_layer.name = "PlatformsLayer"
	plat_layer.tile_set = ts
	world.add_child(plat_layer)
	plat_layer.owner = root
	var haz_layer := TileMapLayer.new()
	haz_layer.name = "HazardsLayer"
	haz_layer.tile_set = ts
	world.add_child(haz_layer)
	haz_layer.owner = root
	var cab: Node = (load(CAB_SCENE) as PackedScene).instantiate()
	cab.name = "CyberCab"
	world.add_child(cab)
	cab.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/levels/level_template.tscn")
	print("Saved level_template.tscn")
