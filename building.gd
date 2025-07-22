extends Area2D
class_name Building

@export var hp: int = 100
@export var max_hp: int = 100

signal building_destroyed()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_hp_text()
	
func _on_body_entered(other: Node) -> void:
	other.queue_free()
	hp -= 1
	_update_hp_text()
	if hp <= 0:
		queue_free()
		var explosion := preload('res://explosion.tscn').instantiate() as GPUParticles2D
		explosion.global_position = global_position
		explosion.restart()
		get_parent().add_child(explosion)
		building_destroyed.emit()
		#Delay.after(2.0, func(): Delay.pause())
		
func _update_hp_text():
	$HPText.text = "%d/%d" % [hp, max_hp]
