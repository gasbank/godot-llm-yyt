# Frigate.gd
extends Node2D

enum State { IDLE, MOVING_TO_ORE, MINING, MOVING_TO_PLANET, DEPOSITING, RETURNING_HOME }

var hex_size: float = 10.0
var home_planet_pos: Vector2i  # 소속 행성 위치
var current_tile: Vector2i     # 현재 타일 위치
var target_tile: Vector2i      # 목표 타일 위치
var path: Array[Vector2i] = [] # 이동 경로
var carried_ore: int = 0       # 보유 광물 개수
var max_capacity: int = 1      # 최대 적재량

var state: State = State.IDLE
var hex_grid: Node2D          # HexTileAllBorders 참조

# 신호
signal turn_action_completed  # 턴 액션 완료 신호
signal ore_collected(frigate, ore_pos)
signal ore_deposited(frigate, planet_pos, amount)
signal frigate_moved(frigate, old_pos, new_pos)
signal mining_started(frigate, tile)
signal mining_stopped(frigate, tile)

func _ready():
	_create_frigate_visuals()

func set_hex_size(size: float):
	hex_size = size
	if is_inside_tree():
		_create_frigate_visuals()

func set_home_planet(planet_pos: Vector2i):
	home_planet_pos = planet_pos
	current_tile = planet_pos

func set_hex_grid(grid: Node2D):
	hex_grid = grid

func _create_frigate_visuals():
	# 기존 자식 노드들 제거
	for child in get_children():
		child.queue_free()
	
	# 우주선 본체 (삼각형 모양)
	var hull = Polygon2D.new()
	hull.color = Color(0.7, 0.7, 0.8)
	var hull_points = PackedVector2Array([
		Vector2(0, -4),     # 앞
		Vector2(-2, 3),     # 왼쪽 뒤
		Vector2(2, 3)       # 오른쪽 뒤
	])
	hull.polygon = hull_points
	hull.z_index = 0
	add_child(hull)
	
	# 엔진 (뒤쪽 파란 점)
	var engine = Polygon2D.new()
	engine.color = Color(0.3, 0.7, 1.0)
	var engine_points = PackedVector2Array([
		Vector2(-1, 2),
		Vector2(1, 2),
		Vector2(0, 4)
	])
	engine.polygon = engine_points
	engine.z_index = 1
	add_child(engine)
	
	# 조종석 (앞쪽 밝은 점)
	var cockpit = Polygon2D.new()
	cockpit.color = Color(1.0, 1.0, 0.8)
	var cockpit_points = PackedVector2Array([
		Vector2(-0.5, -2),
		Vector2(0.5, -2),
		Vector2(0, -3)
	])
	cockpit.polygon = cockpit_points
	cockpit.z_index = 2
	add_child(cockpit)
	
	# 광물 보유 상태 표시
	_create_cargo_indicator()

func _create_cargo_indicator():
	# 광물 보유 상태에 따른 시각적 표시
	if carried_ore > 0:
		# 광물 보유 중 - 밝은 청록색 저장고
		var cargo = Polygon2D.new()
		cargo.color = Color(0.2, 0.8, 1.0, 0.9)  # 밝은 청록색
		var cargo_points = PackedVector2Array([
			Vector2(-1.5, -0.5),
			Vector2(1.5, -0.5),
			Vector2(1.5, 1.5),
			Vector2(-1.5, 1.5)
		])
		cargo.polygon = cargo_points
		cargo.z_index = 1
		add_child(cargo)
		
		# 광물 보유 표시 아이콘 (작은 다이아몬드)
		var ore_icon = Polygon2D.new()
		ore_icon.color = Color(0.4, 0.8, 1.0, 1.0)  # 광물 색상
		var icon_points = PackedVector2Array([
			Vector2(0, -1),     # 위
			Vector2(1, 0),      # 오른쪽
			Vector2(0, 1),      # 아래
			Vector2(-1, 0)      # 왼쪽
		])
		ore_icon.polygon = icon_points
		ore_icon.z_index = 3
		add_child(ore_icon)
		
		# 빛나는 효과 (테두리)
		var glow = Polygon2D.new()
		glow.color = Color(1.0, 1.0, 1.0, 0.6)
		var glow_points = PackedVector2Array([
			Vector2(0, -1.2),
			Vector2(1.2, 0),
			Vector2(0, 1.2),
			Vector2(-1.2, 0)
		])
		glow.polygon = glow_points
		glow.z_index = 2
		add_child(glow)
	else:
		# 광물 없음 - 어두운 빈 저장고
		var empty_cargo = Polygon2D.new()
		empty_cargo.color = Color(0.3, 0.3, 0.4, 0.5)  # 어두운 회색
		var empty_points = PackedVector2Array([
			Vector2(-1, -0.5),
			Vector2(1, -0.5),
			Vector2(1, 1),
			Vector2(-1, 1)
		])
		empty_cargo.polygon = empty_points
		empty_cargo.z_index = 1
		add_child(empty_cargo)

