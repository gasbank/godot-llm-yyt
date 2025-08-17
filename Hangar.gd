# Hangar.gd
extends Polygon2D

var planet_name: String = ""
var facility_name: String = "Hangar"

signal facility_clicked(facility_name, planet_name)

func set_planet_name(name: String):
	planet_name = name

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int):
	print("Hangar _input_event called: ", event)
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		print("Mouse button: ", mb.button_index, " pressed: ", mb.pressed)
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			print("Right click detected! Emitting signal for planet: ", planet_name)
			# 격납고 우클릭 신호 발송
			facility_clicked.emit(facility_name, planet_name)
