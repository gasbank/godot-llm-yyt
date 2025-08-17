# Planet.gd
extends Node2D

@export var planet_radius: int = 3               # 타일맵 상 행성 반경
@export var planet_color: Color = Color.BLUE     # 행성 주 색상
@export var surface_color: Color = Color.CYAN    # 표면 색상
@export var atmosphere_color: Color = Color(0.5, 0.8, 1.0, 0.3)  # 대기 색상

var hex_size: float = 10.0  # 헥스 타일 크기 (부모에서 설정)
var resource_count: int = 0  # 보유 자원 개수
var resource_label: Label  # 자원 표시 레이블

func _ready():
	_create_planet_visuals()
	_create_resource_ui()

func set_hex_size(size: float):
	hex_size = size
	if is_inside_tree():
		_create_planet_visuals()
		_update_resource_ui()

func _create_planet_visuals():
	# 기존 시각 요소들만 제거 (Label은 보존)
	for child in get_children():
		if child != resource_label:
			child.queue_free()
	
	# 행성 반지름 계산 (타일맵 반경 * 헥스 크기)
	var visual_radius: float = planet_radius * hex_size
	
	# 대기권 (가장 큰 원)
	var atmosphere = _create_circle(visual_radius * 1.2, atmosphere_color)
	atmosphere.z_index = -2
	add_child(atmosphere)
	
	# 행성 본체
	var planet_body = _create_circle(visual_radius, planet_color)
	planet_body.z_index = -1
	add_child(planet_body)
	
	# 표면 디테일 (작은 원들)
	var surface_detail = _create_circle(visual_radius * 0.7, surface_color)
	surface_detail.z_index = 0
	add_child(surface_detail)
	
	# 하이라이트
	var highlight = _create_circle(visual_radius * 0.3, Color.WHITE.lerp(planet_color, 0.7))
	highlight.position = Vector2(-visual_radius * 0.2, -visual_radius * 0.2)
	highlight.z_index = 1
	add_child(highlight)

func _create_circle(radius: float, color: Color) -> Polygon2D:
	var circle = Polygon2D.new()
	circle.color = color
	
	# 원형 폴리곤 생성
	var points = PackedVector2Array()
	var segments = 32
	for i in range(segments):
		var angle = (i * 2.0 * PI) / segments
		var point = Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
	
	circle.polygon = points
	return circle

func get_occupied_tiles() -> Array[Vector2i]:
	# 이 행성이 차지하는 타일 좌표들 반환
	var occupied: Array[Vector2i] = []
	for rr in range(-planet_radius, planet_radius + 1):
		for qq in range(-planet_radius, planet_radius + 1):
			# 헥스 거리 계산
			var hex_distance = int((abs(qq) + abs(rr) + abs(qq + rr)) / 2)
			if hex_distance <= planet_radius:
				occupied.append(Vector2i(qq, rr))
	return occupied

func _create_resource_ui():
	# 자원 표시 레이블 생성
	resource_label = Label.new()
	resource_label.text = "0"
	resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resource_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 스타일 설정
	resource_label.add_theme_color_override("font_color", Color.WHITE)
	resource_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	resource_label.add_theme_constant_override("shadow_offset_x", 1)
	resource_label.add_theme_constant_override("shadow_offset_y", 1)
	resource_label.add_theme_font_size_override("font_size", 12)
	
	add_child(resource_label)
	_update_resource_ui()

func _update_resource_ui():
	if not resource_label:
		return
		
	# 행성 크기에 따른 레이블 위치 조정
	var visual_radius = planet_radius * hex_size
	resource_label.position = Vector2(-15, visual_radius + 5)  # 행성 아래쪽에 표시
	resource_label.size = Vector2(30, 20)
	
	# 자원 개수 표시
	resource_label.text = str(resource_count)
	
	# 자원이 있으면 밝게, 없으면 어둡게
	if resource_count > 0:
		resource_label.modulate = Color.WHITE
	else:
		resource_label.modulate = Color.GRAY

func set_resource_count(count: int):
	resource_count = count
	_update_resource_ui()

func add_resources(amount: int):
	resource_count += amount
	_update_resource_ui()

func get_resource_count() -> int:
	return resource_count