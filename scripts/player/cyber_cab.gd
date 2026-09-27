extends CharacterBody2D
## Head-on cyber cab. Banks when strafing; burns fuel; tracks ride bumpiness.

signal landed_on_platform(platform: Node)
signal took_off()
signal out_of_fuel()

const BANK_THRESHOLD := 35.0
const GRAVITY := 180.0
const FREEFALL_SPEED := 50.0 ## Downward vel needed to harvest gravity for fuel.
const FREEFALL_REGEN := 22.0 ## Fuel restored per second while freefalling.

@onready var sprite: Sprite2D = $Sprite
@onready var land_ray: RayCast2D = $LandRay
@onready var prop_timer: Timer = $PropTimer

var tex_idle: Texture2D
var tex_bank_l: Texture2D
var tex_bank_r: Texture2D

var grounded: bool = false
var current_platform: Node = null
var passenger: Node = null ## Rider aboard (Passenger node).

var _prev_velocity: Vector2 = Vector2.ZERO
var bump_accumulator: float = 0.0 ## Integrated jerk while carrying passenger.
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
		velocity.y += GRAVITY * delta
		velocity = velocity.move_toward(Vector2(velocity.x * 0.5, maxf(velocity.y, 120.0)), 280.0 * delta)
		## Empty tank: always harvest while diving, ignore stuck thrust input.
		_harvest_freefall_fuel(delta, false)
		move_and_slide()
		_check_landing()
		_update_visuals()
		if GameState.fuel <= 0.0:
			out_of_fuel.emit()
		return

	if thrusting and not grounded:
		velocity += input * GameState.thrust * delta
	elif grounded and thrusting and input.y < -0.2:
		## Take off upward.
		grounded = false
		current_platform = null
		_takeoff_grace = 0.35
		took_off.emit()
		velocity.y = -GameState.thrust * 0.35 * delta * 60.0

	## Gravity pulls hard — dive to reclaim fuel.
	if not grounded:
		velocity.y += GRAVITY * delta
		velocity *= 1.0 / (1.0 + GameState.drag * delta)
		if velocity.length() > GameState.max_speed:
			velocity = velocity.limit_length(GameState.max_speed)

		if _is_freefalling(thrusting):
			_harvest_freefall_fuel(delta, thrusting)
		else:
			var burn := GameState.fuel_idle_burn
			if thrusting:
				burn = GameState.fuel_burn_rate
			GameState.consume_fuel(burn * delta)

		## Bumpiness = change in velocity (jerk proxy).
		if passenger != null:
			var dv := (velocity - _prev_velocity).length()
			var bump := maxf(0.0, dv - 18.0) ## Deadzone for gentle flight.
			bump_accumulator += bump * delta / maxf(0.2, GameState.stability)
			ride_time += delta
	else:
		velocity = Vector2.ZERO

	_prev_velocity = velocity
	move_and_slide()
	_check_landing()
	_update_visuals()
	_try_interact()


func _is_freefalling(thrusting: bool) -> bool:
	## No thrust + diving = gravity harvest.
	return not thrusting and velocity.y >= FREEFALL_SPEED


func _harvest_freefall_fuel(delta: float, thrusting: bool) -> void:
	if not _is_freefalling(thrusting):
		return
	## Faster fall → denser harvest (capped).
	var rate := FREEFALL_REGEN * clampf(velocity.y / 140.0, 0.6, 1.6)
	GameState.regain_fuel(rate * delta)


func _check_landing() -> void:
	if grounded or _takeoff_grace > 0.0:
		return
	## Soft landing: slow & near a platform area.
	if velocity.length() > 90.0:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider and collider.is_in_group("platforms"):
			_land(collider)
			return
	## Also allow proximity land via ray / overlap.
	if land_ray.is_colliding():
		var hit := land_ray.get_collider()
		if hit and hit.is_in_group("platforms") and velocity.y >= 0.0 and velocity.length() < 100.0:
			_land(hit)


func _land(platform: Node) -> void:
	grounded = true
	current_platform = platform
	velocity = Vector2.ZERO
	global_position.y = platform.global_position.y - 14.0
	landed_on_platform.emit(platform)


func _try_interact() -> void:
	if not Input.is_action_just_pressed("land"):
		return
	if not grounded or current_platform == null:
		return
	## Pickup / dropoff handled by LevelController listening to signal + polling.
	## Emit again so level can process interact.
	landed_on_platform.emit(current_platform)


func begin_ride(pax: Node) -> void:
	passenger = pax
	bump_accumulator = 0.0
	ride_time = 0.0
	_prev_velocity = velocity


func end_ride() -> Dictionary:
	## Returns ride quality metrics for fare calc.
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
	## Subtle hover bob when airborne.
	if not grounded:
		prop_phase += get_physics_process_delta_time() * 18.0
		sprite.position.y = sin(prop_phase) * 1.0
	else:
		sprite.position.y = 0.0


func _on_prop_tick() -> void:
	pass


func force_refuel_visual() -> void:
	pass
