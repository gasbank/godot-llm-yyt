# HexTileAllBorders.gd
extends Node2D
## 반경 R 헥스맵의 모든 경계선을 하나의 Mesh로 생성
## 마우스 휠/핀치 줌 + 드래그 패닝 + Hover 타일 채우기

@export var radius: int = 200                      # 헥스 반경 (축좌표 거리 ≤ R)
@export var hex_size: float = 10.0                 # 헥스 반지름(센터→꼭짓점 픽셀)
@export var pointy_top: bool = true                # true: pointy-top / false: flat-top
@export var line_width: float = 2.0                # 경계선 굵기(월드 좌표 기준)
@export var line_color: Color = Color.BLACK
@export var center_in_viewport: bool = true
@export var z_index_on_top: int = 1000

# === 줌 설정 ===
@export var zoom_step: float = 1.1
@export var min_zoom: float = 0.2
@export var max_zoom: float = 8.0
@export var keep_pixel_line_width: bool = false
@export var pixel_line_px: float = 2.0

# === 패닝 설정 ===
@export_enum("Left", "Middle", "Right") var pan_button: int = 1   # 기본 Middle
@export var allow_spacebar_pan: bool = true                       # Space + Left 로 패닝

# === Hover Fill 설정 ===
@export var hover_fill_color: Color = Color(1.0, 0.85, 0.2, 0.35)  # 반투명
@export var show_hover_when_outside: bool = false

# === 클릭 토글 설정 ===
@export var click_fill_color: Color = Color(0.0, 0.5, 1.0, 0.6)  # 파란색

# === 행성 셀 구분 설정 ===
@export var show_planet_cells: bool = true                      # 행성 셀 표시 여부
@export var planet_cell_fill_color: Color = Color(0.2, 0.3, 0.1, 0.2)  # 연한 녹색
@export var planet_cell_line_color: Color = Color(0.4, 0.6, 0.2, 0.8)  # 녹색 테두리

# === 광물 배치 설정 ===
@export var ore_count: int = 100                                  # 배치할 광물 개수
@export var min_ore_distance: int = 3                             # 광물 간 최소 거리
@export var ore_random_seed: int = 1985                           # 광물 배치 랜덤 시드
@export var ore_scene: PackedScene = preload("res://ore.tscn")    # 광물 씬

# === 행성 배치 설정 ===
@export var planet_count: int = 30                                # 배치할 행성 개수
@export var min_planet_distance: int = 8                          # 행성 간 최소 거리
@export var planet_random_seed: int = 2023                        # 행성 배치 랜덤 시드
@export var planet_scene: PackedScene = preload("res://planet.tscn") # 행성 씬

# === 우주선 설정 ===
@export var frigate_scene: PackedScene = preload("res://frigate.tscn") # 우주선 씬

# === 턴 시스템 설정 ===
@export var turn_duration: float = 1.0                           # 턴당 시간 (초)
@export var auto_play: bool = true                               # 자동 진행 여부

# === 뷰포트 상태 저장 설정 ===
@export var save_viewport_state: bool = true                      # 뷰포트 상태 저장 여부
var _config_file_path: String = "user://viewport_state.cfg"       # 설정 파일 경로
var _save_timer: Timer                                             # 저장 지연 타이머

const SQRT3: float = 1.7320508075688772

var _mesh_instance: MeshInstance2D
var _zoom: float = 1.0
var _corner_off: Array[Vector2]                                   # 6개 코너 오프셋

# 패닝 상태
var _panning: bool = false
var _active_pan_button: int = -1

# Hover fill
var _hover_poly: Polygon2D
var _hover_tile: Vector2i = Vector2i(2147483647, 2147483647)      # 불가능한 초기값

# 클릭된 타일들 저장
var _clicked_tiles: Dictionary = {}  # Vector2i -> bool
var _clicked_polys: Dictionary = {}  # Vector2i -> Polygon2D

# 광물 관리
var _ore_positions: Array[Vector2i] = []  # 광물이 배치된 타일 좌표
var _ore_instances: Array[Node2D] = []    # 광물 인스턴스들

# 행성 관리
var _planet_positions: Array[Vector2i] = []  # 행성이 배치된 중심 타일 좌표
var _planet_instances: Array[Node2D] = []    # 행성 인스턴스들
var _planet_resources: Dictionary = {}       # 행성별 보유 자원 (Vector2i -> int)
var _occupied_tiles: Dictionary = {}         # 모든 점유된 타일 (광물 + 행성)
var _planet_cell_polys: Array[Polygon2D] = [] # 행성 셀 표시용 폴리곤들

