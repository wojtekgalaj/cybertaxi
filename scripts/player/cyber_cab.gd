extends CharacterBody2D
## Drone cab. Heading picks a pre-drawn angle; rotors, lamp, and exhaust animate.

signal landed_on_platform(platform: Node)
signal took_off()
signal out_of_fuel()

## Must match tools/gen_cab_sprite.py. 0° is nose-right, 90° is nose-up.
const SHEET_ANGLES := 36
const SHEET_STEP := 10.0
const ANIM_FRAMES := 4
const SHEET_COLUMNS := 8
## Skids are 11px below the sheet center; this sits them on the pad top.
const SPRITE_REST_Y := -5.0

@onready var sprite: Sprite2D = $Sprite
@onready var land_ray: RayCast2D = $LandRay

var _display_heading: float = 0.0
var _anim_clock: float = 0.0

var grounded: bool = false
var current_platform: Node = null
var passenger: Node = null ## Rider aboard (Passenger node).

var _prev_velocity: Vector2 = Vector2.ZERO
var bump_accumulator: float = 0.0 ## Integrated jerk while carrying passenger.
var ride_time: float = 0.0
var prop_phase: float = 0.0
var _takeoff_grace: float = 0.0


func _ready() -> void:
	sprite.texture = preload("res://assets/sprites/cab_drone.png")
	sprite.hframes = SHEET_COLUMNS
	sprite.vframes = SHEET_ANGLES
	sprite.frame = 0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0.0, SPRITE_REST_Y)


func _physics_process(delta: float) -> void:
	if _takeoff_grace > 0.0:
		_takeoff_grace = maxf(0.0, _takeoff_grace - delta)

	if GameState.fuel <= 0.0 and not grounded:
		velocity = velocity.move_toward(Vector2(0, 80), 200.0 * delta)
		move_and_slide()
		_update_visuals()
		out_of_fuel.emit()
		return

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input.length() > 1.0:
		input = input.normalized()

	var thrusting := input.length() > 0.1
	if thrusting and not grounded:
		velocity += input * GameState.thrust * delta
	elif grounded and thrusting and input.y < -0.2:
		## Take off upward.
		grounded = false
		current_platform = null
		_takeoff_grace = 0.35
		took_off.emit()
		velocity.y = -GameState.thrust * 0.35 * delta * 60.0

	## Soft gravity when airborne so hovering takes effort.
	if not grounded:
		velocity.y += 55.0 * delta
		velocity *= 1.0 / (1.0 + GameState.drag * delta)
		if velocity.length() > GameState.max_speed:
			velocity = velocity.limit_length(GameState.max_speed)

		## Fuel
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
		## Tiny idle burn on pad optional — skip to be nicer at start.

	_prev_velocity = velocity
	move_and_slide()
	_check_landing()
	_update_visuals()
	_try_interact()


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
	var delta := get_physics_process_delta_time()
	var speed := velocity.length()
	var target := _rest_heading(_display_heading)
	if speed > 26.0:
		## Screen-up is -Y. 0° points right, 90° points up.
		target = rad_to_deg(atan2(-velocity.y, velocity.x))
	var response := 14.0 if speed > 26.0 else 7.0
	var blend := 1.0 - exp(-response * delta)
	_display_heading = rad_to_deg(lerp_angle(deg_to_rad(_display_heading), deg_to_rad(target), blend))

	var wrapped := fposmod(_display_heading, 360.0)
	var angle_idx := posmod(roundi(wrapped / SHEET_STEP), SHEET_ANGLES)
	var rate := 8.0
	if not grounded:
		rate = 13.0
	if speed > 80.0:
		rate = 18.0
	_anim_clock += delta * rate
	var anim := posmod(int(_anim_clock), ANIM_FRAMES)
	var column := anim
	if passenger != null:
		column += ANIM_FRAMES
	sprite.frame = angle_idx * SHEET_COLUMNS + column

	var bob := 0.0
	if not grounded:
		prop_phase += delta * 9.0
		bob = sin(prop_phase)
	sprite.position = Vector2(0.0, SPRITE_REST_Y + bob)


## Level off facing the way the nose was last pointed, instead of spinning to the right.
func _rest_heading(current: float) -> float:
	var a := fposmod(current, 360.0)
	if a > 90.0 and a < 270.0:
		return 180.0
	return 0.0
