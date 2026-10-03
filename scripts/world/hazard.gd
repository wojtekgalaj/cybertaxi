extends Area2D
## Painted hazard. Touching it crashes the cab.

signal struck(hazard: Node)


func _ready() -> void:
	add_to_group("hazards")
	monitoring = true
	monitorable = true
	collision_layer = 16
	collision_mask = 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if has_meta("tile_px"):
		var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col:
			var rect := RectangleShape2D.new()
			var extent := float(get_meta("tile_px")) - 2.0
			rect.size = Vector2(extent, extent)
			col.shape = rect


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		struck.emit(self)