func process_turn():
	print("우주선 상태: %s, 위치: %s, 목표: %s" % [State.keys()[state], current_tile, target_tile])
	
	match state:
		State.IDLE:
			_find_nearest_ore()
		State.MOVING_TO_ORE:
			_move_along_path()
		State.MINING:
			_mine_ore()
		State.MOVING_TO_PLANET:
			_move_along_path()
		State.DEPOSITING:
			_deposit_ore()
		State.RETURNING_HOME:
			_move_along_path()

func _find_nearest_ore(exclude_tile: Vector2i = Vector2i(-999999, -999999)):
	if not hex_grid:
		turn_action_completed.emit()
		return
	
	var nearest_ore: Vector2i
	var min_distance: int = 999999
	var found_ore: bool = false
	
	# 사용 가능한 광물만 검색 (채집 중이 아닌 것들)
	var available_ores = hex_grid.get_available_ore_positions()
	for ore_pos in available_ores:
		# 제외할 타일은 건너뛰기 (이미 실패한 타일)
		if ore_pos == exclude_tile:
			continue
			
		var distance = _hex_distance(current_tile, ore_pos)
		if distance < min_distance:
			min_distance = distance
			nearest_ore = ore_pos
			found_ore = true
	
	if found_ore:
		target_tile = nearest_ore
		path = _find_path(current_tile, target_tile)
		if path.size() > 0:
			state = State.MOVING_TO_ORE
			print("새로운 목표 광물 설정: %s (거리: %d)" % [target_tile, min_distance])
		else:
			print("목표 광물로의 경로를 찾을 수 없음: %s" % target_tile)
			_return_to_home_planet()
	else:
		# 채집 가능한 광물이 없으면 소속 행성으로 복귀
		print("채집 가능한 광물이 없습니다 - 소속 행성으로 복귀")
		_return_to_home_planet()
	
	turn_action_completed.emit()

func _move_along_path():
	if path.size() == 0:
		print("경로가 비어있음 - 도착 처리 또는 재계산 필요")
		_handle_arrival()
		return
	
	# 다음 타일 확인
	var next_tile = path[0]
	
	# 이동 가능한지 확인
	if not hex_grid.can_frigate_move_to(next_tile, self):
		# 간단한 우회 시도 (경로 전체 재계산 대신)
		var alternative_path = _find_alternative_move(current_tile, target_tile)
		if alternative_path.size() > 0:
			path = alternative_path + path.slice(1)  # 첫 번째 스텝만 교체
		else:
			# 우회 불가능하면 다른 목표 찾기
			if state == State.MOVING_TO_ORE:
				_find_nearest_ore(target_tile)  # 현재 목표 제외하고 탐색
				return
			elif state == State.RETURNING_HOME:
				# 소속 행성으로 복귀 중 막히면 계속 시도
				state = State.IDLE
			else:
				state = State.IDLE
		turn_action_completed.emit()
		return
	
	# 다음 타일로 이동
	var old_tile = current_tile
	current_tile = path.pop_front()
	
	# 우주선 회전 (이동 방향에 따라)
	_rotate_to_direction(old_tile, current_tile)
	
	# 이동 신호 발송
	frigate_moved.emit(self, old_tile, current_tile)
	
	# 월드 좌표로 변환하여 위치 업데이트
	if hex_grid:
		var world_pos = hex_grid._axial_to_pixel(current_tile.x, current_tile.y, hex_size, hex_grid.pointy_top)
		position = world_pos
	
	# 목적지 도착 확인
	if path.size() == 0:
		_handle_arrival()
	else:
		turn_action_completed.emit()

