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

# === 광물 배치 설정 ===
@export var ore_count: int = 100                                  # 배치할 광물 개수
@export var min_ore_distance: int = 3                             # 광물 간 최소 거리
@export var ore_random_seed: int = 1985                           # 광물 배치 랜덤 시드
@export var ore_scene: PackedScene = preload("res://ore.tscn")    # 광물 씬

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

	_apply_zoom()
	_update_hover_fill()
	
	# 광물 배치
	_place_ores()
	
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
	
	# 유효한 타일 목록 생성
	var valid_tiles: Array[Vector2i] = []
	for rr in range(-radius, radius + 1):
		var q_min: int = max(-radius, -rr - radius)
		var q_max: int = min(radius, -rr + radius)
		for qq in range(q_min, q_max + 1):
			valid_tiles.append(Vector2i(qq, rr))
	
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