# 우주선 관리
var _frigate_instances: Array[Node2D] = []   # 우주선 인스턴스들
var _frigate_positions: Dictionary = {}      # 우주선 위치 추적 (Vector2i -> Node2D)
var _mining_tiles: Dictionary = {}           # 채집 중인 타일 (Vector2i -> Node2D)

# 턴 시스템
var _turn_timer: Timer
var _current_turn: int = 0
var _frigates_ready: int = 0                 # 턴 완료한 우주선 수

func _ready() -> void:
	if center_in_viewport:
		var vp_size: Vector2 = get_viewport_rect().size
		position = vp_size * 0.5

	_corner_off = _corner_offsets(hex_size, pointy_top)

	_mesh_instance = MeshInstance2D.new()
	_mesh_instance.z_index = z_index_on_top
	_mesh_instance.modulate = line_color
	add_child(_mesh_instance)
	_refresh_mesh()

	_hover_poly = Polygon2D.new()
	_hover_poly.color = hover_fill_color
	_hover_poly.visible = false
	_hover_poly.z_index = z_index_on_top + 2
	add_child(_hover_poly)
	
	# 저장 타이머 설정
	_save_timer = Timer.new()
	_save_timer.wait_time = 1.0  # 1초 후 저장
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_save_viewport_state)
	add_child(_save_timer)
	
	# 턴 타이머 설정
	_turn_timer = Timer.new()
	_turn_timer.wait_time = turn_duration
	_turn_timer.timeout.connect(_process_turn)
	add_child(_turn_timer)

	_apply_zoom()
	_update_hover_fill()
	
	# 행성 먼저 배치 (크기가 크므로)
	_place_planets()
	
	# 광물 배치 (행성 위치를 피해서)
	_place_ores()
	
	# 우주선 배치 (각 행성마다 하나씩)
	_place_frigates()
	
	# 턴 시스템 시작
	if auto_play:
		_turn_timer.start()
	
	# 저장된 뷰포트 상태 복원
	_load_viewport_state()

func _unhandled_input(event: InputEvent) -> void:
	# === 줌 ===
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(get_viewport().get_mouse_position(), zoom_step)
			_update_hover_fill()
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(get_viewport().get_mouse_position(), 1.0 / zoom_step)
			_update_hover_fill()
			return
	elif event is InputEventMagnifyGesture:
		var mg: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		var factor: float = clamp(mg.factor, 0.2, 5.0)
		_zoom_at(get_viewport().get_mouse_position(), factor)
		_update_hover_fill()
		return

	# === 패닝 시작/종료 ===
	if event is InputEventMouseButton:
		var btn: InputEventMouseButton = event as InputEventMouseButton
		var wanted_btn: int = _get_pan_button_index()
		var want_pan: bool = (btn.button_index == wanted_btn) \
			or (allow_spacebar_pan and btn.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE))

		if btn.pressed and want_pan and not _panning:
			_panning = true
			_active_pan_button = btn.button_index
			return
		elif (not btn.pressed) and _panning and btn.button_index == _active_pan_button:
			_panning = false
			_active_pan_button = -1
			return

	# === 클릭으로 타일 토글 ===
	if event is InputEventMouseButton:
		var btn: InputEventMouseButton = event as InputEventMouseButton
		if btn.pressed and btn.button_index == MOUSE_BUTTON_LEFT and not _panning:
			_handle_tile_click()
			return

	# === 패닝 중 이동 & Hover 갱신 ===
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _panning:
			position += mm.relative
			_schedule_save()  # 패닝시 저장 예약
		_update_hover_fill()
		return

func _get_pan_button_index() -> int:
	match pan_button:
		0:
			return MOUSE_BUTTON_LEFT
		1:
			return MOUSE_BUTTON_MIDDLE
		2:
			return MOUSE_BUTTON_RIGHT
	return MOUSE_BUTTON_MIDDLE

func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old_zoom: float = _zoom
	_zoom = clamp(_zoom * factor, min_zoom, max_zoom)
	var real_factor: float = _zoom / old_zoom
	if abs(real_factor - 1.0) < 1e-6:
		return

	# 마우스 포인터 아래 월드 포인트 고정
	var local_before: Vector2 = (screen_pos - position) / old_zoom
	position = screen_pos - local_before * _zoom
	_apply_zoom()
	_schedule_save()  # 줌 변경시 저장 예약

