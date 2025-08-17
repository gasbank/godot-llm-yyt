# HexTileAllBorders.gd
extends Node2D
## 반경 R 헥스맵의 "모든" 경계선을 하나의 Mesh로 생성해 표시합니다.

@export var radius: int = 200            # 헥스 반경 (축좌표 거리 ≤ R)
@export var hex_size: float = 10.0        # 헥스 반지름(센터→꼭짓점 픽셀)
@export var pointy_top: bool = true       # true: 꼭짓점 위(pointy) / false: 평평 위(flat)
@export var line_width: float = 2.0       # 경계선 굵기(픽셀)
@export var line_color: Color = Color.BLACK
@export var center_in_viewport: bool = true
@export var z_index_on_top: int = 1000

const SQRT3 := 1.7320508075688772

func _ready() -> void:
	# 눈에 잘 보이도록 화면 중앙 배치(선택)
	if center_in_viewport:
		position = Vector2(get_viewport_rect().size) * 0.5

	# 메쉬를 담을 인스턴스
	var mi := MeshInstance2D.new()
	mi.z_index = z_index_on_top
	mi.modulate = line_color
	add_child(mi)

	# 모든 경계선(중복 제거) → 삼각형 메쉬로 빌드
	var mesh := _build_all_border_mesh()
	mi.mesh = mesh


func _build_all_border_mesh() -> ArrayMesh:
	# 1) 반경 R 내부의 모든 타일 좌표 수집
	var tiles := {} # Dictionary: key=Vector2i(q,r), value=true
	for r in range(-radius, radius + 1):
		var q_min := maxi(-radius, -r - radius)
		var q_max := mini(radius, -r + radius)
		for q in range(q_min, q_max + 1):
			tiles[Vector2i(q, r)] = true

	# 2) 코너 오프셋(6개) 미리 계산
	var corner_off := _corner_offsets(hex_size, pointy_top)

	# 3) 6방향 축좌표 이웃 (Red Blob 표준)
	var dirs := [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]

	# 4) 정점/인덱스 버퍼
	var vertices := PackedVector2Array()
	var indices := PackedInt32Array()
	#vertices.reserve(1000000) # 대략적 예약(큰 반경일 때 성능에 도움)
	#indices.reserve(1500000)

	var vi := 0 # 현재 정점 인덱스

	# 5) 타일 순회하면서 각 변(6개)을 추가.
	#    이웃 타일이 있으면 "한쪽만" 추가(사전식 비교로 중복 제거)
	for r in range(-radius, radius + 1):
		var q_min := maxi(-radius, -r - radius)
		var q_max := mini(radius, -r + radius)
		for q in range(q_min, q_max + 1):
			var center := _axial_to_pixel(q, r, hex_size, pointy_top)

			# 이 타일의 6개 꼭짓점 좌표
			var corners := [
				center + corner_off[0],
				center + corner_off[1],
				center + corner_off[2],
				center + corner_off[3],
				center + corner_off[4],
				center + corner_off[5],
			]

			for i in range(6):
				var nq : float = q + dirs[i].x
				var nr : float = r + dirs[i].y
				var neighbor_exists := tiles.has(Vector2i(nq, nr))

				# 내부 공유 경계선은 한 번만 추가: (q,r) < (nq,nr)일 때만
				# 바깥 경계선(이웃 없음)은 무조건 추가
				if neighbor_exists:
					if (nq < q) or (nq == q and nr < r):
						continue # 이미 이웃 쪽에서 처리됨
				# 변 i의 양 끝점 (i→i+1)
				var p0 : Vector2 = corners[i]
				var p1 : Vector2 = corners[(i + 1) % 6]
				vi = _append_segment_quad(vertices, indices, vi, p0, p1, line_width)

	# 6) ArrayMesh로 묶기 (PRIMITIVE_TRIANGLES)
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

	# 사각형 정점 (시계/반시계 일관 유지)
	var v0 := p0 + n
	var v1 := p1 + n
	var v2 := p1 - n
	var v3 := p0 - n

	vertices.push_back(v0)
	vertices.push_back(v1)
	vertices.push_back(v2)
	vertices.push_back(v3)

	# 두 삼각형 인덱스
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
		# 각도: 30°, 90°, 150°, 210°, 270°, 330°  (i*60 - 30)
		for i in range(6):
			var ang := deg_to_rad(60.0 * i - 30.0)
			offs[i] = Vector2(cos(ang), sin(ang)) * s
	else:
		# 각도: 0°, 60°, 120°, 180°, 240°, 300°
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
