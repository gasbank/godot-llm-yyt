extends Control

var ranking_container: VBoxContainer
var hex_tile_manager: Node2D

signal planet_ranking_clicked(planet_name: String)

func _ready():
	print("PlanetResourceRanking _ready() called")
	print("Parent: ", get_parent().name if get_parent() else "null")
	print("Children count: ", get_child_count())
	for i in range(get_child_count()):
		var child = get_child(i)
		print("Child ", i, ": ", child.name, " (", child.get_class(), ")")

	ranking_container = get_node_or_null("VBoxContainer")
	if not ranking_container:
		print("ERROR: VBoxContainer not found in planet_resource_ranking!")
		print("Available children:")
		for child in get_children():
			print("  - ", child.name, " (", child.get_class(), ")")
		return

	print("VBoxContainer found successfully")

	# CanvasLayer에서는 앵커 프리셋이 다르게 작동할 수 있으므로 직접 위치 설정
	var viewport_size = get_viewport().get_visible_rect().size
	position = Vector2(viewport_size.x - 220, 10)  # 오른쪽 위 고정
	size = Vector2(210, 400)

	print("Ranking UI positioned at: ", position, " with size: ", size)

func setup_ranking(planet_data: Array, manager: Node2D):
	print("setup_ranking() called")
	hex_tile_manager = manager

	# _ready()가 호출되지 않았다면 다시 시도
	if not ranking_container:
		print("ranking_container not ready, trying to find VBoxContainer again")
		ranking_container = get_node_or_null("VBoxContainer")
		if not ranking_container:
			print("ERROR: Still cannot find VBoxContainer")
			return

	_update_ranking_display(planet_data)

func _update_ranking_display(planet_data: Array):
	if not ranking_container:
		print("ERROR: ranking_container is null in _update_ranking_display")
		return

	for child in ranking_container.get_children():
		child.queue_free()

	planet_data.sort_custom(_compare_planets)

	var current_rank = 1
	var previous_resource_count = -1
	var display_rank = 1

	for i in range(planet_data.size()):
		var planet = planet_data[i]
		var resource_count = planet.resource_count

		if resource_count != previous_resource_count:
			current_rank = i + 1
			display_rank = current_rank

		var label = Label.new()
		label.text = "%d위. %s %d개" % [display_rank, planet.name, resource_count]
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)

		var button = Button.new()
		button.flat = true
		button.add_child(label)
		button.custom_minimum_size = Vector2(200, 25)
		button.pressed.connect(_on_planet_button_pressed.bind(planet.name))

		ranking_container.add_child(button)

		previous_resource_count = resource_count

func _compare_planets(a: Dictionary, b: Dictionary) -> bool:
	return a.resource_count > b.resource_count

func _on_planet_button_pressed(planet_name: String):
	if hex_tile_manager:
		hex_tile_manager._center_camera_on_planet(planet_name)

func update_ranking(planet_data: Array):
	if not ranking_container:
		print("ERROR: ranking_container is null in update_ranking")
		return
	_update_ranking_display(planet_data)