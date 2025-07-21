extends Area2D

@export var hp: int = 100
@export var max_hp: int = 100

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(other: Node) -> void:
	other.queue_free()
	hp -= 1
	$HPText.text = "%d/%d" % [hp, max_hp]
