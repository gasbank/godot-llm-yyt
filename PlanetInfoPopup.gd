# PlanetInfoPopup.gd
extends Control

# 팝업 데이터
var planet_name: String = ""
var planet_radius: int = 0
var resource_count: int = 0

# 드래그 상태
var is_dragging: bool = false
var drag_offset: Vector2

# UI 노드 참조 (@onready로 자동 할당)
@onready var planet_name_label: Label = $VBoxContainer/Content/PlanetNameContainer/PlanetName
@onready var planet_radius_label: Label = $VBoxContainer/Content/RadiusContainer/PlanetRadius
@onready var resource_count_label: Label = $VBoxContainer/Content/ResourceContainer/ResourceCount
@onready var close_button: Button = $VBoxContainer/Header/CloseButton
@onready var title_label: Label = $VBoxContainer/Header/Title

# 신호
signal popup_closed(popup)

func _ready():
	print("PlanetInfoPopup _ready - all UI elements created in tscn file")
	print("Node references - Name:", planet_name_label != null, " Radius:", planet_radius_label != null, " Resource:", resource_count_label != null)

	# 닫기 버튼 연결
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
		print("Close button connected")
	else:
		print("Close button not found!")

	# 드래그 이벤트 설정
	mouse_filter = Control.MOUSE_FILTER_PASS

	# CanvasLayer에서는 z-index가 중요하지 않음
	z_index = 0
	visible = true

	print("PlanetInfoPopup _ready complete.")
	print("Position: ", position, " Size: ", size, " Visible: ", visible)
	print("Parent type: ", get_parent().get_class() if get_parent() else "no parent")

func setup_popup(p_name: String, p_radius: int, p_resource_count: int):
	planet_name = p_name
	planet_radius = p_radius
	resource_count = p_resource_count

	print("Setting up planet popup: ", planet_name, " radius:", planet_radius, " resources:", resource_count)

	# 레이블 업데이트
	_update_labels()

func _update_labels():
	# UI 업데이트
	if planet_name_label:
		planet_name_label.text = "행성: " + planet_name
		print("Updated planet name label: ", planet_name_label.text)

	if planet_radius_label:
		planet_radius_label.text = "반지름: " + str(planet_radius)
		print("Updated radius label: ", planet_radius_label.text)

	if resource_count_label:
		resource_count_label.text = "보유 자원: " + str(resource_count) + "개"
		print("Updated resource label: ", resource_count_label.text)

	if title_label:
		title_label.text = planet_name + " 정보"
		print("Updated title label: ", title_label.text)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# 드래그 시작
				is_dragging = true
				drag_offset = global_position - get_global_mouse_position()
				# CanvasLayer에서는 child 순서 변경만으로 충분
				if get_parent():
					get_parent().move_child(self, -1)
			else:
				# 드래그 종료
				is_dragging = false

	elif event is InputEventMouseMotion and is_dragging:
		# 드래그 중 위치 업데이트
		global_position = get_global_mouse_position() + drag_offset

func _on_close_button_pressed():
	print("Planet popup close button pressed")
	popup_closed.emit(self)
	queue_free()

func _input(event: InputEvent):
	# ESC 키로 팝업 닫기
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print("ESC pressed - closing planet popup")
			popup_closed.emit(self)
			queue_free()
			get_viewport().set_input_as_handled()