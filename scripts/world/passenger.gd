extends Area2D
## Person waiting on a platform for a ride to another platform.

signal picked_up(passenger: Node)
signal delivered(passenger: Node, happiness: float)

@export var patience: float = 45.0 ## Ideal max ride time before happiness tanks.

@onready var sprite: Sprite2D = $Sprite
@onready var wave_timer: Timer = $WaveTimer

var origin_platform: Node = null
var destination_platform: Node = null
var waiting: bool = true
var aboard: bool = false
var wave_dir: float = 1.0


func _ready() -> void:
	add_to_group("passengers")
	sprite.texture = preload("res://assets/sprites/passenger.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wave_timer.timeout.connect(_on_wave)


func setup(origin: Node, destination: Node) -> void:
	origin_platform = origin
	destination_platform = destination
	var spread := 8.0
	var span: Variant = origin.get("tile_span")
	if span is Vector2i and (span as Vector2i).x > 1:
		var tile_px := float(origin.get("tile_pixel_size"))
		spread = maxf(8.0, float((span as Vector2i).x) * tile_px * 0.3)
	global_position = origin.get_dock_global() + Vector2(randf_range(-spread, spread), 0)


func _process(delta: float) -> void:
	if waiting:
		sprite.position.x = sin(Time.get_ticks_msec() * 0.008) * 2.0 * wave_dir
	elif aboard:
		## Stick to cab — parented externally; keep local offset.
		pass


func _on_wave() -> void:
	wave_dir *= -1.0


func pickup(cab: Node) -> void:
	waiting = false
	aboard = true
	reparent(cab)
	position = Vector2(0, -10)
	sprite.visible = false ## Hidden while aboard (cab carries them).
	picked_up.emit(self)


func deliver(cab: Node, bump: float, ride_time: float) -> float:
	aboard = false
	var ideal := patience
	## Speed happiness: 1 at fast rides, falls after ideal time.
	var time_score := clampf(1.2 - (ride_time / ideal), 0.0, 1.0)
	## Smoothness: bump accumulator of ~8+ starts hurting.
	var smooth_score := clampf(1.0 - (bump / (10.0 * GameState.stability)), 0.0, 1.0)
	var happiness := clampf(time_score * 0.55 + smooth_score * 0.45, 0.0, 1.0)
	delivered.emit(self, happiness)
	queue_free()
	return happiness


func get_destination() -> Node:
	return destination_platform
