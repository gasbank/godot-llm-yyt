extends RigidBody2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(other: Node) -> void:
	queue_free()
