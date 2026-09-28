extends Node2D
## Cone lamp. Charges drone batteries when the cab is inside the beam with clear LOS.
## Platforms / world walls block the cone via LightOccluder2D + ray check.

signal charge_zone_changed(active: bool)

@export var cone_range: float = 140.0
@export var cone_half_angle_deg: float = 38.0
@export var charge_rate: float = 32.0 ## Battery / second while illuminated.
@export var aim_degrees: float = 90.0 ## 90 = beam points down.

@onready var lamp: Sprite2D = $Lamp
@onready var light: PointLight2D = $PointLight2D

var _cab: Node2D = null


func _ready() -> void:
	add_to_group("light_sources")
	if lamp:
		lamp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if light:
		light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		light.shadow_enabled = true
		light.range_item_cull_mask = 1
		light.shadow_item_cull_mask = 1
		light.energy = 1.35
		light.texture_scale = cone_range / 64.0
	rotation_degrees = aim_degrees - 90.0 ## Texture cone points +Y in local; aim_degrees from +X.


func bind_cab(cab: Node2D) -> void:
	_cab = cab


func _physics_process(_delta: float) -> void:
	if light:
		light.texture_scale = cone_range / 64.0


func illuminates(global_point: Vector2) -> bool:
	var local_pt := to_local(global_point)
	## Cone texture points along local +Y after rotation setup.
	var to_pt := local_pt
	var dist := to_pt.length()
	if dist < 4.0:
		return true
	if dist > cone_range:
		return false
	var forward := Vector2.DOWN.rotated(0.0) ## local +Y
	var ang := absf(forward.angle_to(to_pt.normalized()))
	if ang > deg_to_rad(cone_half_angle_deg):
		return false
	return _has_line_of_sight(global_point)


func _has_line_of_sight(global_point: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_point)
	query.collision_mask = 1 | 4 ## world + platforms
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	## Allow if we nearly reached the target (hit the cab body, etc.).
	var hit_pos: Vector2 = hit.get("position", global_point)
	return hit_pos.distance_to(global_point) < 12.0