func _handle_arrival():
	match state:
		State.MOVING_TO_ORE:
			if current_tile == target_tile:
				# 광물이 여전히 사용 가능한지 확인
				if hex_grid.is_ore_being_mined(target_tile):
					# 다른 우주선이 채집 중이면 즉시 다른 광물 찾기 (턴 소모 없음)
					print("우주선이 이미 채집 중인 광물에 도착 - 다른 광물 탐색")
					_find_nearest_ore(target_tile)  # 현재 목표 타일 제외하고 탐색
					return
				else:
					state = State.MINING
					mining_started.emit(self, current_tile)
			else:
				# 목표에 도달하지 않았는데 경로가 끝남 - 경로 재계산
				print("목표에 도달하지 않음. 경로 재계산: 현재=%s, 목표=%s" % [current_tile, target_tile])
				path = _find_path(current_tile, target_tile)
				if path.size() == 0:
					print("경로 재계산 실패 - 다른 광물 탐색")
					_find_nearest_ore(target_tile)
					return
		State.MOVING_TO_PLANET:
			# 행성 영역 내에 도달했는지 확인
			if _is_in_planet_area(current_tile, home_planet_pos):
				state = State.DEPOSITING
			else:
				# 목표에 도달하지 않았는데 경로가 끝남 - 경로 재계산
				print("행성에 도달하지 않음. 경로 재계산: 현재=%s, 목표=%s" % [current_tile, home_planet_pos])
				path = _find_path(current_tile, home_planet_pos)
				if path.size() == 0:
					print("행성으로의 경로 재계산 실패")
					state = State.IDLE
		State.RETURNING_HOME:
			# 소속 행성에 도달했는지 확인
			if _is_in_planet_area(current_tile, home_planet_pos):
				state = State.IDLE
				print("우주선이 소속 행성에 복귀 완료")
			else:
				# 목표에 도달하지 않았는데 경로가 끝남 - 경로 재계산
				print("소속 행성에 도달하지 않음. 경로 재계산: 현재=%s, 목표=%s" % [current_tile, home_planet_pos])
				path = _find_path(current_tile, home_planet_pos)
				if path.size() == 0:
					print("소속 행성으로의 경로 재계산 실패")
					state = State.IDLE
	
	turn_action_completed.emit()

func _is_in_planet_area(tile: Vector2i, planet_center: Vector2i) -> bool:
	# 행성 영역 내에 있는지 확인 (hex_grid의 함수 사용)
	if hex_grid:
		return hex_grid._is_tile_in_planet(tile, planet_center)
	return tile == planet_center

func _mine_ore():
	if carried_ore < max_capacity:
		carried_ore += 1
		ore_collected.emit(self, current_tile)
		mining_stopped.emit(self, current_tile)
		_create_frigate_visuals()  # 광물 표시 업데이트
		
		# 다음 목표: 행성으로 돌아가기
		target_tile = home_planet_pos
		path = _find_path(current_tile, target_tile)
		state = State.MOVING_TO_PLANET
	
	turn_action_completed.emit()

func _deposit_ore():
	if carried_ore > 0:
		ore_deposited.emit(self, home_planet_pos, carried_ore)
		carried_ore = 0
		_create_frigate_visuals()  # 광물 표시 제거
		# 저장 후 다시 광물 탐색 (없으면 자동으로 소속 행성으로 복귀)
		state = State.IDLE
	
	turn_action_completed.emit()

