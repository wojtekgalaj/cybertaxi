extends CanvasLayer
## F1 — live feel tweaks for GameState, dimension, and cab. Refuel included.

var level: Node = null

var _panel: PanelContainer
var _list: VBoxContainer
var _hint: Label
var _sliders: Dictionary = {} ## id -> HSlider
var _value_labels: Dictionary = {} ## id -> Label
var _syncing: bool = false


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.visible = false
	_hint.visible = true


func bind_level(level_node: Node) -> void:
	level = level_node
	_pull_from_sources()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_panel.visible = not _panel.visible
			_hint.visible = not _panel.visible
			if _panel.visible:
				_pull_from_sources()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_hint = Label.new()
	_hint.text = "Q tweaks"
	_hint.position = Vector2(12, 330)
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", Color(0.55, 0.7, 0.8, 0.7))
	add_child(_hint)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 8
	_panel.offset_top = 48
	_panel.offset_right = 280
	_panel.offset_bottom = 348
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 0.92)
	style.border_color = Color(0.2, 1.0, 0.75, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_panel.add_child(outer)

	var title := Label.new()
	title.text = "FEEL TWEAKS  (Q)"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.85))
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(250, 240)
	outer.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	_section("Cab (GameState)")
	_add_slider("thrust", "Thrust", 50.0, 900.0, 1.0)
	_add_slider("drag", "Drag", 0.0, 6.0, 0.05)
	_add_slider("max_speed", "Max speed", 60.0, 400.0, 1.0)
	_add_slider("fuel_burn", "Fuel burn (thrust)", 0.0, 30.0, 0.1)
	_add_slider("fuel_idle", "Fuel burn (idle)", 0.0, 10.0, 0.1)
	_add_slider("max_fuel", "Max fuel", 20.0, 300.0, 1.0)
	_add_slider("stability", "Stability", 0.2, 3.0, 0.05)

	_section("Dimension")
	_add_slider("gravity", "Gravity", 40.0, 450.0, 1.0)
	_add_slider("air_friction", "Air friction", 0.05, 3.0, 0.01)
	_add_slider("inertia", "Inertia", 0.05, 5.0, 0.05)

	_section("Cab feel")
	_add_slider("freefall_speed", "Freefall speed gate", 10.0, 150.0, 1.0)
	_add_slider("freefall_regen", "Freefall fuel regen", 0.0, 60.0, 0.5)
	_add_slider("soft_land", "Soft-land max speed", 40.0, 200.0, 1.0)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	outer.add_child(btns)

	var refuel := Button.new()
	refuel.text = "Refuel"
	refuel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refuel.pressed.connect(_on_refuel)
	btns.add_child(refuel)

	var pull := Button.new()
	pull.text = "Reload"
	pull.tooltip_text = "Pull current values from level / GameState"
	pull.pressed.connect(_pull_from_sources)
	btns.add_child(pull)


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
	_list.add_child(l)


func _add_slider(id: String, caption: String, min_v: float, max_v: float, step: float) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var head := HBoxContainer.new()
	var name_l := Label.new()
	name_l.text = caption
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override("font_size", 10)
	name_l.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	var val_l := Label.new()
	val_l.custom_minimum_size = Vector2(44, 0)
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_l.add_theme_font_size_override("font_size", 10)
	val_l.add_theme_color_override("font_color", Color(0.3, 1.0, 0.75))
	head.add_child(name_l)
	head.add_child(val_l)
	row.add_child(head)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(220, 12)
	slider.value_changed.connect(func(v: float): _on_slider(id, v))
	row.add_child(slider)
	_list.add_child(row)

	_sliders[id] = slider
	_value_labels[id] = val_l


func _refresh_label(id: String, value: float) -> void:
	if not _value_labels.has(id):
		return
	var step: float = _sliders[id].step if _sliders.has(id) else 0.1
	if step >= 1.0:
		_value_labels[id].text = "%d" % int(round(value))
	else:
		_value_labels[id].text = "%.2f" % value


func _set_slider(id: String, value: float) -> void:
	if not _sliders.has(id):
		return
	_syncing = true
	_sliders[id].value = value
	_syncing = false
	_refresh_label(id, value)


func _pull_from_sources() -> void:
	_set_slider("thrust", GameState.thrust)
	_set_slider("drag", GameState.drag)
	_set_slider("max_speed", GameState.max_speed)
	_set_slider("fuel_burn", GameState.fuel_burn_rate)
	_set_slider("fuel_idle", GameState.fuel_idle_burn)
	_set_slider("max_fuel", GameState.max_fuel)
	_set_slider("stability", GameState.stability)

	if level:
		_set_slider("gravity", float(level.get("gravity")))
		_set_slider("air_friction", float(level.get("air_friction")))
		_set_slider("inertia", float(level.get("inertia")))
	if level and level.get("cab"):
		var cab: Node = level.cab
		_set_slider("freefall_speed", float(cab.get("freefall_speed")))
		_set_slider("freefall_regen", float(cab.get("freefall_regen")))
		_set_slider("soft_land", float(cab.get("soft_land_speed")))


func _on_slider(id: String, value: float) -> void:
	if _syncing:
		return
	_refresh_label(id, value)
	match id:
		"thrust":
			GameState.thrust = value
		"drag":
			GameState.drag = value
		"max_speed":
			GameState.max_speed = value
		"fuel_burn":
			GameState.fuel_burn_rate = value
		"fuel_idle":
			GameState.fuel_idle_burn = value
		"max_fuel":
			GameState.max_fuel = value
			GameState.set_fuel(mini(GameState.fuel, GameState.max_fuel))
		"stability":
			GameState.stability = value
		"gravity", "air_friction", "inertia":
			_push_dimension()
		"freefall_speed":
			if level and level.cab:
				level.cab.freefall_speed = value
		"freefall_regen":
			if level and level.cab:
				level.cab.freefall_regen = value
		"soft_land":
			if level and level.cab:
				level.cab.soft_land_speed = value
				level.cab.soft_land_ray_speed = value + 10.0


func _push_dimension() -> void:
	if level == null:
		return
	level.gravity = _sliders["gravity"].value
	level.air_friction = _sliders["air_friction"].value
	level.inertia = _sliders["inertia"].value
	if level.has_method("_apply_dimension_to_cab"):
		level._apply_dimension_to_cab()
	elif level.cab and level.cab.has_method("apply_dimension"):
		level.cab.apply_dimension({
			"name": level.get("dimension_name"),
			"gravity": level.gravity,
			"friction": level.air_friction,
			"inertia": level.inertia,
		})


func _on_refuel() -> void:
	GameState.refill_fuel()
