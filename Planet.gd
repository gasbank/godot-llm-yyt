# Planet.gd
extends Node2D

@export var planet_radius: int = 3               # 타일맵 상 행성 반경
@export var planet_color: Color = Color.BLUE     # 행성 주 색상
@export var surface_color: Color = Color.CYAN    # 표면 색상
@export var atmosphere_color: Color = Color(0.5, 0.8, 1.0, 0.3)  # 대기 색상

var hex_size: float = 10.0  # 헥스 타일 크기 (부모에서 설정)
var resource_count: int = 0  # 보유 자원 개수
var resource_label: Label  # 자원 표시 레이블
var planet_name: String = ""  # 행성 이름
var name_label: Label  # 이름 표시 레이블
var base_scale: Vector2 = Vector2.ONE  # 기본 스케일

# 시설물 시스템
var facilities: Dictionary = {}  # 타일 위치별 시설물 매핑 (Vector2i -> Node2D)
var hangar_position: Vector2i  # 격납고 위치

# 신호
signal facility_popup_requested(facility_name: String, planet_name: String)
signal planet_info_requested(planet_name: String, planet_radius: int, resource_count: int)
signal resource_changed(new_resource_count: int)

func _ready():
	base_scale = get_parent().scale if get_parent() else Vector2.ONE
	_create_planet_visuals()
	_create_resource_ui()
	_create_name_ui()

func _process(_delta):
	# 부모의 스케일 변화를 감지하고 UI 스케일 보정
	if get_parent():
		var parent_scale = get_parent().scale
		if parent_scale != base_scale:
			_update_ui_scale(parent_scale)
			base_scale = parent_scale

func _update_ui_scale(parent_scale: Vector2):
	# UI 요소들이 항상 동일한 크기를 유지하도록 역스케일 적용
	var inverse_scale = Vector2(1.0 / parent_scale.x, 1.0 / parent_scale.y)
	
	if resource_label:
		resource_label.scale = inverse_scale
	if name_label:
		name_label.scale = inverse_scale

func set_hex_size(size: float):
	hex_size = size
	if is_inside_tree():
		_create_planet_visuals()
		_update_resource_ui()
		_update_name_ui()

func _create_planet_visuals():
	# 기존 시각 요소들만 제거 (Label들은 보존)
	for child in get_children():
		if child != resource_label and child != name_label:
			child.queue_free()
	
	# 행성 반지름 계산 (타일맵 반경에 맞춰 헥스 셀 영역과 일치하도록)
	# 헥스 그리드에서 반경 N인 영역의 실제 크기
	# pointy-top 헥스에서 반경 N 타일의 실제 거리는 대략 N * hex_size * sqrt(3)
	var SQRT3 = sqrt(3.0)
	var visual_radius: float = planet_radius * hex_size * SQRT3 * 0.6  # 적절한 비율로 조정
	
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
	
	resource_label.z_index = 2000  # 그리드보다 위에 표시
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
	resource_changed.emit(resource_count)

func add_resources(amount: int):
	resource_count += amount
	_update_resource_ui()
	resource_changed.emit(resource_count)

func get_resource_count() -> int:
	return resource_count

func _create_name_ui():
	# 이름 표시 레이블 생성
	name_label = Label.new()
	name_label.text = "%s (R%d)" % [planet_name, planet_radius]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 스타일 설정
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.add_theme_font_size_override("font_size", 14)
	
	name_label.z_index = 2000  # 그리드보다 위에 표시
	add_child(name_label)
	_update_name_ui()

func _update_name_ui():
	if not name_label:
		return
		
	# 행성 크기에 따른 레이블 위치 조정
	var visual_radius = planet_radius * hex_size * sqrt(3.0) * 0.6
	name_label.position = Vector2(-40, -visual_radius - 25)  # 행성 위쪽에 표시
	name_label.size = Vector2(80, 20)
	
	# 이름과 반경 표시
	name_label.text = "%s (R%d)" % [planet_name, planet_radius]

func set_planet_name(name: String):
	planet_name = name
	if name_label:
		_update_name_ui()

# 시설물 시스템 함수들
func create_hangar(tile_position: Vector2i):
	"""지정된 타일에 격납고 생성"""
	hangar_position = tile_position
	
	# 격납고 씬 로드
	var hangar_scene = preload("res://hangar.tscn")
	var hangar_instance = hangar_scene.instantiate()
	
	# 격납고를 시설물로 등록
	facilities[tile_position] = hangar_instance
	
	# 격납고 위치 설정 (상대 좌표로 변환)
	var relative_pos = _tile_to_relative_position(tile_position)
	hangar_instance.position = relative_pos
	hangar_instance.z_index = 10  # 행성 위에 표시되도록
	
	# 격납고에 행성 이름 설정 및 신호 연결
	hangar_instance.set_planet_name(planet_name)
	hangar_instance.facility_clicked.connect(_on_facility_clicked)
	
	add_child(hangar_instance)

func get_hangar_position() -> Vector2i:
	"""격납고 위치 반환"""
	return hangar_position

func _tile_to_relative_position(tile: Vector2i) -> Vector2:
	"""타일 좌표를 행성 중심 기준 상대 위치로 변환"""
	# HexTileAllBorders.gd의 _axial_to_pixel과 동일한 변환 (pointy-top)
	var q = float(tile.x)
	var r = float(tile.y)
	var SQRT3 = sqrt(3.0)
	return Vector2(
		hex_size * (SQRT3 * q + (SQRT3 * 0.5) * r),
		hex_size * (1.5 * r)
	)

func place_hangar_randomly(planet_center: Vector2i):
	"""행성이 차지하는 타일 중 하나를 랜덤으로 선택해 격납고 배치"""
	var occupied_tiles = get_occupied_tiles()
	if occupied_tiles.size() > 0:
		var random_index = randi() % occupied_tiles.size()
		var relative_tile = occupied_tiles[random_index]
		# 행성 중심 좌표를 더해서 절대 좌표로 변환
		var absolute_tile = planet_center + relative_tile
		create_hangar(relative_tile)  # 시각적 표시는 상대 좌표 사용
		hangar_position = absolute_tile  # 실제 격납고 위치는 절대 좌표

func _on_facility_clicked(facility_name: String, planet_name_from_facility: String):
	print("Planet received facility click signal: ", facility_name, " on planet: ", planet_name)
	# 시설물 클릭 시 팝업 요청 신호 발송
	facility_popup_requested.emit(facility_name, planet_name)

# 행성 클릭 이벤트 처리
func on_planet_clicked():
	print("Planet clicked: ", planet_name)
	# 행성 정보 팝업 요청 신호 발송
	planet_info_requested.emit(planet_name, planet_radius, resource_count)