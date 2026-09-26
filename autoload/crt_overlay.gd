extends CanvasLayer
## Persistent full-screen CRT overlay across every scene.

const CRT_SHADER := preload("res://assets/shaders/crt.gdshader")


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.name = "CRTRect"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1, 1, 1, 1)
	var mat := ShaderMaterial.new()
	mat.shader = CRT_SHADER
	rect.material = mat
	add_child(rect)
