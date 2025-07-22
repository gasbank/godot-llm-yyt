extends CanvasLayer

@export var button: Button

func _ready() -> void:
	button.pressed.connect(restart_current_scene)

func restart_current_scene():
	get_tree().paused = false
	get_tree().reload_current_scene()
