extends Node2D
## Fare loop + layout. Prefer TileMapLayer painting (PlatformsLayer / HazardsLayer).
## Legacy: hand-placed Platform/Hazard instances, or procedural spawn.

signal fare_paid(amount: int, happiness: float)
signal level_won()
signal level_lost(reason: String)
signal status_message(text: String)

const PassengerScene := preload("res://scenes/passenger.tscn")
const PlatformScene := preload("res://scenes/platform.tscn")

@export var map_size: Vector2 = Vector2(1200, 800)
@export var platform_count: int = 5
@export var building_count: int = 18
@export var hand_authored: bool = false ## Legacy instance placement (ignored if tile layers present).
@export var platform_count: int = 5
@export var building_count: int = 18
@export var fill_sky: bool = true
@export var scatter_buildings: bool = true

@onready var world: Node2D = $World
@onready var platforms_root: Node2D = $World/Platforms
@onready var decor_root: Node2D = $World/Decor
@onready var passengers_root: Node2D = $World/Passengers
@onready var cab: CharacterBody2D = $World/CyberCab
@onready var camera: Camera2D = $World/CyberCab/Camera2D
@onready var bounds: Node2D = $World/Bounds

var platforms_layer: TileMapLayer = null
var hazards_layer: TileMapLayer = null

var platforms: Array[Node] = []
var active_destination: Node = null
var rng := RandomNumberGenerator.new()
var _lost: bool = false
var _won: bool = false
var _fuel_dead_timer: float = 0.0


func _ready() -> void:
	rng.randomize()
	platforms_layer = world.get_node_or_null("PlatformsLayer") as TileMapLayer
	hazards_layer = world.get_node_or_null("HazardsLayer") as TileMapLayer
	_build_level()
	cab.landed_on_platform.connect(_on_cab_landed)
	status_message.emit("Pick up riders. Land with SPACE/E. Smooth & quick!")


func uses_tilemap() -> bool:
	return (
		platforms_layer != null
		and platforms_layer.tile_set != null
		and platforms_layer.get_used_cells().size() > 0
	)


func _build_level() -> void:
	## Clear
	for c in platforms_root.get_children():
		c.queue_free()
	for c in passengers_root.get_children():
		c.queue_free()
	for c in decor_root.get_children():
		c.queue_free()
	platforms.clear()
	hazards.clear()

	if fill_sky or scatter_buildings:
		_spawn_decor()

	if uses_tilemap():
		var built: Dictionary = TileLevelBuilder.build(
			platforms_layer, hazards_layer, platforms_root, hazards_root
		)
		platforms.assign(built.get("platforms", []))
		hazards.assign(built.get("hazards", []))
	elif hand_authored:
		_collect_hand_layout()
	else:
		for c in platforms_root.get_children():
			c.queue_free()
		for c in hazards_root.get_children():
			c.queue_free()
		_spawn_platforms()

	_wire_hazards()
	_place_cab_on_start()
	_spawn_waiting_passengers()
	_draw_bounds_visual()


func _collect_hand_layout() -> void:
	platforms.clear()
	hazards.clear()
	for p in platforms_root.get_children():
		platforms.append(p)
	for h in hazards_root.get_children():
		hazards.append(h)


func _wire_hazards() -> void:
	for h in hazards:
		if h.has_signal("struck") and not h.struck.is_connected(_on_hazard_struck):
			h.struck.connect(_on_hazard_struck)


func _on_hazard_struck(hazard: Node) -> void:
	if _lost or _won:
		return
	var reason := "Hit a no-fly pylon"
	if hazard.has_meta("underside_of"):
		reason = "Struck underside of pad %s" % str(hazard.get_meta("underside_of"))
	_fail(reason)


