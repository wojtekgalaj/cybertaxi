extends SceneTree
## Builds tileset + example tilemap districts.
## Godot --headless --path . --script res://tools/build_tile_districts.gd

const TILESET_PATH := "res://assets/tiles/district_tileset.tres"
const TILE_PNG := "res://assets/tiles/district_tiles.png"
const LVL_SCRIPT := "res://scripts/world/level_controller.gd"
const CAB_SCENE := "res://scenes/cyber_cab.tscn"

const T_SINGLE := Vector2i(0, 0)
const T_LEFT := Vector2i(1, 0)
const T_MID := Vector2i(2, 0)
const T_RIGHT := Vector2i(3, 0)
const T_HAZARD := Vector2i(0, 1)
const T_START := Vector2i(1, 1)
const T_BLOCK := Vector2i(3, 1)
const T_LIGHT := Vector2i(0, 2)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _ensure_tileset():
		quit(1)
		return
	_write_district(
		"res://scenes/levels/district_01_rooftops.tscn",
		{
			"map_size": Vector2(1100, 720),
			"dimension_name": "Neon Shelf",
			"gravity": 155.0,
			"air_friction": 1.05,
			"inertia": 3.2,
			"platforms": _district_01_platforms(),
			"hazards": _district_01_hazards(),
			"lights": _district_01_lights(),
		}
	)
	_write_district(
		"res://scenes/levels/district_02_gauntlet.tscn",
		{
			"map_size": Vector2(1200, 800),
			"dimension_name": "Iron Drift",
			"gravity": 275.0,
			"air_friction": 0.42,
			"inertia": 4.0,
			"platforms": _district_02_platforms(),
			"hazards": _district_02_hazards(),
			"lights": _district_02_lights(),
		}
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
		T_LIGHT: "light",
	}
	for coords in roles.keys():
		src.create_tile(coords)
	ts.add_source(src, 0)
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
	return [
		[6, 9, 32, true],
		[22, 28, 18, false],
		[40, 43, 30, false],
		[52, 58, 12, false],
		[30, 34, 8, false],
	]


func _district_01_hazards() -> Array:
	return [[16, 24], [34, 22], [46, 18], [20, 14], [48, 28]]


func _district_01_lights() -> Array:
	## Hang lamps above key pads / routes.
	return [[8, 28], [25, 14], [41, 26], [55, 8], [32, 4]]


func _district_02_platforms() -> Array:
	return [
		[4, 8, 40, true],
		[4, 8, 12, false],
		[34, 40, 26, false],
		[64, 68, 10, false],
		[64, 68, 42, false],
		[34, 42, 6, false],
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


func _district_02_lights() -> Array:
	return [[6, 36], [6, 8], [37, 22], [66, 6], [66, 38], [38, 2]]


func _write_district(path: String, cfg: Dictionary) -> void:
	var map_size: Vector2 = cfg["map_size"]
	var root := Node2D.new()
	root.name = "Level"
	root.set_script(load(LVL_SCRIPT))
	root.set("map_size", map_size)
	root.set("building_count", 12)
	root.set("scatter_buildings", true)
	root.set("dimension_name", cfg.get("dimension_name", "Prime Strip"))
	root.set("gravity", cfg.get("gravity", 180.0))
	root.set("air_friction", cfg.get("air_friction", 1.0))
	root.set("inertia", cfg.get("inertia", 3.4))
	root.set("ambient_light", Color(0.32, 0.36, 0.48, 1.0))

	var world := Node2D.new()
	world.name = "World"
	root.add_child(world)
	world.owner = root

	for child_name in ["Decor", "Platforms", "Hazards", "Lights", "Passengers", "Bounds"]:
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

	var light_layer := TileMapLayer.new()
	light_layer.name = "LightsLayer"
	light_layer.tile_set = ts
	light_layer.z_index = -1
	world.add_child(light_layer)
	light_layer.owner = root

	for run in cfg.get("platforms", []):
		_paint_run(plat_layer, int(run[0]), int(run[1]), int(run[2]), bool(run[3]))
	for cell in cfg.get("hazards", []):
		haz_layer.set_cell(Vector2i(int(cell[0]), int(cell[1])), 0, T_HAZARD)
	for cell in cfg.get("lights", []):
		light_layer.set_cell(Vector2i(int(cell[0]), int(cell[1])), 0, T_LIGHT)

	var cab: Node = (load(CAB_SCENE) as PackedScene).instantiate()
	cab.name = "CyberCab"
	world.add_child(cab)
	cab.owner = root

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("pack failed %s" % path)
		return
	if ResourceSaver.save(packed, path) != OK:
		push_error("save failed %s" % path)
		return
	print("Saved ", path)


func _write_template() -> void:
	var root := Node2D.new()
	root.name = "Level"
	root.set_script(load(LVL_SCRIPT))
	root.set("map_size", Vector2(1100, 720))
	root.set("building_count", 16)
	root.set("inertia", 3.4)
	var world := Node2D.new()
	world.name = "World"
	root.add_child(world)
	world.owner = root
	for child_name in ["Decor", "Platforms", "Hazards", "Lights", "Passengers", "Bounds"]:
		var n := Node2D.new()
		n.name = child_name
		world.add_child(n)
		n.owner = root
	var ts: TileSet = load(TILESET_PATH)
	for layer_name in ["PlatformsLayer", "HazardsLayer", "LightsLayer"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = ts
		world.add_child(layer)
		layer.owner = root
	var cab: Node = (load(CAB_SCENE) as PackedScene).instantiate()
	cab.name = "CyberCab"
	world.add_child(cab)
	cab.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/levels/level_template.tscn")
	print("Saved level_template.tscn")
