extends CharacterBody2D
## Head-on cyber cab. Strafes with a banked thrust cycle, and can only
## land once the gear is fully down.
##
## Art lives in assets/sprites/cab.aseprite (layers: hull, gear, thrust).
## Tags: idle, strafe_left, strafe_right, gear_down, gear_up, gear_idle,
## strafe_left_gear, strafe_right_gear. Frames are 32×32.
## The game plays assets/sprites/cab_sheet.png using cab_sheet.json.
## After tweaking in Aseprite, re-export over those two files:
##   aseprite -b --list-tags --format json-array --sheet-type rows --sheet-columns 8 \
##     --sheet assets/sprites/cab_sheet.png \
##     --data assets/sprites/cab_sheet.json \
##     assets/sprites/cab.aseprite

signal landed_on_platform(platform: Node)
signal took_off()
signal out_of_fuel()
signal landing_rejected

const BANK_THRESHOLD := 35.0
const BODY_OFFSET_Y := 2.0
## Chassis lift for each gear_down frame. Keeps the skids on the contact
## line while the body rises. Matches the gear cels in cab.aseprite.
const GEAR_FRAME_LIFT: Array[int] = [0, 2, 4, 6, 8]
const SHEET_JSON := "res://assets/sprites/cab_sheet.json"
const SHEET_PNG := "res://assets/sprites/cab_sheet.png"

enum GearState { UP, LOWERING, DOWN, RAISING }

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var land_ray: RayCast2D = $LandRay

var grounded: bool = false
var current_platform: Node = null
var passenger: Node = null ## Rider aboard (Passenger node).
var gear_state: GearState = GearState.DOWN

var _prev_velocity: Vector2 = Vector2.ZERO
var bump_accumulator: float = 0.0 ## Integrated jerk while carrying passenger.
var ride_time: float = 0.0
var _takeoff_grace: float = 0.0
var _told_gear: bool = false


func _ready() -> void:
	add_to_group("player")
	_load_sprite_frames()
	sprite.animation_finished.connect(_on_animation_finished)
	_sync_animation()


func _process(_delta: float) -> void:
	_apply_gear_offset()


func _physics_process(delta: float) -> void:
	if _takeoff_grace > 0.0:
		_takeoff_grace = maxf(0.0, _takeoff_grace - delta)

	_handle_gear_input()

	if GameState.fuel <= 0.0 and not grounded:
		velocity = velocity.move_toward(Vector2(0, 80), 200.0 * delta)
		move_and_slide()
		_sync_animation()
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
		## Take off upward and stow the gear. Landing again means lowering it.
		grounded = false
		current_platform = null
		_takeoff_grace = 0.35
		took_off.emit()
		velocity.y = -GameState.thrust * 0.35 * delta * 60.0
		_begin_gear(true)

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
	_sync_animation()
	_try_interact()


func _handle_gear_input() -> void:
	if grounded or not Input.is_action_just_pressed("gear"):
		return
	var raising := gear_state == GearState.DOWN or gear_state == GearState.LOWERING
	_begin_gear(raising)


func _begin_gear(raising: bool) -> void:
	if sprite.sprite_frames == null:
		return
	var last := GEAR_FRAME_LIFT.size() - 1
	if raising:
		if gear_state == GearState.UP or gear_state == GearState.RAISING:
			return
		var start := 0
		if gear_state == GearState.LOWERING and str(sprite.animation) == "gear_down":
			start = clampi(last - sprite.frame, 0, last)
		gear_state = GearState.RAISING
		_play("gear_up")
		sprite.frame = start
	else:
		if gear_state == GearState.DOWN or gear_state == GearState.LOWERING:
			return
		var start := 0
		if gear_state == GearState.RAISING and str(sprite.animation) == "gear_up":
			start = clampi(last - sprite.frame, 0, last)
		gear_state = GearState.LOWERING
		_play("gear_down")
		sprite.frame = start


func _check_landing() -> void:
	if grounded or _takeoff_grace > 0.0:
		return
	var pad := _find_landing_pad()
	if pad == null:
		_told_gear = false
		return
	if gear_state != GearState.DOWN:
		if not _told_gear:
			_told_gear = true
			landing_rejected.emit()
		return
	_land(pad)


func _find_landing_pad() -> Node:
	## Soft landing: descending slowly onto the top face only.
	if velocity.length() > 90.0 or velocity.y < 0.0:
		return null
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider and collider.is_in_group("platforms") and col.get_normal().y < -0.5:
			return collider
	if land_ray.is_colliding():
		var hit := land_ray.get_collider()
		if hit and hit.is_in_group("platforms") and velocity.y >= 0.0 and velocity.length() < 100.0:
			return hit
	return null


