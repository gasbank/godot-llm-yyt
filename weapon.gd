extends Sprite2D

@export var bullet_prefab: PackedScene
@onready var timer: Timer = $BulletSpawnTimer
@onready var muzzle: Node = $Muzzle

func _ready() -> void:
	timer.timeout.connect(_on_spawn_timer_timeout)
	
func _on_spawn_timer_timeout() -> void:
	var bullet := bullet_prefab.instantiate() as RigidBody2D
	get_parent().add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.linear_velocity = Vector2(-350,-120)
