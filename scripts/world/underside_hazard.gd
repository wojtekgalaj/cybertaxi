extends Area2D
## Deadly underside / tile hazard. Emits struck when the cab touches it.

signal struck(hazard: Node)


func _ready() -> void:
	add_to_group("hazards")
	monitoring = true
	monitorable = true
	collision_layer = 16
	collision_mask = 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		struck.emit(self)