func _land(platform: Node) -> void:
	grounded = true
	current_platform = platform
	velocity = Vector2.ZERO
	if platform.has_method("get_cab_rest_global"):
		global_position.y = platform.get_cab_rest_global().y
	else:
		global_position.y = platform.global_position.y - 14.0
	GameState.refill_fuel()
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


func _desired_anim() -> String:
	if gear_state == GearState.LOWERING:
		return "gear_down"
	if gear_state == GearState.RAISING:
		return "gear_up"
	var gear_down := gear_state == GearState.DOWN
	var strafing := not grounded and absf(velocity.x) > BANK_THRESHOLD
	if strafing:
		var left := velocity.x < 0.0
		if gear_down:
			return "strafe_left_gear" if left else "strafe_right_gear"
		return "strafe_left" if left else "strafe_right"
	if gear_down:
		return "gear_idle"
	return "idle"


func _sync_animation() -> void:
	var anim := _desired_anim()
	if str(sprite.animation) != anim:
		_play(anim)
	_apply_gear_offset()


func _play(anim: String) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim):
		return
	sprite.play(anim)


func _apply_gear_offset() -> void:
	var lift := 0
	var anim := str(sprite.animation)
	var frame := sprite.frame
	var last := GEAR_FRAME_LIFT.size() - 1
	if anim == "gear_down":
		lift = GEAR_FRAME_LIFT[clampi(frame, 0, last)]
	elif anim == "gear_up":
		lift = GEAR_FRAME_LIFT[clampi(last - frame, 0, last)]
	elif anim == "gear_idle" or anim.ends_with("_gear"):
		lift = GEAR_FRAME_LIFT[last]
	sprite.offset = Vector2(0.0, BODY_OFFSET_Y - float(lift))


func _on_animation_finished() -> void:
	if gear_state == GearState.LOWERING and str(sprite.animation) == "gear_down":
		gear_state = GearState.DOWN
	elif gear_state == GearState.RAISING and str(sprite.animation) == "gear_up":
		gear_state = GearState.UP
	_sync_animation()


func _load_sprite_frames() -> void:
	var text := FileAccess.get_file_as_string(SHEET_JSON)
	if text.is_empty():
		push_error("Missing cab sprite sheet data: %s" % SHEET_JSON)
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Cab sprite sheet JSON is invalid.")
		return
	var data: Dictionary = parsed
	var tex: Texture2D = load(SHEET_PNG)
	var sheet := SpriteFrames.new()
	var frame_list: Array = data.get("frames", [])
	var meta: Dictionary = data.get("meta", {})
	var tag_list: Array = meta.get("frameTags", [])
	for tag_v in tag_list:
		if typeof(tag_v) != TYPE_DICTIONARY:
			continue
		var tag: Dictionary = tag_v
		var name := str(tag.get("name", ""))
		if name.is_empty():
			continue
		if not sheet.has_animation(name):
			sheet.add_animation(name)
		sheet.set_animation_speed(name, 1.0)
		sheet.set_animation_loop(name, name != "gear_down" and name != "gear_up")
		var from_i := int(tag.get("from", 0))
		var to_i := int(tag.get("to", from_i))
		var direction := str(tag.get("direction", "forward"))
		var order: Array[int] = []
		if direction == "reverse":
			for i in range(to_i, from_i - 1, -1):
				order.append(i)
		else:
			for i in range(from_i, to_i + 1):
				order.append(i)
			if direction == "pingpong":
				for i in range(to_i - 1, from_i, -1):
					order.append(i)
		for i in order:
			if i < 0 or i >= frame_list.size():
				continue
			var fr_v: Variant = frame_list[i]
			if typeof(fr_v) != TYPE_DICTIONARY:
				continue
			var fr: Dictionary = fr_v
			var rect_v: Variant = fr.get("frame", {})
			if typeof(rect_v) != TYPE_DICTIONARY:
				continue
			var rect: Dictionary = rect_v
			if bool(fr.get("rotated", false)):
				push_warning("Cab sheet frame %d is rotated; re-export without rotation." % i)
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(
				float(rect.get("x", 0)),
				float(rect.get("y", 0)),
				float(rect.get("w", 32)),
				float(rect.get("h", 32))
			)
			var dur := float(fr.get("duration", 100)) / 1000.0
			sheet.add_frame(name, atlas, maxf(dur, 0.01))
	if sheet.has_animation("default"):
		sheet.remove_animation("default")
	sprite.sprite_frames = sheet
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func force_refuel_visual() -> void:
	pass
