extends Control


func _ready() -> void:
	$Center/VBox/PlayButton.pressed.connect(_on_play)
	$Center/VBox/QuitButton.pressed.connect(_on_quit)


func _on_play() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_quit() -> void:
	get_tree().quit()
