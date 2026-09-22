extends Control
## Between-district upgrade shop.

@onready var money_label: Label = $Panel/VBox/MoneyLabel
@onready var list: VBoxContainer = $Panel/VBox/Scroll/List
@onready var continue_btn: Button = $Panel/VBox/ContinueButton
@onready var title: Label = $Panel/VBox/Title


func _ready() -> void:
	title.text = "CHOP SHOP"
	continue_btn.pressed.connect(_on_continue)
	GameState.money_changed.connect(_refresh_money)
	_refresh_money(GameState.money)
	_rebuild_list()


func _refresh_money(amount: int) -> void:
	money_label.text = "Credits: $%d" % amount


func _rebuild_list() -> void:
	for c in list.get_children():
		c.queue_free()
	var available: Array[Dictionary] = UpgradeDB.get_available_for_purchase()
	if available.is_empty():
		var empty := Label.new()
		empty.text = "You're fully tuned. Fly safe."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)
		return
	for up in available:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_l := Label.new()
		name_l.text = "%s  —  $%d" % [up.get("name", "?"), int(up.get("cost", 0))]
		var desc_l := Label.new()
		desc_l.text = str(up.get("desc", ""))
		desc_l.modulate = Color(0.7, 0.85, 0.9)
		info.add_child(name_l)
		info.add_child(desc_l)
		var buy := Button.new()
		buy.text = "Buy"
		buy.pressed.connect(_buy.bind(str(up.get("id", "")), int(up.get("cost", 0))))
		row.add_child(info)
		row.add_child(buy)
		list.add_child(row)


func _buy(id: String, cost: int) -> void:
	if GameState.has_upgrade(id):
		return
	if not GameState.spend_money(cost):
		return
	GameState.own_upgrade(id)
	_rebuild_list()


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