func _apply_zoom() -> void:
	scale = Vector2(_zoom, _zoom)
	if keep_pixel_line_width:
		_refresh_mesh()

func _refresh_mesh() -> void:
	var effective_width: float = line_width
	if keep_pixel_line_width:
		effective_width = pixel_line_px / max(_zoom, 0.0001)
	_mesh_instance.mesh = _build_all_border_mesh(effective_width)

func _build_all_border_mesh(width: float) -> ArrayMesh:
	# 1) 타일 사전(중복 경계 제거용)
	var tiles: Dictionary = {}
	for rr in range(-radius, radius + 1):
		var q_min: int = max(-radius, -rr - radius)
		var q_max: int = min(radius, -rr + radius)
		for qq in range(q_min, q_max + 1):
			tiles[Vector2i(qq, rr)] = true

	# 2) 6방향 축좌표 이웃
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]

	# 3) 버퍼
	var vertices: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var vi: int = 0

	# 4) 변 추가(이웃 있으면 한 번만)
	for rr2 in range(-radius, radius + 1):
		var q_min2: int = max(-radius, -rr2 - radius)
		var q_max2: int = min(radius, -rr2 + radius)
		for qq2 in range(q_min2, q_max2 + 1):
			var center: Vector2 = _axial_to_pixel(qq2, rr2, hex_size, pointy_top)
			var corners: Array[Vector2] = [
				center + _corner_off[0],
				center + _corner_off[1],
				center + _corner_off[2],
				center + _corner_off[3],
				center + _corner_off[4],
				center + _corner_off[5]
			]
			for i in range(6):
				var neighbor_q: int = qq2 + dirs[i].x
				var neighbor_r: int = rr2 + dirs[i].y
				var neighbor_exists: bool = tiles.has(Vector2i(neighbor_q, neighbor_r))
				if neighbor_exists:
					if (neighbor_q < qq2) or (neighbor_q == qq2 and neighbor_r < rr2):
						continue
				var p0: Vector2 = corners[i]
				var p1: Vector2 = corners[(i + 1) % 6]
				vi = _append_segment_quad(vertices, indices, vi, p0, p1, width)

	var mesh: ArrayMesh = ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _append_segment_quad(vertices: PackedVector2Array, indices: PackedInt32Array, vi: int, p0: Vector2, p1: Vector2, width: float) -> int:
	var d: Vector2 = p1 - p0
	var len_v: float = d.length()
	if len_v <= 0.00001:
		return vi
	var dir: Vector2 = d / len_v
	var n: Vector2 = Vector2(-dir.y, dir.x) * (width * 0.5)

	var v0: Vector2 = p0 + n
	var v1: Vector2 = p1 + n
	var v2: Vector2 = p1 - n
	var v3: Vector2 = p0 - n

	vertices.push_back(v0)
	vertices.push_back(v1)
	vertices.push_back(v2)
	vertices.push_back(v3)

	indices.push_back(vi + 0)
	indices.push_back(vi + 1)
	indices.push_back(vi + 2)
	indices.push_back(vi + 0)
	indices.push_back(vi + 2)
	indices.push_back(vi + 3)

	return vi + 4

# ---------- Hover tile 계산 & 표시 ----------
func _update_hover_fill() -> void:
	var mouse_screen: Vector2 = get_viewport().get_mouse_position()
	var local: Vector2 = to_local(mouse_screen)  # 줌/패닝 반영
	var af: Vector2 = _pixel_to_axial(local, hex_size, pointy_top) # fractional axial
	var at: Vector2i = _axial_round(af.x, af.y)                    # 정수 타일(q,r)

	var inside: bool = _axial_distance(at.x, at.y) <= radius
	if not inside and not show_hover_when_outside:
		_hover_poly.visible = false
		return

	if at != _hover_tile or not _hover_poly.visible:
		_hover_tile = at
		var center: Vector2 = _axial_to_pixel(at.x, at.y, hex_size, pointy_top)
		var poly: PackedVector2Array = PackedVector2Array()
		poly.resize(6)
		for i in range(6):
			poly[i] = center + _corner_off[i]
		_hover_poly.polygon = poly
		_hover_poly.visible = true

