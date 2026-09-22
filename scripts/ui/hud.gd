extends CanvasLayer
## In-run HUD: fuel, money, fares, status, minimap.

@onready var fuel_bar: ProgressBar = $Root/FuelBar
@onready var money_label: Label = $Root/MoneyLabel
@onready var level_label: Label = $Root/LevelLabel
@onready var fare_label: Label = $Root/FareLabel
@onready var status_label: Label = $Root/StatusLabel
@onready var happiness_bar: ProgressBar = $Root/HappinessBar
@onready var minimap: Control = $Root/Minimap
@onready var overlay: ColorRect = $Root/Overlay
@onready var overlay_label: Label = $Root/Overlay/OverlayLabel
@onready var overlay_btn: Button = $Root/Overlay/OverlayButton

var level: Node = null
var _overlay_mode: String = "" ## "win" | "lose"


func _ready() -> void:
	overlay.visible = false
	GameState.money_changed.connect(_on_money)
	GameState.fuel_changed.connect(_on_fuel)
	GameState.level_changed.connect(_on_level)
	overlay_btn.pressed.connect(_on_overlay_btn)
	_on_money(GameState.money)
	_on_fuel(GameState.fuel, GameState.max_fuel)
	_on_level(GameState.level)
	_refresh_fares()
	happiness_bar.visible = false


func bind_level(level_node: Node) -> void:
	level = level_node
	level.fare_paid.connect(_on_fare_paid)
	level.level_won.connect(_on_level_won)
	level.level_lost.connect(_on_level_lost)
	level.status_message.connect(_on_status)
	if minimap.has_method("bind_level"):
		minimap.bind_level(level)


func _process(_delta: float) -> void:
	_refresh_fares()
	if level and level.cab and level.cab.has_passenger():
		happiness_bar.visible = true
		## Live estimate of happiness from bump + time.
		var bump: float = level.cab.bump_accumulator
		var t: float = level.cab.ride_time
		var time_score := clampf(1.2 - (t / 45.0), 0.0, 1.0)
		var smooth_score := clampf(1.0 - (bump / (10.0 * GameState.stability)), 0.0, 1.0)
		happiness_bar.value = (time_score * 0.55 + smooth_score * 0.45) * 100.0
	else:
		happiness_bar.visible = false
	if level and level.has_method("check_fail_conditions"):
		level.check_fail_conditions()


func _on_money(amount: int) -> void:
	money_label.text = "$%d" % amount


func _on_fuel(current: float, maximum: float) -> void:
	fuel_bar.max_value = maximum
	fuel_bar.value = current
	if current / maximum < 0.25:
		fuel_bar.modulate = Color(1.0, 0.4, 0.4)
	else:
		fuel_bar.modulate = Color(0.3, 1.0, 0.7)


func _on_level(lvl: int) -> void:
	level_label.text = "LVL %d" % lvl


func _refresh_fares() -> void:
	fare_label.text = "FARES %d/%d" % [GameState.fares_completed_this_level, GameState.fares_required_this_level]


func _on_fare_paid(_amount: int, _happiness: float) -> void:
	_refresh_fares()


func _on_status(text: String) -> void:
	status_label.text = text


func _on_level_won() -> void:
	_overlay_mode = "win"
	overlay.visible = true
	overlay_label.text = "District clear!\nYou earned your keep."
	if GameState.store_after_this_level():
		overlay_btn.text = "Visit Chop Shop"
	else:
		overlay_btn.text = "Next District"


func _on_level_lost(reason: String) -> void:
	_overlay_mode = "lose"
	overlay.visible = true
	overlay_label.text = "Run over\n%s" % reason
	overlay_btn.text = "Try Again"


func _on_overlay_btn() -> void:
	if _overlay_mode == "lose":
		GameState.reset_run()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	## Win
	GameState.advance_level()
	if GameState.should_visit_store():
		get_tree().change_scene_to_file("res://scenes/store.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/game.tscn")
