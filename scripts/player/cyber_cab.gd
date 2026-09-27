extends CharacterBody2D
## Head-on cyber cab. Heavy inertia; dimension gravity/friction come from the level.

signal landed_on_platform(platform: Node)
signal took_off()
signal out_of_fuel()

const BANK_THRESHOLD := 28.0
const DEFAULT_GRAVITY := 180.0
const DEFAULT_FRICTION := 1.0
const DEFAULT_INERTIA := 0.6 ## Higher = slower to accelerate / change heading.

@onready var sprite: Sprite2D = $Sprite
@onready var land_ray: RayCast2D = $LandRay
@onready var prop_timer: Timer = $PropTimer

var tex_idle: Texture2D
var tex_bank_l: Texture2D
var tex_bank_r: Texture2D

var grounded: bool = false
var current_platform: Node = null
var passenger: Node = null

var dim_name: String = "Prime Strip"
var dim_gravity: float = DEFAULT_GRAVITY
var dim_friction: float = DEFAULT_FRICTION
var dim_inertia: float = DEFAULT_INERTIA

## Live-tweakable (debug panel).
var freefall_speed: float = 50.0
var freefall_regen: float = 22.0
var soft_land_speed: float = 110.0
var soft_land_ray_speed: float = 120.0

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
	prop_timer.timeout.connect(_on_prop_tick)


func apply_dimension(settings: Dictionary) -> void:
	dim_name = str(settings.get("name", dim_name))
	dim_gravity = float(settings.get("gravity", DEFAULT_GRAVITY))
	dim_friction = float(settings.get("friction", DEFAULT_FRICTION))
	dim_inertia = maxf(0.05, float(settings.get("inertia", DEFAULT_INERTIA)))


func _accel() -> float:
	## Thrust budget spread over inertia — heavy cab = sluggish vectoring.
	return GameState.thrust / dim_inertia


func _drag_coeff() -> float:
	return GameState.drag * dim_friction


func _physics_process(delta: float) -> void:
	if _takeoff_grace > 0.0:
		_takeoff_grace = maxf(0.0, _takeoff_grace - delta)

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input.length() > 1.0:
		input = input.normalized()
	var thrusting := input.length() > 0.1

	if GameState.fuel <= 0.0 and not grounded:
		velocity.y += dim_gravity * delta
		_apply_drag(delta)
		velocity = velocity.move_toward(
			Vector2(velocity.x * 0.85, maxf(velocity.y, dim_gravity * 0.55)),
			(120.0 / dim_inertia) * delta
		)
		_harvest_freefall_fuel(delta, false)
		move_and_slide()
		_check_landing()
		_update_visuals()
		if GameState.fuel <= 0.0:
			out_of_fuel.emit()
		return

	if thrusting and not grounded:
		## Momentum-heavy: add acceleration, don't snap velocity to input.
		velocity += input * _accel() * delta
	elif grounded and thrusting and input.y < -0.2:
		grounded = false
		current_platform = null
		_takeoff_grace = 0.4
		took_off.emit()
		velocity.y = -_accel() * 0.55

	if not grounded:
		velocity.y += dim_gravity * delta
		_apply_drag(delta)
		if velocity.length() > GameState.max_speed:
			velocity = velocity.limit_length(GameState.max_speed)

		if _is_freefalling(thrusting):
			_harvest_freefall_fuel(delta, thrusting)
		else:
			var burn := GameState.fuel_idle_burn
			if thrusting:
				burn = GameState.fuel_burn_rate
			GameState.consume_fuel(burn * delta)

		if passenger != null:
			var dv := (velocity - _prev_velocity).length()
			## Tighter deadzone — inertia makes big vector changes costly for tips.
			var bump := maxf(0.0, dv - 12.0)
			bump_accumulator += bump * delta / maxf(0.2, GameState.stability)
			ride_time += delta
	else:
		velocity = Vector2.ZERO

	_prev_velocity = velocity
	move_and_slide()
	_check_landing()
	_update_visuals()
	_try_interact()


func _apply_drag(delta: float) -> void:
	## Low dimension friction = icy slide; high = thick air.
	velocity *= 1.0 / (1.0 + _drag_coeff() * delta)


func _is_freefalling(thrusting: bool) -> bool:
	return not thrusting and velocity.y >= freefall_speed


func _harvest_freefall_fuel(delta: float, thrusting: bool) -> void:
	if not _is_freefalling(thrusting):
		return
	var rate := freefall_regen * clampf(velocity.y / maxf(100.0, dim_gravity * 0.75), 0.6, 1.6)
	GameState.regain_fuel(rate * delta)


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
	if absf(velocity.x) > BANK_THRESHOLD:
		sprite.texture = tex_bank_l if velocity.x < 0.0 else tex_bank_r
	else:
		sprite.texture = tex_idle
	if not grounded:
		prop_phase += get_physics_process_delta_time() * 18.0
		sprite.position.y = sin(prop_phase) * 1.0
	else:
		sprite.position.y = 0.0


func _on_prop_tick() -> void:
	pass


func force_refuel_visual() -> void:
	pass
