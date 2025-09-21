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
@onready var planet_name_label: Label = $MainContainer/ContentContainer/ContentVBox/PlanetNameRow/PlanetName
@onready var planet_radius_label: Label = $MainContainer/ContentContainer/ContentVBox/RadiusRow/PlanetRadius
@onready var resource_count_label: Label = $MainContainer/ContentContainer/ContentVBox/ResourceRow/ResourceCount
@onready var close_button: Button = $MainContainer/HeaderContainer/HeaderMargin/HeaderContent/CloseButton
@onready var title_label: Label = $MainContainer/HeaderContainer/HeaderMargin/HeaderContent/Title
@onready var header_container: Control = $MainContainer/HeaderContainer
@onready var content_container: MarginContainer = $MainContainer/ContentContainer
@onready var content_vbox: VBoxContainer = $MainContainer/ContentContainer/ContentVBox

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

	# 제목표시줄에 드래그 이벤트 연결
	if header_container:
		header_container.gui_input.connect(_on_header_gui_input)
		header_container.mouse_filter = Control.MOUSE_FILTER_PASS
		print("Header drag event connected")

	# 마우스 이벤트를 팝업이 모두 차단하도록 설정
	mouse_filter = Control.MOUSE_FILTER_STOP

	# CanvasLayer에서는 z-index가 중요하지 않음
	z_index = 0
	visible = true

	# 콘텐츠 크기에 맞춰 팝업 크기 조절
	_adjust_popup_size()

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

	# 콘텐츠 크기에 맞춰 팝업 크기 조절
	_adjust_popup_size()

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
	# 모든 마우스 이벤트를 소비하여 뒤쪽 요소들로 전달되지 않도록 함
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
	popup_closed.emit(self)
	queue_free()

func _on_header_gui_input(event: InputEvent):
	# 제목표시줄에서 드래그 처리
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

func _adjust_popup_size():
	# 콘텐츠 크기 계산을 위해 다음 프레임까지 대기
	await get_tree().process_frame

	if content_vbox:
		# 콘텐츠의 실제 크기 계산
		var content_size = content_vbox.get_combined_minimum_size()

		# 헤더와 마진을 고려한 최소 크기 계산
		var header_height = 32  # HeaderContainer의 minimum_size
		var margin_x = 24  # 좌우 마진 (12 + 12)
		var margin_y = 16  # 상하 마진 (4 + 12)
		var border_offset = 4  # 보더 오프셋

		var min_width = content_size.x + margin_x + border_offset
		var min_height = content_size.y + header_height + margin_y + border_offset

		# 최소 크기 적용 (기존 크기보다 작지 않도록)
		var new_width = max(size.x, min_width)
		var new_height = max(size.y, min_height)

		# 크기 조정
		if new_width != size.x or new_height != size.y:
			size = Vector2(new_width, new_height)
			print("Popup size adjusted to: ", size)

func _input(event: InputEvent):
	# ESC 키로 팝업 닫기
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print("ESC pressed - closing planet popup")
			popup_closed.emit(self)
			queue_free()
			get_viewport().set_input_as_handled()