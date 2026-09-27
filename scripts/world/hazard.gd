extends Area2D
## No-fly hazard. Touching it fails the run — place under World/Hazards.

signal struck(hazard: Node)

@export var label_text: String = ""

@onready var sprite: Sprite2D = $Sprite
@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("hazards")
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	if sprite:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if label:
		label.visible = not label_text.is_empty()
		label.text = label_text


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		struck.emit(self)