# ---------- 좌표 변환 유틸 ----------
func _corner_offsets(s: float, pointy: bool) -> Array[Vector2]:
	var offs: Array[Vector2] = []
	offs.resize(6)
	if pointy:
		for i in range(6):
			var ang: float = deg_to_rad(60.0 * i - 30.0)
			offs[i] = Vector2(cos(ang), sin(ang)) * s
	else:
		for i in range(6):
			var ang2: float = deg_to_rad(60.0 * i)
			offs[i] = Vector2(cos(ang2), sin(ang2)) * s
	return offs

func _axial_to_pixel(q: float, r: float, s: float, pointy: bool) -> Vector2:
	if pointy:
		return Vector2(
			s * (SQRT3 * q + (SQRT3 * 0.5) * r),
			s * (1.5 * r)
		)
	else:
		return Vector2(
			s * (1.5 * q),
			s * ((SQRT3 * 0.5) * q + SQRT3 * r)
		)

func _pixel_to_axial(p: Vector2, s: float, pointy: bool) -> Vector2:
	if pointy:
		var q: float = ((SQRT3 / 3.0) * p.x - (1.0 / 3.0) * p.y) / s
		var r: float = ((2.0 / 3.0) * p.y) / s
		return Vector2(q, r)
	else:
		var q2: float = ((2.0 / 3.0) * p.x) / s
		var r2: float = ((-1.0 / 3.0) * p.x + (1.0 / SQRT3) * p.y) / s
		return Vector2(q2, r2)

func _axial_round(qf: float, rf: float) -> Vector2i:
	var x: float = qf
	var z: float = rf
	var y: float = -x - z

	var rx: float = roundf(x)
	var ry: float = roundf(y)
	var rz: float = roundf(z)

	var x_diff: float = abs(rx - x)
	var y_diff: float = abs(ry - y)
	var z_diff: float = abs(rz - z)

	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry

	return Vector2i(int(rx), int(rz))

func _axial_distance(q: int, r: int) -> int:
	return int((abs(q) + abs(r) + abs(q + r)) / 2)

# ---------- 클릭 처리 ----------
func _handle_tile_click() -> void:
	var mouse_screen: Vector2 = get_viewport().get_mouse_position()
	var local: Vector2 = to_local(mouse_screen)
	var af: Vector2 = _pixel_to_axial(local, hex_size, pointy_top)
	var at: Vector2i = _axial_round(af.x, af.y)
	
	# 타일이 범위 내에 있는지 확인
	var inside: bool = _axial_distance(at.x, at.y) <= radius
	if not inside:
		return
	
	# 타일 토글
	_toggle_tile(at)

func _toggle_tile(tile: Vector2i) -> void:
	if _clicked_tiles.has(tile):
		# 이미 클릭된 타일 - 제거
		_clicked_tiles.erase(tile)
		if _clicked_polys.has(tile):
			var poly: Polygon2D = _clicked_polys[tile]
			poly.queue_free()
			_clicked_polys.erase(tile)
	else:
		# 새로 클릭된 타일 - 추가
		_clicked_tiles[tile] = true
		var poly: Polygon2D = Polygon2D.new()
		poly.color = click_fill_color
		poly.z_index = z_index_on_top + 1
		
		var center: Vector2 = _axial_to_pixel(tile.x, tile.y, hex_size, pointy_top)
		var corners: PackedVector2Array = PackedVector2Array()
		corners.resize(6)
		for i in range(6):
			corners[i] = center + _corner_off[i]
		poly.polygon = corners
		
		add_child(poly)
		_clicked_polys[tile] = poly

# ---------- 광물 배치 ----------
func _place_ores() -> void:
	if not ore_scene:
		print("광물 씬이 설정되지 않았습니다")
		return
	
	# 랜덤 시드 설정
	var rng = RandomNumberGenerator.new()
	rng.seed = ore_random_seed
	
	# 유효한 타일 목록 생성 (점유되지 않은 타일만)
	var valid_tiles: Array[Vector2i] = []
	for rr in range(-radius, radius + 1):
		var q_min: int = max(-radius, -rr - radius)
		var q_max: int = min(radius, -rr + radius)
		for qq in range(q_min, q_max + 1):
			var tile = Vector2i(qq, rr)
			if not _occupied_tiles.has(tile):
				valid_tiles.append(tile)
	
	# 균등 분산 알고리즘으로 광물 배치
	_ore_positions = _distribute_ores_evenly(valid_tiles, ore_count, min_ore_distance, rng)
	
	# 광물 인스턴스 생성
	for pos in _ore_positions:
		var ore_instance: Node2D = ore_scene.instantiate()
		var world_pos: Vector2 = _axial_to_pixel(pos.x, pos.y, hex_size, pointy_top)
		ore_instance.position = world_pos
		ore_instance.z_index = z_index_on_top + 3
		add_child(ore_instance)
		_ore_instances.append(ore_instance)
		
		# 점유된 타일로 마킹
		_occupied_tiles[pos] = true

