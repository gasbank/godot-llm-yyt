@tool
extends Node2D

enum HexOrientation { POINTY, FLAT }

@export var orientation: HexOrientation = HexOrientation.POINTY
@export var hex_size: float = 32.0            # 한 변 기준 반경
@export var grid_origin: Vector2 = Vector2.ZERO
@export var debug_draw: bool = true
@export var debug_radius: int = 5             # 그릴 반경(헥스 거리)

const SQRT3 := 1.7320508075688772

# ─────────────────────────────────────────────────────────────
# 좌표 변환
# ─────────────────────────────────────────────────────────────

func axial_to_world(q: int, r: int) -> Vector2:
	var x: float
	var y: float
	if orientation == HexOrientation.POINTY:
		# pointy-top (세로로 긴 육각)
		x = hex_size * SQRT3 * (q + r * 0.5)
		y = hex_size * 1.5 * r
	else:
		# flat-top (가로로 긴 육각)
		x = hex_size * 1.5 * q
		y = hex_size * SQRT3 * (r + q * 0.5)
	return grid_origin + Vector2(x, y)

func world_to_axial(pos: Vector2) -> Vector2i:
	var p := pos - grid_origin
	var qf: float
	var rf: float
	if orientation == HexOrientation.POINTY:
		qf = (SQRT3/3.0 * p.x - 1.0/3.0 * p.y) / hex_size
		rf = (2.0/3.0 * p.y) / hex_size
	else:
		qf = (2.0/3.0 * p.x) / hex_size
		rf = (-1.0/3.0 * p.x + SQRT3/3.0 * p.y) / hex_size
	var cube := cube_round(Vector3(qf, -qf - rf, rf))
	return Vector2i(cube.x, cube.z) # (q,r)

# ─────────────────────────────────────────────────────────────
# 큐브 좌표 유틸
# ─────────────────────────────────────────────────────────────

static func axial_to_cube(q: int, r: int) -> Vector3i:
	return Vector3i(q, -q - r, r)

static func cube_to_axial(c: Vector3i) -> Vector2i:
	return Vector2i(c.x, c.z)

static func cube_round(c: Vector3) -> Vector3i:
	var rx := roundi(c.x)
	var ry := roundi(c.y)
	var rz := roundi(c.z)
	var dx := absf(rx - c.x)
	var dy := absf(ry - c.y)
	var dz := absf(rz - c.z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector3i(rx, ry, rz)

# ─────────────────────────────────────────────────────────────
# 방향/이웃/거리
# ─────────────────────────────────────────────────────────────

# axial 기준 6방향(orientation과 무관)
const DIRS := [
			  Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
			  Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
			  ]

static func neighbors(a: Vector2i) -> Array[Vector2i]:
	var n: Array[Vector2i] = []
	for d in DIRS:
		n.append(a + d)
	return n

static func distance(a: Vector2i, b: Vector2i) -> int:
	var ac := axial_to_cube(a.x, a.y)
	var bc := axial_to_cube(b.x, b.y)
	return int((abs(ac.x - bc.x) + abs(ac.y - bc.y) + abs(ac.z - bc.z)) / 2)

# ─────────────────────────────────────────────────────────────
# 링/스파이럴(반경 r)
# ─────────────────────────────────────────────────────────────

static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if radius <= 0:
		return result
	# 시작점: center에서 DIRS[4]로 radius만큼 이동
	var hex := center + DIRS[4] * radius
	for side in range(6):
		for i in range(radius):
			result.append(hex)
			hex += DIRS[side]
	return result

static func spiral(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [center]
	for r in range(1, radius + 1):
		out.append_array(ring(center, r))
	return out

# ─────────────────────────────────────────────────────────────
# 헥스 코너(6각형 점 좌표)
# ─────────────────────────────────────────────────────────────

func hex_corners(center: Vector2) -> PackedVector2Array:
	var corners := PackedVector2Array()
	var angle_offset := 30.0 if orientation == HexOrientation.POINTY else 0.0
	for i in range(6):
		var ang := deg_to_rad(angle_offset + 60.0 * i)
		corners.append(center + Vector2(cos(ang), sin(ang)) * hex_size)
	return corners

# ─────────────────────────────────────────────────────────────
# 디버그 드로잉
# ─────────────────────────────────────────────────────────────

func _draw() -> void:
	if not debug_draw: return
	# 중심(0,0)에서 반경 debug_radius 스파이럴을 그림
	for a in spiral(Vector2i(0, 0), debug_radius):
		var c := axial_to_world(a.x, a.y)
		var pts := hex_corners(c)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.2, 0.9, 1.0, 0.75), 1.5)
		# 좌표 텍스트
		
		#draw_string(ThemeDB.fallback_font, c + Vector2(-10, 4), "%d,%d" % [a.x, a.y], HAlign.CENTER, -1, 10, Color.WHITE)

func _notification(what):
	#if what == NOTIFICATION_EDITOR_SETTINGS_CHANGED or what == NOTIFICATION_TRANSFORM_CHANGED:
	#	queue_redraw()
	pass
