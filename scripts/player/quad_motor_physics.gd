extends RefCounted
class_name QuadMotorPhysics
## Simplified 4-rotor drone in 2D (head-on). Stick mixes motors; tilt makes lateral thrust.
## Motor power is retuned so full throttle always out-climbs gravity (upgrades scale that).

const FL := 0
const FR := 1
const BL := 2
const BR := 3


var mass: float = 2.4
var angular_inertia: float = 2.8
var motor_force: float = 800.0 ## Peak craft thrust (all motors at 1 ≈ this force).
var arm_length: float = 14.0
var linear_drag: float = 0.85
var angular_drag: float = 5.5
var max_tilt: float = 0.72
var gravity: float = 180.0
var air_friction: float = 1.0
var max_speed: float = 240.0
var climb_margin: float = 1.7 ## Full throttle accel vs gravity.

var tilt: float = 0.0
var angular_vel: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var motors: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func reset() -> void:
	tilt = 0.0
	angular_vel = 0.0
	velocity = Vector2.ZERO
	for i in 4:
		motors[i] = 0.0


func apply_dimension(g: float, friction: float, inertia_scale: float) -> void:
	gravity = g
	air_friction = friction
	## Inertia adds mass without making the craft undrivable.
	mass = 1.15 + inertia_scale * 0.4
	angular_inertia = 1.4 + inertia_scale * 0.55
	retune_motors(520.0)


func retune_motors(thrust_stat: float) -> void:
	## Full throttle (motor sum 4 → force scale 1) lifts at climb_margin * g.
	var base := mass * gravity * climb_margin
	motor_force = base * (thrust_stat / 520.0)


func set_motor_mix(input: Vector2, powered: bool) -> void:
	if not powered:
		for i in 4:
			motors[i] = 0.0
		return
	## Stick up (input.y < 0) raises collective toward 1.
	var collective := clampf(0.42 - input.y * 0.58, 0.0, 1.0)
	if input.length() < 0.08:
		collective = 0.58 ## Neutral hover bias — slightly above hover.
	var roll := clampf(input.x, -1.0, 1.0)
	var pitch := clampf(-input.y, -1.0, 1.0) * 0.12
	motors[FL] = clampf(collective - roll * 0.4 + pitch * 0.1, 0.0, 1.0)
	motors[FR] = clampf(collective + roll * 0.4 + pitch * 0.1, 0.0, 1.0)
	motors[BL] = clampf(collective - roll * 0.4 - pitch * 0.1, 0.0, 1.0)
	motors[BR] = clampf(collective + roll * 0.4 - pitch * 0.1, 0.0, 1.0)


func integrate(delta: float) -> void:
	var left := motors[FL] + motors[BL]
	var right := motors[FR] + motors[BR]
	var total := left + right
	var torque := (right - left) * motor_force * 0.02 * arm_length
	angular_vel += (torque / maxf(0.2, angular_inertia)) * delta
	angular_vel *= 1.0 / (1.0 + angular_drag * air_friction * delta)
	tilt = clampf(tilt + angular_vel * delta, -max_tilt, max_tilt)
	if absf(tilt) >= max_tilt:
		angular_vel *= 0.4

	## total in [0,4] → thrust fraction in [0,1].
	var thrust_frac := total * 0.25
	var thrust_dir := Vector2(sin(tilt), -cos(tilt))
	var force := thrust_dir * (thrust_frac * motor_force)
	var accel := force / maxf(0.2, mass)
	accel.y += gravity
	velocity += accel * delta
	var drag := linear_drag * air_friction
	velocity *= 1.0 / (1.0 + drag * delta)
	if velocity.length() > max_speed:
		velocity = velocity.limit_length(max_speed)


func average_throttle() -> float:
	return (motors[FL] + motors[FR] + motors[BL] + motors[BR]) * 0.25


func is_spooling() -> bool:
	return average_throttle() > 0.08
