class_name Workstation
extends Node2D

signal clicked

var occupant_id := -1
var completed_jobs := 0
var highlighted := false
var facility_id := "workbench"
var display_name := "工作台"
var waiting_ids: Array[int] = []
const FONT := preload("res://assets/fonts/interface.otf")
var hovered := false
var animation_time := 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	animation_time += delta
	hovered = interaction_rect().has_point(get_local_mouse_position())
	queue_redraw()


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


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if interaction_rect().has_point(local_point):
			clicked.emit()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	_draw_interaction()
	if facility_id == "water":
		draw_rect(Rect2(-22, -61, 45, 60), Color("4b6664"))
		draw_rect(Rect2(-19, -59, 39, 9), Color("71867b"))
		draw_line(Vector2(-12, -36), Vector2(5, -36), Color("a4b3a5"), 3)
		return
	if facility_id == "exit":
		draw_rect(Rect2(-22, -87, 44, 87), Color("687563"))
		draw_rect(Rect2(-17, -82, 34, 82), Color("1b2927"))
		draw_circle(Vector2(9, -39), 3, Color("c2af83"))
		return
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
	if hovered:
		draw_arc(Vector2(0, -5), 35, PI * 0.05, PI * 0.95, 40, Color(0.84, 0.69, 0.47, 0.5), 1.2, true)


func _draw_stove() -> void:
	for radius in range(78, 10, -8):
		draw_circle(Vector2(-3, -35), radius, Color(0.87, 0.52, 0.25, 0.012))
	draw_rect(Rect2(-37, -45, 79, 44), Color("59605a"))
	draw_rect(Rect2(-42, -49, 89, 7), Color("92937c"))
	draw_rect(Rect2(3, -32, 25, 22), Color("222e2e"))
	if occupant_id != -1:
		draw_rect(Rect2(8, -27, 15, 12), Color("db9b5f"))
		draw_line(Vector2(-12 + sin(animation_time * 2) * 3, -79), Vector2(-15 + sin(animation_time * 2 + 1) * 4, -89), Color(0.8, 0.84, 0.75, 0.4), 2, true)
		draw_line(Vector2(sin(animation_time * 2 + 1) * 3, -80), Vector2(4 + sin(animation_time * 2) * 4, -94), Color(0.8, 0.84, 0.75, 0.4), 2, true)
	draw_rect(Rect2(-28, -69, 42, 20), Color("858c7a"))
	draw_line(Vector2(-32, -69), Vector2(18, -69), Color("bec2a7"), 4, true)
	draw_circle(Vector2(-7, -74), 3, Color("929a88"))
	draw_line(Vector2(32, -50), Vector2(32, -92), Color("646f68"), 7, true)
	if hovered:
		draw_arc(Vector2(0, -3), 35, PI * 0.05, PI * 0.95, 32, Color(0.84, 0.69, 0.47, 0.5), 1.2, true)


func _draw_interaction() -> void:
	var quiet: bool = get_parent().get_parent().has_method("_compact_card")
	if quiet and not hovered and occupant_id < 0: return
	var point := Vector2(0, -118)
	var game := get_parent().get_parent()
	var actor: Survivor = game.survivors[game.selected_id]
	var ready := interaction_ready(actor)
	var color := Color("eed2a0") if hovered and (not quiet or ready) else Color("b9bb9e")
	draw_circle(point, 15, Color("1a2927"))
	draw_arc(point, 15, 0, TAU, 24, color, 1.5, true)
	var glyph: String = {"bed": "休", "table": "食", "stove": "炊", "workbench": "工", "water": "水", "exit": "出"}[facility_id]
	if quiet: HudIcons.draw(self,facility_id,point,15,color)
	else: draw_string(FONT, point + Vector2(-7, 5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
	if hovered and not quiet:
		var prompt: String = {"bed": "床位 · 休息", "table": "餐桌 · 进食 / 本人用药", "stove": "灶台 · 做饭", "workbench": "工作台 · 修整 / 制作", "water": "饮水 · 选中者喝水 / 消耗水1", "exit": "门口 · 准备外出 V"}[facility_id]
		var width := FONT.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_rect(Rect2(point + Vector2(-width / 2 - 10, -46), Vector2(width + 20, 24)), Color("182622"))
		draw_string(FONT, point + Vector2(-width / 2, -29), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	if quiet and hovered and facility_id != "exit":
		var target := Vector2.ZERO if facility_id == "water" else work_position()-position
		draw_arc(target+Vector2(0,-2),14,0,TAU,24,color,1.5,true)
	if quiet and occupant_id >= 0:
		var worker: Survivor = game.survivors[occupant_id]
		draw_arc(point,19,-PI/2,-PI/2+TAU*worker.progress(),30,Color("eed2a0"),2.5,true)
	if occupant_id >= 0:
		draw_circle(point + Vector2(14, 12), 4, Color("9abca1"))


func interaction_rect() -> Rect2:
	return Rect2(-28, -135, 56, 140) if facility_id in ["water", "exit"] else Rect2(-70, -135, 150, 140)


func interaction_ready(actor: Survivor) -> bool:
	var target := position if facility_id == "water" else work_position()
	return facility_id != "exit" and actor.position.distance_to(target) <= 1.0
