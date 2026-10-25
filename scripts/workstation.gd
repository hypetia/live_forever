class_name Workstation
extends Node2D

signal clicked

var occupant_id := -1
var completed_jobs := 0
var highlighted := true
var facility_id := "workbench"
var display_name := "工作台"
var waiting_ids: Array[int] = []


func work_position() -> Vector2:
	if facility_id == "bed":
		return position
	return position + Vector2(-30, 0)


func waiting_position(actor_id: int) -> Vector2:
	if facility_id == "bed":
		return Vector2(145 + actor_id * 36, ShelterNavigation.UPPER_Y)
	if facility_id == "table":
		return Vector2(395 + actor_id * 36, ShelterNavigation.UPPER_Y)
	return Vector2(780 + actor_id * 36, ShelterNavigation.UPPER_Y) if facility_id == "stove" else Vector2(565 + actor_id * 37, ShelterNavigation.LOWER_Y)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if Rect2(-70, -93, 150, 100).has_point(local_point):
			clicked.emit()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if facility_id == "bed":
		return # The mattress is drawn in the room, with the same coordinates.
	if facility_id == "table":
		draw_rect(Rect2(-58, -40, 112, 7), Color("877453"))
		draw_line(Vector2(-48, -33), Vector2(-48, 0), Color("5c6558"), 6)
		draw_line(Vector2(44, -33), Vector2(44, 0), Color("5c6558"), 6)
		draw_circle(Vector2(-10, -44), 11, Color("c1b497"))
		draw_circle(Vector2(-10, -44), 7, Color("927354"))
		return
	if facility_id == "stove":
		_draw_stove()
		return
	# Pool of lamplight, battered worktop, vice and a simple hand tool.
	for radius in range(110, 15, -10):
		draw_circle(Vector2(10, -43), radius, Color(0.82, 0.59, 0.30, 0.009))
	draw_rect(Rect2(-56, -43, 116, 8), Color("927453"))
	draw_line(Vector2(-48, -36), Vector2(-52, -1), Color("5c6260"), 7, true)
	draw_line(Vector2(50, -36), Vector2(54, -1), Color("5c6260"), 7, true)
	draw_rect(Rect2(-45, -17, 91, 5), Color("4b504b"))
	draw_rect(Rect2(-40, -53, 20, 10), Color("7c8580"))
	draw_line(Vector2(-34, -58), Vector2(-34, -43), Color("9caaa0"), 3, true)
	draw_line(Vector2(-1, -46), Vector2(16, -46), Color("b3aea0"), 3, true)
	draw_line(Vector2(37, -44), Vector2(37, -85), Color("a9926a"), 3, true)
	draw_line(Vector2(37, -85), Vector2(17, -85), Color("a9926a"), 3, true)
	draw_colored_polygon(PackedVector2Array([Vector2(11, -84), Vector2(23, -84), Vector2(29, -73), Vector2(5, -73)]), Color("d5bd88"))
	if highlighted:
		draw_arc(Vector2(0, -5), 77, PI * 0.05, PI * 0.95, 40, Color(0.84, 0.69, 0.47, 0.5), 1.2, true)


func _draw_stove() -> void:
	for radius in range(78, 10, -8):
		draw_circle(Vector2(-3, -35), radius, Color(0.87, 0.52, 0.25, 0.012))
	draw_rect(Rect2(-37, -45, 79, 44), Color("59605a"))
	draw_rect(Rect2(-42, -49, 89, 7), Color("92937c"))
	draw_rect(Rect2(3, -32, 25, 22), Color("222e2e"))
	if occupant_id != -1:
		draw_rect(Rect2(8, -27, 15, 12), Color("db9b5f"))
		draw_line(Vector2(-12, -79), Vector2(-15, -89), Color(0.8, 0.84, 0.75, 0.4), 2, true)
		draw_line(Vector2(0, -80), Vector2(4, -94), Color(0.8, 0.84, 0.75, 0.4), 2, true)
	draw_rect(Rect2(-28, -69, 42, 20), Color("858c7a"))
	draw_line(Vector2(-32, -69), Vector2(18, -69), Color("bec2a7"), 4, true)
	draw_circle(Vector2(-7, -74), 3, Color("929a88"))
	draw_line(Vector2(32, -50), Vector2(32, -92), Color("646f68"), 7, true)
	if highlighted:
		draw_arc(Vector2(0, -3), 56, PI * 0.05, PI * 0.95, 32, Color(0.84, 0.69, 0.47, 0.5), 1.2, true)
