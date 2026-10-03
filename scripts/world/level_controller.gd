extends Node2D
## Hand-painted district. Paint World/Tiles with district_tileset.tres.
## Atlas top row: pad left, middle, right, single.
## Atlas bottom row: spikes, start pad, wall, pylon.
## A horizontal run of pad tiles is one landing pad. The cyan top is safe.
## The red belly, spikes, and pylons crash the cab. Walls are solid.
## The gold start tile marks where the cab spawns.
## Add finished scenes to data/level_catalog.gd.

signal fare_paid(amount: int, happiness: float)
signal level_won()
signal level_lost(reason: String)
signal status_message(text: String)

const PassengerScene := preload("res://scenes/passenger.tscn")
const TileBuilder := preload("res://scripts/world/tile_level_builder.gd")

@export var map_size: Vector2 = Vector2(640, 448)
@export var fill_sky: bool = true

@onready var world: Node2D = $World
@onready var platforms_root: Node2D = $World/Platforms
@onready var hazards_root: Node2D = $World/Hazards
@onready var walls_root: Node2D = $World/Walls
@onready var decor_root: Node2D = $World/Decor
@onready var passengers_root: Node2D = $World/Passengers
@onready var cab: CharacterBody2D = $World/CyberCab
@onready var camera: Camera2D = $World/CyberCab/Camera2D
@onready var bounds: Node2D = $World/Bounds
@onready var tiles: TileMapLayer = $World/Tiles

var platforms: Array[Node] = []
var hazards: Array[Node] = []
var walls: Array[Node] = []
var active_destination: Node = null
var rng := RandomNumberGenerator.new()
var _lost: bool = false
var _won: bool = false
var _fuel_dead_timer: float = 0.0


func _ready() -> void:
	rng.randomize()
	_build_level()
	cab.landed_on_platform.connect(_on_cab_landed)
	call_deferred("_announce")


func _announce() -> void:
	status_message.emit("Land on the cyan tops. Red bellies and hazards crash. SPACE/E on a pad.")


func _build_level() -> void:
	for c in passengers_root.get_children():
		c.queue_free()
	for c in decor_root.get_children():
		c.queue_free()
	platforms.clear()
	hazards.clear()
	walls.clear()

	if fill_sky:
		_spawn_sky()

	if tiles == null or tiles.tile_set == null:
		push_error("%s is missing World/Tiles. Assign district_tileset.tres and paint the district." % name)
		status_message.emit("No tileset on this district.")
	elif tiles.get_used_cells().is_empty():
		push_error("%s: paint platforms, walls, and hazards on World/Tiles." % name)
		status_message.emit("Empty district — paint World/Tiles.")
	else:
		## Keep the cab out of newly created areas until it is docked.
		cab.global_position = Vector2(-10000, -10000)
		var built: Dictionary = TileBuilder.build(tiles, platforms_root, hazards_root, walls_root)
		for p in built.get("platforms", []):
			platforms.append(p)
		for h in built.get("hazards", []):
			hazards.append(h)
		for w in built.get("walls", []):
			walls.append(w)

	_wire_hazards()
	_place_cab_on_start()
	_spawn_waiting_passengers()
	_draw_bounds_visual()


func _wire_hazards() -> void:
	for h in hazards:
		if h.has_signal("struck") and not h.struck.is_connected(_on_hazard_struck):
			h.struck.connect(_on_hazard_struck)


func _on_hazard_struck(hazard: Node) -> void:
	if _lost or _won:
		return
	var reason := "Hit a hazard"
	if hazard.has_meta("underside_of"):
		reason = "Crashed into the underside of pad %s" % str(hazard.get_meta("underside_of"))
	_fail(reason)


func _spawn_sky() -> void:
	var sky_tex: Texture2D = preload("res://assets/sprites/sky.png")
	var tile := 64
	var cols := int(map_size.x / tile) + 2
	var rows := int(map_size.y / tile) + 2
	for y in rows:
		for x in cols:
			var s := Sprite2D.new()
			s.texture = sky_tex
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.centered = false
			s.position = Vector2(x * tile - 32, y * tile - 32)
			s.z_index = -20
			decor_root.add_child(s)


func _place_cab_on_start() -> void:
	if platforms.is_empty():
		return
	var home: Node = platforms[0]
	for p in platforms:
		if p.get("is_start"):
			home = p
			break
	cab.global_position = home.get_cab_rest_global()
	cab.grounded = true
	cab.current_platform = home
	cab.velocity = Vector2.ZERO


func _spawn_waiting_passengers() -> void:
	var needed := GameState.fares_required_this_level - GameState.fares_completed_this_level
	var waiting := 0
	for pax in passengers_root.get_children():
		if is_instance_valid(pax) and not pax.is_queued_for_deletion() and pax.waiting:
			waiting += 1
	var to_spawn := mini(needed - waiting, platforms.size() - 1)
	to_spawn = maxi(to_spawn, 0)
	if waiting + to_spawn < mini(2, needed):
		to_spawn = mini(2, needed) - waiting
	for _i in to_spawn:
		_spawn_one_passenger()


