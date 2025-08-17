# HexTileAllBorders.gd
extends Node2D
## 반경 R 헥스맵의 "모든" 경계선을 하나의 Mesh로 생성해 표시
## 마우스 휠/핀치 줌 + 드래그 패닝 지원 (Godot 4.x)

@export var radius: int = 200            # 헥스 반경 (축좌표 거리 ≤ R)
@export var hex_size: float = 10.0       # 헥스 반지름(센터→꼭짓점 픽셀)
@export var pointy_top: bool = true      # true: pointy-top / false: flat-top
@export var line_width: float = 2.0      # 경계선 굵기(월드 좌표 기준)
@export var line_color: Color = Color.BLACK
@export var center_in_viewport: bool = true
@export var z_index_on_top: int = 1000

# === 줌 설정 ===
@export var zoom_step: float = 1.1       # 휠 한 클릭당 배율
@export var min_zoom: float = 0.2
@export var max_zoom: float = 8.0
@export var keep_pixel_line_width: bool = false  # true면 선 두께를 화면 픽셀 기준으로 고정
@export var pixel_line_px: float = 2.0           # keep_pixel_line_width=true일 때 목표 화면 픽셀 두께

# === 패닝 설정 ===
@export_enum("Left", "Middle", "Right") var pan_button: int = 1   # 기본 Middle
@export var allow_spacebar_pan: bool = true   # Space + Left 로도 패닝 허용

const SQRT3 := 1.7320508075688772

var _mesh_instance: MeshInstance2D
var _zoom: float = 1.0

var _panning := false
var _active_pan_button := -1
var _drag_last: Vector2

func _ready() -> void:
	if center_in_viewport:
		position = Vector2(get_viewport_rect().size) * 0.5

	_mesh_instance = MeshInstance2D.new()
	_mesh_instance.z_index = z_index_on_top
	_mesh_instance.modulate = line_color
	add_child(_mesh_instance)

	_refresh_mesh()
	_apply_zoom()

func _unhandled_input(event: InputEvent) -> void:
	# === 줌 ===
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(get_viewport().get_mouse_position(), zoom_step)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(get_viewport().get_mouse_position(), 1.0 / zoom_step)
			return
	elif event is InputEventMagnifyGesture:
		# macOS 트랙패드 핀치
		_zoom_at(get_viewport().get_mouse_position(), clamp(event.factor, 0.2, 5.0))
		return

	# === 패닝 시작/종료 ===
	if event is InputEventMouseButton:
		var wanted_btn := _get_pan_button_index()
		var want_pan : bool = (event.button_index == wanted_btn) \
			or (allow_spacebar_pan and event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE))

		if event.pressed and want_pan and not _panning:
			_panning = true
			_active_pan_button = event.button_index
			_drag_last = event.position
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # 편의상 커서는 그대로
			return
		elif (not event.pressed) and _panning and event.button_index == _active_pan_button:
			_panning = false
			_active_pan_button = -1
			return

	# === 패닝 중 이동 ===
	if event is InputEventMouseMotion and _panning:
		# 화면(뷰포트) 좌표 기준으로 이동 → 스케일과 무관하게 자연스러운 패닝
		position += event.relative
		return

func _get_pan_button_index() -> int:
	match pan_button: # export_enum 인덱스(Left=0, Middle=1, Right=2)
		0: return MOUSE_BUTTON_LEFT
		1: return MOUSE_BUTTON_MIDDLE
		2: return MOUSE_BUTTON_RIGHT
	return MOUSE_BUTTON_MIDDLE

func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old_zoom := _zoom
	_zoom = clamp(_zoom * factor, min_zoom, max_zoom)
	var real_factor := _zoom / old_zoom
	if abs(real_factor - 1.0) < 1e-6:
		return

	# 마우스 포인터 아래 월드 포인트 고정
	var local_before := (screen_pos - position) / old_zoom
	position = screen_pos - local_before * _zoom
	_apply_zoom()

func _apply_zoom() -> void:
	scale = Vector2(_zoom, _zoom)
	if keep_pixel_line_width:
		_refresh_mesh()

func _refresh_mesh() -> void:
	var effective_width := line_width
	if keep_pixel_line_width:
		effective_width = pixel_line_px / max(_zoom, 0.0001)
	_mesh_instance.mesh = _build_all_border_mesh(effective_width)

func _build_all_border_mesh(width: float) -> ArrayMesh:
	# 1) 반경 R 내부의 모든 타일 좌표 수집
	var tiles := {}
	for rr in range(-radius, radius + 1):
		var q_min : float = max(-radius, -rr - radius)
		var q_max : float = min(radius, -rr + radius)
		for qq in range(q_min, q_max + 1):
			tiles[Vector2i(qq, rr)] = true

	# 2) 코너 오프셋(6개)
	var corner_off := _corner_offsets(hex_size, pointy_top)

	# 3) 6방향 축좌표 이웃
	var dirs := [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]

	# 4) 정점/인덱스 버퍼
	var vertices := PackedVector2Array()
	var indices := PackedInt32Array()
	var vi := 0

	# 5) 타일 순회하며 변 추가(이웃이 있으면 사전식으로 한쪽만 추가)
	for rr in range(-radius, radius + 1):
		var q_min : int = max(-radius, -rr - radius)
		var q_max : int = min(radius, -rr + radius)
		for qq in range(q_min, q_max + 1):
			var center := _axial_to_pixel(qq, rr, hex_size, pointy_top)
			var corners := [
				center + corner_off[0],
				center + corner_off[1],
				center + corner_off[2],
				center + corner_off[3],
				center + corner_off[4],
				center + corner_off[5]
			]
			for i in range(6):
				var nq : int = qq + dirs[i].x
				var nr : int = rr + dirs[i].y
				var neighbor_exists := tiles.has(Vector2i(nq, nr))
				if neighbor_exists:
					if (nq < qq) or (nq == qq and nr < rr):
						continue
				var p0 : Vector2 = corners[i]
				var p1 : Vector2 = corners[(i + 1) % 6]
				vi = _append_segment_quad(vertices, indices, vi, p0, p1, width)

	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vertices
	arr[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _append_segment_quad(vertices: PackedVector2Array, indices: PackedInt32Array, vi: int, p0: Vector2, p1: Vector2, width: float) -> int:
	var d := p1 - p0
	var len := d.length()
	if len <= 0.00001:
		return vi
	var dir := d / len
	var n := Vector2(-dir.y, dir.x) * (width * 0.5)

	# 사각형 정점(두 삼각형)
	var v0 := p0 + n
	var v1 := p1 + n
	var v2 := p1 - n
	var v3 := p0 - n

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

func _corner_offsets(s: float, pointy: bool) -> Array:
	var offs := []
	offs.resize(6)
	if pointy:
		for i in range(6):
			var ang := deg_to_rad(60.0 * i - 30.0)
			offs[i] = Vector2(cos(ang), sin(ang)) * s
	else:
		for i in range(6):
			var ang := deg_to_rad(60.0 * i)
			offs[i] = Vector2(cos(ang), sin(ang)) * s
	return offs

func _axial_to_pixel(q: float, r: float, s: float, pointy: bool) -> Vector2:
	if pointy:
		# pointy-top
		return Vector2(
			s * (SQRT3 * q + (SQRT3 * 0.5) * r),
			s * (1.5 * r)
		)
	else:
		# flat-top
		return Vector2(
			s * (1.5 * q),
			s * ((SQRT3 * 0.5) * q + SQRT3 * r)
		)
