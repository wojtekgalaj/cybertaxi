extends CharacterBody2D
## Head-on cyber cab driven by QuadMotorPhysics. Batteries charge in light cones.

signal landed_on_platform(platform: Node)
signal took_off()
signal out_of_battery()

const BANK_TILT := 0.22
const DEFAULT_GRAVITY := 180.0
const DEFAULT_FRICTION := 1.0
const DEFAULT_INERTIA := 3.2

@onready var sprite: Sprite2D = $Sprite
@onready var land_ray: RayCast2D = $LandRay
@onready var prop_timer: Timer = $PropTimer

var tex_idle: Texture2D
var tex_bank_l: Texture2D
var tex_bank_r: Texture2D

var grounded: bool = false
var current_platform: Node = null
var passenger: Node = null
var in_light: bool = false

var dim_name: String = "Prime Strip"
var dim_gravity: float = DEFAULT_GRAVITY
var dim_friction: float = DEFAULT_FRICTION
var dim_inertia: float = DEFAULT_INERTIA

var soft_land_speed: float = 100.0
var soft_land_ray_speed: float = 110.0

var flight := QuadMotorPhysics.new()
var _prev_velocity: Vector2 = Vector2.ZERO
var bump_accumulator: float = 0.0
var ride_time: float = 0.0
var prop_phase: float = 0.0
var _takeoff_grace: float = 0.0


func _ready() -> void:
	add_to_group("player")
	tex_idle = preload("res://assets/sprites/cab.png")
	tex_bank_l = preload("res://assets/sprites/cab_bank_l.png")
	tex_bank_r = preload("res://assets/sprites/cab_bank_r.png")
	sprite.texture = tex_idle
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 10
	## Stay readable in dark districts — small self-light + unshaded fill.
	sprite.modulate = Color(1.15, 1.15, 1.2, 1.0)
	_ensure_nav_light()
	prop_timer.timeout.connect(_on_prop_tick)
	flight.apply_dimension(dim_gravity, dim_friction, dim_inertia)
	flight.max_speed = GameState.max_speed
	flight.retune_motors(GameState.thrust)


func _ensure_nav_light() -> void:
	if get_node_or_null("NavLight") != null:
		return
	var nav := PointLight2D.new()
	nav.name = "NavLight"
	nav.color = Color(0.55, 0.95, 1.0, 1.0)
	nav.energy = 0.85
	nav.texture_scale = 0.55
	## Soft omni blob so the cab silhouette always reads.
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a *= a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	nav.texture = ImageTexture.create_from_image(img)
	nav.shadow_enabled = false
	add_child(nav)


func apply_dimension(settings: Dictionary) -> void:
	dim_name = str(settings.get("name", dim_name))
	dim_gravity = float(settings.get("gravity", DEFAULT_GRAVITY))
	dim_friction = float(settings.get("friction", DEFAULT_FRICTION))
	dim_inertia = maxf(0.4, float(settings.get("inertia", DEFAULT_INERTIA)))
	flight.apply_dimension(dim_gravity, dim_friction, dim_inertia)
	flight.retune_motors(GameState.thrust)


func _physics_process(delta: float) -> void:
	if _takeoff_grace > 0.0:
		_takeoff_grace = maxf(0.0, _takeoff_grace - delta)

	flight.max_speed = GameState.max_speed
	flight.retune_motors(GameState.thrust)

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input.length() > 1.0:
		input = input.normalized()

	_update_light_charge(delta)

	var has_power := GameState.battery > 0.0
	if grounded:
		flight.reset()
		velocity = Vector2.ZERO
		if has_power and input.y < -0.2:
			grounded = false
			current_platform = null
			_takeoff_grace = 0.55
			took_off.emit()
			flight.set_motor_mix(Vector2(0, -1), true)
			flight.velocity = Vector2(0, -90)
			velocity = flight.velocity
	else:
		flight.set_motor_mix(input, has_power)
		flight.integrate(delta)
		velocity = flight.velocity
		if has_power:
			var burn := GameState.battery_idle_burn
			if flight.is_spooling():
				burn = lerpf(GameState.battery_idle_burn, GameState.battery_burn_rate, flight.average_throttle())
			GameState.consume_battery(burn * delta)
		else:
			out_of_battery.emit()

		if passenger != null:
			var dv := (velocity - _prev_velocity).length()
			var bump := maxf(0.0, dv - 10.0)
			bump_accumulator += bump * delta / maxf(0.2, GameState.stability)
			ride_time += delta

	_prev_velocity = velocity
	move_and_slide()
	if not grounded:
		flight.velocity = velocity
	_check_landing()
	_update_visuals()
	_try_interact()


func _update_light_charge(delta: float) -> void:
	in_light = false
	for light in get_tree().get_nodes_in_group("light_sources"):
		if light.has_method("illuminates") and light.illuminates(global_position):
			in_light = true
			GameState.charge_battery(float(light.charge_rate) * delta)
			break


func _check_landing() -> void:
	if grounded or _takeoff_grace > 0.0:
		return
	if velocity.length() > soft_land_speed:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider and collider.is_in_group("platforms"):
			_land(collider)
			return
	if land_ray.is_colliding():
		var hit := land_ray.get_collider()
		if hit and hit.is_in_group("platforms") and velocity.y >= 0.0 and velocity.length() < soft_land_ray_speed:
			_land(hit)


func _land(platform: Node) -> void:
	grounded = true
	current_platform = platform
	velocity = Vector2.ZERO
	flight.reset()
	if platform.has_method("get_dock_global"):
		global_position = platform.get_dock_global() + Vector2(0, -4)
	else:
		global_position.y = platform.global_position.y - 14.0
	landed_on_platform.emit(platform)


func _try_interact() -> void:
	if not Input.is_action_just_pressed("land"):
		return
	if not grounded or current_platform == null:
		return
	landed_on_platform.emit(current_platform)


func begin_ride(pax: Node) -> void:
	passenger = pax
	bump_accumulator = 0.0
	ride_time = 0.0
	_prev_velocity = velocity


func end_ride() -> Dictionary:
	var result := {
		"bump": bump_accumulator,
		"time": ride_time,
		"passenger": passenger,
	}
	passenger = null
	bump_accumulator = 0.0
	ride_time = 0.0
	return result


func has_passenger() -> bool:
	return passenger != null


func _update_visuals() -> void:
	if absf(flight.tilt) > BANK_TILT:
		sprite.texture = tex_bank_l if flight.tilt < 0.0 else tex_bank_r
	elif absf(velocity.x) > 40.0:
		sprite.texture = tex_bank_l if velocity.x < 0.0 else tex_bank_r
	else:
		sprite.texture = tex_idle
	if not grounded:
		prop_phase += get_physics_process_delta_time() * (14.0 + flight.average_throttle() * 20.0)
		sprite.position.y = sin(prop_phase) * 1.0
		sprite.rotation = flight.tilt * 0.35
	else:
		sprite.position.y = 0.0
		sprite.rotation = 0.0


func _on_prop_tick() -> void:
	pass
