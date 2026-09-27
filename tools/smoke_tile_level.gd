extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/levels/district_01_rooftops.tscn")
	var level: Node = packed.instantiate()
	get_root().add_child(level)
	await process_frame
	await process_frame
	print("platforms=", level.platforms.size(), " hazards=", level.hazards.size())
	for p in level.platforms:
		print(" pad ", p.platform_id, " start=", p.is_start, " span=", p.tile_span, " pos=", p.position)
	quit(0)
