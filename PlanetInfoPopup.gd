# PlanetInfoPopup.gd
extends Control

# 팝업 데이터
var planet_name: String = ""
var planet_radius: int = 0
var resource_count: int = 0
var planet_instance: Node2D = null  # 연결된 행성 인스턴스

# 드래그 상태
var is_dragging: bool = false
var drag_offset: Vector2

# UI 노드 참조 (@onready로 자동 할당)
@onready var planet_name_label: Label = $PopupPanel/ContentVBox/PlanetNameRow/PlanetName
@onready var planet_radius_label: Label = $PopupPanel/ContentVBox/RadiusRow/PlanetRadius
@onready var resource_count_label: Label = $PopupPanel/ContentVBox/ResourceRow/ResourceCount
@onready var close_button: Button = $PopupPanel/ContentVBox/TitleRow/CloseButton
@onready var title_label: Label = $PopupPanel/ContentVBox/TitleRow/TitleMargin/Title
@onready var popup_panel: PanelContainer = $PopupPanel

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

	# 팝업 전체 영역에서 드래그 처리
	print("Popup drag handling enabled for entire area")

	# 마우스 이벤트를 팝업이 모두 차단하도록 설정
	mouse_filter = Control.MOUSE_FILTER_STOP

	# CanvasLayer에서는 z-index가 중요하지 않음
	z_index = 0
	visible = true

	print("PlanetInfoPopup _ready complete.")
	print("Position: ", position, " Visible: ", visible)
	print("Parent type: ", get_parent().get_class() if get_parent() else "no parent")

func setup_popup(p_name: String, p_radius: int, p_resource_count: int, p_planet_instance: Node2D = null):
	planet_name = p_name
	planet_radius = p_radius
	resource_count = p_resource_count
	planet_instance = p_planet_instance

	print("Setting up planet popup: ", planet_name, " radius:", planet_radius, " resources:", resource_count)

	# 행성 인스턴스와 연결하여 실시간 자원 업데이트 감지
	if planet_instance and planet_instance.has_signal("resource_changed"):
		planet_instance.resource_changed.connect(_on_planet_resource_changed)
		print("Connected to planet resource change signal")

	# 레이블 업데이트
	_update_labels()

func _on_planet_resource_changed(new_resource_count: int):
	# 행성의 자원이 변경되었을 때 팝업 업데이트
	resource_count = new_resource_count
	_update_resource_label()
	print("Popup resource count updated to: ", resource_count)

func _update_resource_label():
	# 자원 개수 레이블만 업데이트
	if resource_count_label:
		resource_count_label.text = "보유 자원: " + str(resource_count) + "개"
		print("Updated resource label: ", resource_count_label.text)

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
	# 팝업 전체 영역에서 드래그 처리
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

		# 이벤트 소비
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if is_dragging:
			# 드래그 중 위치 업데이트
			global_position = get_global_mouse_position() + drag_offset

		# 마우스 모션 이벤트도 소비
		get_viewport().set_input_as_handled()

func _on_close_button_pressed():
	print("Planet popup close button pressed")
	_cleanup_connections()
	popup_closed.emit(self)
	queue_free()

func _cleanup_connections():
	# 행성 인스턴스와의 신호 연결 해제
	if planet_instance and planet_instance.has_signal("resource_changed"):
		if planet_instance.resource_changed.is_connected(_on_planet_resource_changed):
			planet_instance.resource_changed.disconnect(_on_planet_resource_changed)
			print("Disconnected from planet resource change signal")



func _input(event: InputEvent):
	# ESC 키로 팝업 닫기
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print("ESC pressed - closing planet popup")
			_cleanup_connections()
			popup_closed.emit(self)
			queue_free()
			get_viewport().set_input_as_handled()