func _spawn_one_passenger() -> void:
	if platforms.size() < 2:
		return
	var occupied: Dictionary = {}
	for pax in passengers_root.get_children():
		if not is_instance_valid(pax) or pax.is_queued_for_deletion():
			continue
		if pax.origin_platform:
			occupied[pax.origin_platform] = true
	var origins: Array[Node] = []
	for p in platforms:
		if not occupied.has(p) and p != cab.current_platform:
			origins.append(p)
	if origins.is_empty():
		origins = platforms.duplicate()
	var origin: Node = origins[rng.randi_range(0, origins.size() - 1)]
	var dests: Array[Node] = []
	for p in platforms:
		if p != origin:
			dests.append(p)
	var dest: Node = dests[rng.randi_range(0, dests.size() - 1)]
	var pax: Node = PassengerScene.instantiate()
	passengers_root.add_child(pax)
	pax.setup(origin, dest)


func _on_cab_landed(platform: Node) -> void:
	if _lost or _won:
		return
	if cab.has_passenger():
		var dest: Node = cab.passenger.get_destination()
		if platform == dest:
			_complete_fare(platform)
		else:
			status_message.emit("Wrong pad — need %s" % str(dest.label_text))
		return
	for pax in passengers_root.get_children():
		if pax.waiting and pax.origin_platform == platform:
			_pickup(pax)
			return
	status_message.emit("Pad %s — no rider here" % platform.label_text)


func _pickup(pax: Node) -> void:
	pax.pickup(cab)
	cab.begin_ride(pax)
	_set_destination_highlight(pax.get_destination())
	status_message.emit("Rider aboard → pad %s" % pax.get_destination().label_text)


func _complete_fare(platform: Node) -> void:
	var metrics: Dictionary = cab.end_ride()
	var pax: Node = metrics.get("passenger")
	if pax == null:
		return
	var distance: float = 0.0
	if pax.origin_platform:
		distance = pax.origin_platform.global_position.distance_to(platform.global_position)
	var happiness: float = pax.deliver(cab, float(metrics.get("bump", 0.0)), float(metrics.get("time", 0.0)))
	var pay: int = GameState.calc_fare_payout(happiness, distance)
	GameState.add_money(pay)
	GameState.register_fare_complete()
	_clear_destination_highlight()
	fare_paid.emit(pay, happiness)
	var moods := ["grumpy", "meh", "ok", "thrilled"]
	var mood: String = moods[clampi(int(happiness * 3.99), 0, 3)]
	status_message.emit("Rider %s · +$%d  (%d/%d)" % [
		mood, pay, GameState.fares_completed_this_level, GameState.fares_required_this_level
	])
	if GameState.level_complete():
		_won = true
		level_won.emit()
	else:
		_spawn_waiting_passengers()


func _set_destination_highlight(platform: Node) -> void:
	_clear_destination_highlight()
	active_destination = platform
	if platform:
		platform.set_destination_highlight(true)


func _clear_destination_highlight() -> void:
	if active_destination and is_instance_valid(active_destination):
		active_destination.set_destination_highlight(false)
	active_destination = null


func _process(delta: float) -> void:
	if _lost or _won:
		return
	if GameState.fuel <= 0.0 and not cab.grounded:
		_fuel_dead_timer += delta
		if _fuel_dead_timer > 1.6:
			_fail("Out of fuel — free fall")
	else:
		_fuel_dead_timer = 0.0


func check_fail_conditions() -> void:
	pass


func _fail(reason: String) -> void:
	if _lost or _won:
		return
	_lost = true
	level_lost.emit(reason)


func _draw_bounds_visual() -> void:
	for c in bounds.get_children():
		c.queue_free()
	_add_wall(Rect2(0, -20, map_size.x, 20))
	_add_wall(Rect2(0, map_size.y, map_size.x, 20))
	_add_wall(Rect2(-20, 0, 20, map_size.y))
	_add_wall(Rect2(map_size.x, 0, 20, map_size.y))


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	body.position = rect.position + rect.size * 0.5
	body.add_child(shape)
	bounds.add_child(body)


func get_minimap_data() -> Dictionary:
	var hazard_positions: Array = []
	for h in hazards:
		if h.has_meta("underside_of"):
			continue
		hazard_positions.append(h.global_position)
	var wall_rects: Array = []
	for w in walls:
		if w.has_meta("world_rect"):
			wall_rects.append(w.get_meta("world_rect"))
	return {
		"map_size": map_size,
		"cab_pos": cab.global_position,
		"platforms": platforms.map(func(p): return {"pos": p.global_position, "id": p.platform_id, "dest": p == active_destination}),
		"hazards": hazard_positions,
		"walls": wall_rects,
		"passengers": passengers_root.get_children().map(func(pax): return pax.global_position if pax.waiting else null),
	}