func _find_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	# 간단하고 빠른 그리디 경로 찾기
	var path_result: Array[Vector2i] = []
	var current = start
	var max_steps = 100  # 무한 루프 방지
	var step_count = 0
	var stuck_count = 0  # 막힌 횟수 추적
	
	# 시작점과 목표점이 같으면 빈 경로 반환
	if start == end:
		return path_result
	
	# 헥스 방향 (6방향)
	var directions = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	
	while current != end and step_count < max_steps:
		step_count += 1
		
		# 목표까지의 방향 벡터 계산
		var diff = end - current
		
		# 가능한 이동 방향들을 거리순으로 정렬
		var move_options: Array = []
		
		for direction in directions:
			var next_pos = current + direction
			
			# 이동 가능한지 확인
			if hex_grid and not hex_grid.can_frigate_move_to(next_pos, self):
				continue
			
			# 목표까지의 거리 계산
			var distance_to_goal = _hex_distance(next_pos, end)
			move_options.append({"pos": next_pos, "distance": distance_to_goal})
		
		# 사용 가능한 이동이 없으면 중단
		if move_options.size() == 0:
			stuck_count += 1
			print("경로 찾기 중 막힘 발생 (시도 %d회)" % stuck_count)
			# 즉시 포기하고 다른 방법 시도
			break
		
		stuck_count = 0  # 이동 가능하면 막힌 횟수 초기화
		
		# 목표에 가장 가까운 방향으로 이동
		move_options.sort_custom(func(a, b): return a.distance < b.distance)
		var best_move = move_options[0]
		current = best_move.pos
		path_result.append(current)
	
	if path_result.size() == 0:
		print("경로를 찾을 수 없음: %s -> %s" % [start, end])
	
	return path_result

func _find_alternative_move(start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	# 막힌 경로의 간단한 우회 찾기
	var directions = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	
	var best_option: Vector2i
	var best_distance = 999999
	var found_alternative = false
	
	# 이동 가능한 인접 타일 중 목표에 가장 가까운 것 선택
	for direction in directions:
		var next_pos = start + direction
		
		if hex_grid and hex_grid.can_frigate_move_to(next_pos, self):
			var distance = _hex_distance(next_pos, target)
			if distance < best_distance:
				best_distance = distance
				best_option = next_pos
				found_alternative = true
	
	if found_alternative:
		return [best_option]
	else:
		return []

func _rotate_to_direction(from: Vector2i, to: Vector2i) -> void:
	var direction = to - from
	var angle = 0.0
	
	# 헥스 방향에 따른 각도 계산 (90도 시계방향 추가 회전)
	if direction == Vector2i(1, 0):      # 오른쪽
		angle = 90
	elif direction == Vector2i(1, -1):   # 오른쪽 위
		angle = 30
	elif direction == Vector2i(0, -1):   # 위
		angle = -30
	elif direction == Vector2i(-1, 0):   # 왼쪽
		angle = -90
	elif direction == Vector2i(-1, 1):   # 왼쪽 아래
		angle = -150
	elif direction == Vector2i(0, 1):    # 아래
		angle = 150
	
	rotation_degrees = angle

func _return_to_home_planet():
	# 소속 행성으로 복귀
	if current_tile == home_planet_pos or _is_in_planet_area(current_tile, home_planet_pos):
		# 이미 소속 행성에 있으면 대기 상태
		state = State.IDLE
		print("우주선이 이미 소속 행성에 있습니다")
	else:
		# 소속 행성으로 이동 경로 설정
		target_tile = home_planet_pos
		path = _find_path(current_tile, target_tile)
		if path.size() > 0:
			state = State.RETURNING_HOME
			print("소속 행성으로 복귀 중: %s" % home_planet_pos)
		else:
			state = State.IDLE
			print("소속 행성으로의 경로를 찾을 수 없습니다")

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	return int((abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2)
