extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
func _on_body_entered(body: Node) -> void:
	print('entered:', body.name)
	
func _on_body_exited(body: Node) -> void:
	print('exited:', body.name)
