# HexUI.gd
extends Control

var _coord_label: Label
var _hex_grid: Node2D  # HexTileAllBorders 참조

func _ready() -> void:
	# UI 설정 - 화면 좌상단 고정
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 마우스 이벤트 통과
	
	# 좌표 표시 레이블 생성
	_coord_label = Label.new()
	_coord_label.text = "Hex: (0, 0)"
	_coord_label.position = Vector2(10, 10)
	_coord_label.size = Vector2(180, 30)
	
	# 스타일 설정
	_coord_label.add_theme_color_override("font_color", Color.WHITE)
	_coord_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_coord_label.add_theme_constant_override("shadow_offset_x", 1)
	_coord_label.add_theme_constant_override("shadow_offset_y", 1)
	_coord_label.add_theme_font_size_override("font_size", 16)
	
	add_child(_coord_label)
	
	# HexTileAllBorders 찾기 (같은 부모의 Node2D)
	_hex_grid = get_parent()
	if not _hex_grid or not _hex_grid.has_method("_pixel_to_axial"):
		print("HexTileAllBorders 노드를 찾을 수 없습니다")

func _input(event: InputEvent) -> void:
	# 마우스 움직임 이벤트만 처리
	if event is InputEventMouseMotion:
		_update_coord_display()

func _update_coord_display() -> void:
	if not _hex_grid or not _hex_grid.has_method("_pixel_to_axial"):
		return
		
	# 마우스 위치를 헥스 좌표로 변환
	var mouse_screen: Vector2 = get_viewport().get_mouse_position()
	var local: Vector2 = _hex_grid.to_local(mouse_screen)
	var af: Vector2 = _hex_grid._pixel_to_axial(local, _hex_grid.hex_size, _hex_grid.pointy_top)
	var at: Vector2i = _hex_grid._axial_round(af.x, af.y)
	
	# 범위 내 확인
	var inside: bool = _hex_grid._axial_distance(at.x, at.y) <= _hex_grid.radius
	
	if inside:
		_coord_label.text = "Hex: (%d, %d)" % [at.x, at.y]
		_coord_label.modulate = Color.WHITE
	else:
		_coord_label.text = "Hex: Outside"
		_coord_label.modulate = Color.GRAY