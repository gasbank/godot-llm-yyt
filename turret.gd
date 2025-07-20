extends Node2D

@onready var muzzle: Node2D = $Muzzle
@onready var timer: Timer = $SpawnTimer
@export var bullet_prefab: PackedScene

func _ready() -> void:
	timer.timeout.connect(_on_spawn_timer_timeout)
	
func _on_spawn_timer_timeout() -> void:
	var random_enemy = Utils.get_random_with_script(get_tree().current_scene, load("res://enemy.gd"))
	if random_enemy:
		var bullet := bullet_prefab.instantiate() as Bullet
		get_parent().add_child(bullet)
		
		#bullet.set_target($"../Player")
		bullet.set_target(random_enemy)
		bullet.global_position = muzzle.global_position
