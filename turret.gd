extends Node2D

@onready var muzzle: Node2D = $Muzzle
@onready var timer: Timer = $SpawnTimer
@export var bullet_prefab: PackedScene
@export var only_spawn_if_enemy_exists: bool = false
@export var enemy_detector: Area2D

var can_spawn_immediately = false

func _ready() -> void:
	timer.timeout.connect(_on_spawn_timer_timeout)
	if enemy_detector:
		enemy_detector.body_entered.connect(_on_enemy_detected)
	
func _on_spawn_timer_timeout() -> void:
	var random_enemy = Utils.get_random_with_script(get_tree().current_scene, load("res://enemy.gd"))
	if random_enemy || only_spawn_if_enemy_exists == false:
		can_spawn_immediately = false
		
		var bullet := bullet_prefab.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = muzzle.global_position
	
		if bullet is Bullet:
			#bullet.set_target($"../Player")
			bullet.set_target(random_enemy)
		elif bullet is RigidBody2D:
			bullet.linear_velocity = Vector2(-600,-700)
	else:
		# 발사할 수 있는 쿨타임이 돌아왔는데, 다른 조건 때문에 발사를 못했다면
		# 다른 조건이 만족되는 순간 바로 발사될 수 있도록 한다.
		can_spawn_immediately = true

func _on_enemy_detected(_other: Node) -> void:
	if can_spawn_immediately:
		call_deferred("_on_spawn_timer_timeout")
		timer.start()
