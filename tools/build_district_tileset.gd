extends SceneTree
## Headless: Godot --headless --path . --script res://tools/build_district_tileset.gd


func _init() -> void:
	var tex: Texture2D = load("res://assets/tiles/district_tiles.png")
	if tex == null:
		push_error("Missing district_tiles.png")
		quit(1)
		return

	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_custom_data_layer(0)
	ts.set_custom_data_layer_name(0, "role")
	ts.set_custom_data_layer_type(0, TYPE_STRING)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)

	var roles := {
		Vector2i(0, 0): "platform",
		Vector2i(1, 0): "platform",
		Vector2i(2, 0): "platform",
		Vector2i(3, 0): "platform",
		Vector2i(0, 1): "hazard",
		Vector2i(1, 1): "start",
		Vector2i(2, 1): "platform",
		Vector2i(3, 1): "hazard",
		Vector2i(0, 2): "light",
	}
	for coords in roles.keys():
		src.create_tile(coords)
	ts.add_source(src, 0)
	for coords in roles.keys():
		var td: TileData = src.get_tile_data(coords, 0)
		td.set_custom_data("role", roles[coords])

	var err := ResourceSaver.save(ts, "res://assets/tiles/district_tileset.tres")
	if err != OK:
		push_error("Failed to save tileset: %s" % err)
		quit(1)
		return
	print("Wrote res://assets/tiles/district_tileset.tres")
	quit(0)