func _spawn_decor() -> void:
	var sky_tex: Texture2D = preload("res://assets/sprites/sky.png")
	var bldg_tex: Texture2D = preload("res://assets/sprites/building.png")
	## Tiled night sky
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
			s.modulate = Color(1, 1, 1, 1)
			s.z_index = -20
			decor_root.add_child(s)
	for i in building_count:
		var s := Sprite2D.new()
		s.texture = bldg_tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = true
		s.position = Vector2(
			rng.randf_range(40, map_size.x - 40),
			rng.randf_range(80, map_size.y - 40)
		)
		s.z_index = -10
		s.modulate = Color(1, 1, 1, 0.85)
		decor_root.add_child(s)


func _spawn_platforms() -> void:
	var ids := ["A", "B", "C", "D", "E", "F", "G", "H"]
	var count := mini(platform_count + GameState.level / 2, ids.size())
	var margin := 80.0
	var positions: Array[Vector2] = []
	## Guaranteed spread: place on a loose grid then jitter.
	var cols := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / float(cols))
	var cell_w := (map_size.x - margin * 2.0) / maxf(cols, 1)
	var cell_h := (map_size.y - margin * 2.0) / maxf(rows, 1)
	var idx := 0
	for r in rows:
		for c in cols:
			if idx >= count:
				break
			var base := Vector2(
				margin + cell_w * (c + 0.5),
				margin + cell_h * (r + 0.5)
			)
			base += Vector2(rng.randf_range(-cell_w * 0.25, cell_w * 0.25),
				rng.randf_range(-cell_h * 0.25, cell_h * 0.25))
			positions.append(base)
			idx += 1

	for i in positions.size():
		var p: Node = PlatformScene.instantiate()
		p.platform_id = ids[i]
		p.label_text = ids[i]
		platforms_root.add_child(p)
		p.global_position = positions[i]
		platforms.append(p)


func _place_cab_on_first() -> void:
	if platforms.is_empty():
		return
	var home: Node = platforms[0]
	cab.global_position = home.get_dock_global() + Vector2(0, -4)
	cab.grounded = true
	cab.current_platform = home
	cab.velocity = Vector2.ZERO


func _spawn_waiting_passengers() -> void:
	## Keep enough jobs in play for the level quota.
	var needed := GameState.fares_required_this_level - GameState.fares_completed_this_level
	var waiting := passengers_root.get_child_count()
	var to_spawn := mini(needed - waiting, platforms.size() - 1)
	to_spawn = maxi(to_spawn, 0)
	## Also keep at least 2 waiting early for feel.
	if waiting + to_spawn < mini(2, needed):
		to_spawn = mini(2, needed) - waiting
	for _i in to_spawn:
		_spawn_one_passenger()


func _spawn_one_passenger() -> void:
	if platforms.size() < 2:
		return
	var occupied: Dictionary = {}
	for pax in passengers_root.get_children():
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
	## Dropoff first
	if cab.has_passenger():
		var dest: Node = cab.passenger.get_destination()
		if platform == dest:
			_complete_fare(platform)
		else:
			status_message.emit("Wrong pad — need %s" % str(dest.label_text))
		return
	## Pickup
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
	## Kept for HUD hook; main fail handled in _process.
	pass


func _fail(reason: String) -> void:
	_lost = true
	level_lost.emit(reason)


func _draw_bounds_visual() -> void:
	## Invisible walls via StaticBody segments.
	for c in bounds.get_children():
		c.queue_free()
	_add_wall(Rect2(0, -20, map_size.x, 20))
	_add_wall(Rect2(0, map_size.y, map_size.x, 20))
	_add_wall(Rect2(-20, 0, 20, map_size.y))
	_add_wall(Rect2(map_size.x, 0, 20, map_size.y))


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	body.position = rect.position + rect.size * 0.5
	body.add_child(shape)
	bounds.add_child(body)


func get_minimap_data() -> Dictionary:
	return {
		"map_size": map_size,
		"cab_pos": cab.global_position,
		"platforms": platforms.map(func(p): return {"pos": p.global_position, "id": p.platform_id, "dest": p == active_destination}),
		"passengers": passengers_root.get_children().map(func(pax): return pax.global_position if pax.waiting else null),
	}