func _distribute_ores_evenly(valid_tiles: Array[Vector2i], count: int, min_distance: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var selected: Array[Vector2i] = []
	var attempts: int = 0
	var max_attempts: int = count * 50  # 무한 루프 방지
	
	# 첫 번째 광물은 중심 근처에 배치
	if valid_tiles.size() > 0:
		var center_candidates: Array[Vector2i] = []
		for tile in valid_tiles:
			if _axial_distance(tile.x, tile.y) <= radius / 4:
				center_candidates.append(tile)
		
		if center_candidates.size() > 0:
			selected.append(center_candidates[rng.randi() % center_candidates.size()])
		else:
			selected.append(valid_tiles[rng.randi() % valid_tiles.size()])
	
	# 나머지 광물들을 균등하게 분산 배치
	while selected.size() < count and attempts < max_attempts:
		attempts += 1
		var candidate: Vector2i = valid_tiles[rng.randi() % valid_tiles.size()]
		
		# 최소 거리 확인
		var too_close: bool = false
		for existing in selected:
			if _axial_distance_between(candidate, existing) < min_distance:
				too_close = true
				break
		
		if not too_close:
			selected.append(candidate)
	
	print("광물 %d개 배치 완료 (%d번 시도)" % [selected.size(), attempts])
	return selected

func _axial_distance_between(a: Vector2i, b: Vector2i) -> int:
	return int((abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2)

# ---------- 행성 배치 ----------
func _place_planets() -> void:
	if not planet_scene:
		print("행성 씬이 설정되지 않았습니다")
		return
	
	# 랜덤 시드 설정
	var rng = RandomNumberGenerator.new()
	rng.seed = planet_random_seed
	
	# 유효한 타일 목록 생성
	var valid_tiles: Array[Vector2i] = []
	for rr in range(-radius, radius + 1):
		var q_min: int = max(-radius, -rr - radius)
		var q_max: int = min(radius, -rr + radius)
		for qq in range(q_min, q_max + 1):
			valid_tiles.append(Vector2i(qq, rr))
	
	# 행성 배치
	_planet_positions = _distribute_planets_evenly(valid_tiles, planet_count, min_planet_distance, rng)
	
	# 행성 색상 목록
	var planet_colors = [
		{"main": Color(0.8, 0.3, 0.2), "surface": Color(0.9, 0.5, 0.3), "atmosphere": Color(1.0, 0.6, 0.4, 0.3)},  # 화성
		{"main": Color(0.2, 0.4, 0.8), "surface": Color(0.3, 0.6, 0.9), "atmosphere": Color(0.5, 0.8, 1.0, 0.3)},  # 지구
		{"main": Color(0.6, 0.4, 0.2), "surface": Color(0.7, 0.5, 0.3), "atmosphere": Color(0.8, 0.6, 0.4, 0.3)},  # 사막
		{"main": Color(0.3, 0.7, 0.3), "surface": Color(0.4, 0.8, 0.4), "atmosphere": Color(0.6, 1.0, 0.6, 0.3)},  # 숲
		{"main": Color(0.5, 0.3, 0.7), "surface": Color(0.6, 0.4, 0.8), "atmosphere": Color(0.7, 0.5, 0.9, 0.3)},  # 신비
		{"main": Color(0.7, 0.7, 0.3), "surface": Color(0.8, 0.8, 0.4), "atmosphere": Color(0.9, 0.9, 0.5, 0.3)},  # 가스
	]
	
	# 행성 이름 목록
	var planet_names = [
		"Proxima", "Kepler", "Gliese", "Trappist", "Wolf", "Ross", "Tau", "HD",
		"K2", "WASP", "CoRoT", "Upsilon", "Mu", "Epsilon", "Zeta", "Alpha",
		"Beta", "Gamma", "Delta", "Theta", "Lambda", "Sigma", "Omega", "Nova",
		"Stellar", "Cosmic", "Nebula", "Aurora", "Solaris", "Vega", "Altair",
		"Sirius", "Rigel", "Betelgeuse", "Arcturus", "Aldebaran", "Spica", "Antares",
		"Pollux", "Regulus", "Adhara", "Castor", "Gacrux", "Bellatrix", "Elnath",
		"Miaplacidus", "Alnilam", "Alnair", "Alioth", "Dubhe", "Mirfak",
		"Wezen", "Sargas", "Kaus", "Avior", "Alkaid", "Menkalinan", "Atria",
		"Alhena", "Peacock", "Alsephina", "Mirzam", "Polaris", "Alphard",
		"Hamal", "Diphda", "Nunki", "Menkent", "Mirach", "Alpheratz", "Rasalhague",
		"Kochab", "Saiph", "Deneb", "Algol", "Tiaki", "Muhlifain", "Aspidiske",
		"Suhail", "Alphecca", "Mintaka", "Sadr", "Eltanin", "Schedar", "Naos",
		"Almach", "Caph", "Izar", "Dschubba", "Larawag", "Merak", "Ankaa",
		"Girtab", "Enif", "Scheat", "Sabik", "Phecda", "Aludra", "Markeb",
		"Navi", "Markab", "Aljanah", "Acrab"
	]
	
	# 행성 인스턴스 생성
	for i in range(_planet_positions.size()):
		var pos = _planet_positions[i]
		var planet_instance: Node2D = planet_scene.instantiate()
		var world_pos: Vector2 = _axial_to_pixel(pos.x, pos.y, hex_size, pointy_top)
		planet_instance.position = world_pos
		planet_instance.z_index = -10  # 타일맵 그리드보다 아래에 그리기
		
		# 행성 반경 설정 (1-5 랜덤)
		var planet_radius = rng.randi_range(1, 5)
		planet_instance.planet_radius = planet_radius
		
		# 행성 색상 설정 (랜덤)
		var color_set = planet_colors[rng.randi() % planet_colors.size()]
		planet_instance.planet_color = color_set.main
		planet_instance.surface_color = color_set.surface
		planet_instance.atmosphere_color = color_set.atmosphere
		
		# 헥스 크기 설정
		planet_instance.set_hex_size(hex_size)
		
		# 행성 이름 설정 (랜덤)
		var planet_name = planet_names[rng.randi() % planet_names.size()]
		planet_instance.set_planet_name(planet_name)
		
		add_child(planet_instance)
		_planet_instances.append(planet_instance)
		
		# 행성이 점유하는 모든 타일 마킹
		for occupied_tile in _get_planet_occupied_tiles(pos, planet_radius):
			_occupied_tiles[occupied_tile] = true
		
		# 행성 자원 UI 초기화
		planet_instance.set_resource_count(0)
		
		# 격납고 배치 (행성 타일 중 랜덤 선택)
		planet_instance.place_hangar_randomly(pos)
		
		# 행성 셀 시각적 표시
		if show_planet_cells:
			_create_planet_cell_display(pos, planet_radius)

func _distribute_planets_evenly(valid_tiles: Array[Vector2i], count: int, min_distance: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var selected: Array[Vector2i] = []
	var attempts: int = 0
	var max_attempts: int = count * 100
	
	while selected.size() < count and attempts < max_attempts:
		attempts += 1
		var candidate: Vector2i = valid_tiles[rng.randi() % valid_tiles.size()]
		
		# 다른 행성들과의 최소 거리 확인
		var too_close: bool = false
		for existing in selected:
			if _axial_distance_between(candidate, existing) < min_distance:
				too_close = true
				break
		
		if not too_close:
			selected.append(candidate)
	
	print("행성 %d개 배치 완료 (%d번 시도)" % [selected.size(), attempts])
	return selected

func _create_planet_cell_display(planet_center: Vector2i, planet_radius: int):
	"""행성에 속한 셀들을 시각적으로 구분하여 표시"""
	var occupied_tiles = _get_planet_occupied_tiles(planet_center, planet_radius)
	
	for tile in occupied_tiles:
		# 각 타일에 대한 폴리곤 생성
		var poly = Polygon2D.new()
		poly.color = planet_cell_fill_color
		poly.z_index = -5  # 행성보다는 위에, 그리드보다는 아래에
		
		# 헥스 타일 모양 생성
		var center = _axial_to_pixel(tile.x, tile.y, hex_size, pointy_top)
		var corners = PackedVector2Array()
		corners.resize(6)
		for i in range(6):
			corners[i] = center + _corner_off[i]
		poly.polygon = corners
		
		# 테두리 추가
		var line = Line2D.new()
		line.default_color = planet_cell_line_color
		line.width = 2.0
		line.z_index = -4
		line.closed = true
		for corner in corners:
			line.add_point(corner)
		
		add_child(poly)
		add_child(line)
		_planet_cell_polys.append(poly)
		_planet_cell_polys.append(line)

func _get_planet_occupied_tiles(center: Vector2i, planet_radius: int) -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	for rr in range(-planet_radius, planet_radius + 1):
		for qq in range(-planet_radius, planet_radius + 1):
			var tile = center + Vector2i(qq, rr)
			var hex_distance = int((abs(qq) + abs(rr) + abs(qq + rr)) / 2)
			if hex_distance <= planet_radius:
				occupied.append(tile)
	return occupied

# ---------- 우주선 배치 ----------
func _place_frigates() -> void:
	if not frigate_scene:
		print("우주선 씬이 설정되지 않았습니다")
		return
	
	for i in range(_planet_positions.size()):
		var planet_pos = _planet_positions[i]
		var planet_instance = _planet_instances[i]
		
		# 격납고 위치에서 우주선 생성 (절대 좌표 사용)
		var frigate_pos = planet_instance.get_hangar_position()
		
		# 우주선 인스턴스 생성
		var frigate_instance: Node2D = frigate_scene.instantiate()
		var world_pos: Vector2 = _axial_to_pixel(frigate_pos.x, frigate_pos.y, hex_size, pointy_top)
		frigate_instance.position = world_pos
		frigate_instance.z_index = z_index_on_top + 4  # 행성보다 위에
		
		# 우주선 설정
		frigate_instance.set_hex_size(hex_size)
		frigate_instance.set_home_planet(planet_pos)
		frigate_instance.set_home_hangar(frigate_pos)
		frigate_instance.set_hex_grid(self)
		
		# 신호 연결
		frigate_instance.turn_action_completed.connect(_on_frigate_turn_completed)
		frigate_instance.ore_collected.connect(_on_ore_collected)
		frigate_instance.ore_deposited.connect(_on_ore_deposited)
		frigate_instance.frigate_moved.connect(_on_frigate_moved)
		frigate_instance.mining_started.connect(_on_mining_started)
		frigate_instance.mining_stopped.connect(_on_mining_stopped)
		
		add_child(frigate_instance)
		_frigate_instances.append(frigate_instance)
		
		# 우주선 위치 등록
		_frigate_positions[frigate_pos] = frigate_instance
		
		# 행성 자원 초기화
		_planet_resources[planet_pos] = 0

func _get_planet_edge_tiles(center: Vector2i, planet_radius: int) -> Array[Vector2i]:
	var edge_tiles: Array[Vector2i] = []
	
	# 행성 반경의 테두리 타일들 찾기
	for rr in range(-planet_radius, planet_radius + 1):
		for qq in range(-planet_radius, planet_radius + 1):
			var tile = center + Vector2i(qq, rr)
			var hex_distance = int((abs(qq) + abs(rr) + abs(qq + rr)) / 2)
			
			# 정확히 반경 거리에 있는 타일만
			if hex_distance == planet_radius:
				edge_tiles.append(tile)
	
	return edge_tiles

# ---------- 턴 시스템 ----------
func _process_turn() -> void:
	_current_turn += 1
	_frigates_ready = 0
	
	# 모든 우주선의 턴 처리 시작
	for frigate in _frigate_instances:
		frigate.process_turn()
	
	print("턴 %d 시작 - 우주선 %d대 작업 중" % [_current_turn, _frigate_instances.size()])

func _on_frigate_turn_completed() -> void:
	_frigates_ready += 1
	
	# 모든 우주선이 턴을 완료하면 다음 턴 준비
	if _frigates_ready >= _frigate_instances.size():
		if auto_play:
			_turn_timer.start()

func _on_ore_collected(frigate: Node2D, ore_pos: Vector2i) -> void:
	# 광물 제거
	var ore_index = _ore_positions.find(ore_pos)
	if ore_index >= 0:
		_ore_positions.remove_at(ore_index)
		var ore_instance = _ore_instances[ore_index]
		ore_instance.queue_free()
		_ore_instances.remove_at(ore_index)
		
		# 점유 타일에서도 제거
		_occupied_tiles.erase(ore_pos)
		
		print("광물 채집됨: %s" % ore_pos)

func _on_ore_deposited(frigate: Node2D, planet_pos: Vector2i, amount: int) -> void:
	# 행성에 자원 추가
	if _planet_resources.has(planet_pos):
		_planet_resources[planet_pos] += amount
	else:
		_planet_resources[planet_pos] = amount
	
	# 행성 UI 업데이트
	var planet_index = _planet_positions.find(planet_pos)
	if planet_index >= 0:
		var planet_instance = _planet_instances[planet_index]
		planet_instance.set_resource_count(_planet_resources[planet_pos])
	
	print("행성 %s에 광물 %d개 저장됨 (총 %d개)" % [planet_pos, amount, _planet_resources[planet_pos]])

func _on_frigate_moved(frigate: Node2D, old_pos: Vector2i, new_pos: Vector2i) -> void:
	# 우주선 위치 업데이트
	_frigate_positions.erase(old_pos)
	_frigate_positions[new_pos] = frigate

func _on_mining_started(frigate: Node2D, tile: Vector2i) -> void:
	# 채집 중인 타일 등록
	_mining_tiles[tile] = frigate

func _on_mining_stopped(frigate: Node2D, tile: Vector2i) -> void:
	# 채집 중인 타일 해제
	_mining_tiles.erase(tile)

# 우주선이 특정 타일로 이동할 수 있는지 확인
func can_frigate_move_to(tile: Vector2i, requesting_frigate: Node2D = null) -> bool:
	# 다른 우주선이 점유 중인지 확인
	if _frigate_positions.has(tile):
		var occupying_frigate = _frigate_positions[tile]
		if occupying_frigate != requesting_frigate:
			return false
	
	# 광물이나 행성이 점유 중인지 확인 (둘 다 이동 가능)
	if _occupied_tiles.has(tile):
		# 광물인 경우 이동 가능 (같은 타일에서 채집)
		if _ore_positions.has(tile):
			return true
		# 행성인 경우도 이동 가능 (겹침 허용)
		for planet_pos in _planet_positions:
			if _is_tile_in_planet(tile, planet_pos):
				return true
		return false
	
	return true

# 특정 타일이 행성 영역 내에 있는지 확인
func _is_tile_in_planet(tile: Vector2i, planet_center: Vector2i) -> bool:
	var planet_index = _planet_positions.find(planet_center)
	if planet_index >= 0:
		var planet_instance = _planet_instances[planet_index]
		var planet_radius = planet_instance.planet_radius
		var distance = _axial_distance_between(tile, planet_center)
		return distance <= planet_radius
	return false

# 특정 광물이 채집 중인지 확인
func is_ore_being_mined(ore_pos: Vector2i) -> bool:
	return _mining_tiles.has(ore_pos)

# 사용 가능한 광물 목록 반환 (채집 중이 아닌 것들)
func get_available_ore_positions() -> Array[Vector2i]:
	var available: Array[Vector2i] = []
	for ore_pos in _ore_positions:
		if not is_ore_being_mined(ore_pos):
			available.append(ore_pos)
	return available

# ---------- 뷰포트 상태 저장/로드 ----------
func _save_viewport_state() -> void:
	if not save_viewport_state:
		return
		
	var config = ConfigFile.new()
	config.set_value("viewport", "zoom", _zoom)
	config.set_value("viewport", "position_x", position.x)
	config.set_value("viewport", "position_y", position.y)
	
	var error = config.save(_config_file_path)
	if error == OK:
		print("뷰포트 상태가 저장되었습니다: 줌=%.2f, 위치=(%.1f, %.1f)" % [_zoom, position.x, position.y])
	else:
		print("뷰포트 상태 저장 실패: ", error)

func _load_viewport_state() -> void:
	if not save_viewport_state:
		return
		
	var config = ConfigFile.new()
	var error = config.load(_config_file_path)
	
	if error != OK:
		print("저장된 뷰포트 상태가 없습니다")
		return
	
	# 저장된 줌과 위치 복원
	var saved_zoom = config.get_value("viewport", "zoom", 1.0)
	var saved_pos_x = config.get_value("viewport", "position_x", position.x)
	var saved_pos_y = config.get_value("viewport", "position_y", position.y)
	
	_zoom = clamp(saved_zoom, min_zoom, max_zoom)
	position = Vector2(saved_pos_x, saved_pos_y)
	_apply_zoom()
	
	print("뷰포트 상태가 복원되었습니다: 줌=%.2f, 위치=(%.1f, %.1f)" % [_zoom, position.x, position.y])

func _schedule_save() -> void:
	if not save_viewport_state or not _save_timer:
		return
	_save_timer.start()  # 타이머 재시작 (1초 후 저장)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_viewport_state()
