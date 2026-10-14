extends Control
## Shown when a shift ends in a wreck. The district is already gone.


func _ready() -> void:
	var reason := GameState.death_reason.strip_edges()
	if reason.is_empty():
		reason = "The cab is wrecked."
	$Center/VBox/Reason.text = reason
	$Center/VBox/RetryButton.pressed.connect(_on_retry)
	$Center/VBox/MenuButton.pressed.connect(_on_menu)


func _on_retry() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_menu() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
