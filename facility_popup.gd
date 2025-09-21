# FacilityPopup.gd
extends Control

var facility_name: String = ""
var planet_name: String = ""
var is_dragging: bool = false
var drag_offset: Vector2

var facility_name_label: Label
var planet_name_label: Label
var close_button: Button
var title_label: Label

signal popup_closed(popup)

func _ready():
	# 노드 참조 가져오기
	facility_name_label = $VBoxContainer/Content/FacilityName
	planet_name_label = $VBoxContainer/Content/PlanetName
	close_button = $VBoxContainer/Header/CloseButton
	title_label = $VBoxContainer/Header/Title
	
	# 닫기 버튼 연결
	close_button.pressed.connect(_on_close_button_pressed)
	
	# 드래그 이벤트 설정
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# 팝업을 최상위에 표시 (모든 요소보다 위에)
	z_index = 10000
	
	# 초기 위치를 화면 중앙으로 설정
	position = get_viewport().get_visible_rect().size / 2 - size / 2
	
	# 이미 데이터가 설정되어 있다면 레이블 업데이트
	if facility_name != "":
		_update_labels()

func setup_popup(facility_name_text: String, planet_name_text: String):
	facility_name = facility_name_text
	planet_name = planet_name_text
	
	# _ready가 호출된 후라면 즉시 업데이트, 아니면 _ready에서 처리
	if facility_name_label:
		_update_labels()

func _update_labels():
	# UI 업데이트
	if facility_name_label:
		facility_name_label.text = "Facility: " + facility_name
	if planet_name_label:
		planet_name_label.text = "Planet: " + planet_name
	if title_label:
		title_label.text = facility_name + " Info"

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# 드래그 시작
				is_dragging = true
				drag_offset = global_position - get_global_mouse_position()
				# 이 팝업을 최상위로 가져오기
				get_parent().move_child(self, -1)
				z_index = 10000
			else:
				# 드래그 종료
				is_dragging = false
	
	elif event is InputEventMouseMotion and is_dragging:
		# 드래그 중 위치 업데이트
		global_position = get_global_mouse_position() + drag_offset

func _on_close_button_pressed():
	popup_closed.emit(self)
	queue_free()

func _input(event: InputEvent):
	# DELETE 키로 팝업 닫기 (전역 처리)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE:
			# 모든 팝업 닫기는 부모에서 처리하도록 신호 발송
			popup_closed.emit(self)
			queue_free()
