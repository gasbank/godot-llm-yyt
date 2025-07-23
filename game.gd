extends Node2D

@export var enemy_prefab: PackedScene
@export var spawn_point: Node2D

func _ready() -> void:
	# 예: 시작하자마자 5개 생성
	spawn_multiple(5)
	
	for building in _collect_building_with_type(self):
		building.building_destroyed.connect(_on_building_destroyed)

func spawn_multiple(count: int) -> void:
	if enemy_prefab:
		for i in range(count):
			var enemy = enemy_prefab.instantiate()      # ① 프리팹 인스턴스 생성
			enemy.position = spawn_point.position      # ② 생성 위치 지정
			add_child(enemy)                           # ③ 씬 트리에 추가

func _collect_building_with_type(root: Node) -> Array[Building]:
	var bucket: Array[Building] = []
	if root is Building:
		bucket.append(root)
	for child in root.get_children():
		bucket.append_array(_collect_building_with_type(child))
	return bucket

func _on_building_destroyed() -> void:
	await get_tree().create_timer(2.0).timeout
	
	get_tree().paused = true
	
	var game_over_canvas_layer := preload('res://game_over_canvas_layer.tscn').instantiate()
	game_over_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(game_over_canvas_layer)
