extends Node2D

@export var enemy_scene: PackedScene
@onready var spawn_point: Node2D = $SpawnPoint

func _ready() -> void:
	# 예: 시작하자마자 5개 생성
	spawn_multiple(5)

func spawn_multiple(count: int) -> void:
	for i in range(count):
		var enemy = enemy_scene.instantiate()      # ① 프리팹 인스턴스 생성
		enemy.position = spawn_point.position      # ② 생성 위치 지정
		add_child(enemy)                           # ③ 씬 트리에 추가
