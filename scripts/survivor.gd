class_name Survivor
extends Node2D

signal clicked(survivor: Survivor)

enum TaskState { IDLE, MOVING, WAITING, WORKING, BLOCKED, RETURNING, DEAD, AWAY }

var person := CharacterState.new()
var survivor_id := 0
var display_name := ""
var speciality := ""
var description := ""
var tint := Color("9eaf9d")
var selected := false
var state := TaskState.IDLE
var orders: Array[String] = []
var route: Array[Vector2] = []
var work_elapsed := 0.0
var work_duration := 6.0
var repair_duration := 6.0
var task_label := "修整"
var target_label := "工作台"
var held_cost: Dictionary = {}
var legacy_repair := false
var completed_jobs := 0
var completed_by_task := {"repair": 0, "cook": 0, "eat": 0, "sleep": 0, "craft": 0, "heal": 0}
var hunger := 45.0
var fatigue := 30.0
var health := 100.0
var injury := 0.0
var infection := 0.0
var warned := {"hunger": false, "fatigue": false, "health": false, "infection": false}
var feedback := "等待你的安排"
var movement_clock := 0.0
var facing := 1.0
const MOVE_SPEED := 150.0
const FONT := preload("res://assets/fonts/interface.otf")
var visual_time := 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var game := get_parent().get_parent()
	if not game.paused: visual_time += delta * game.speed
	queue_redraw()


func advance_route(delta: float) -> void:
	var travel := MOVE_SPEED * effort_factor() * delta
	while not route.is_empty() and travel > 0.0:
		var destination := route[0]
		var distance := position.distance_to(destination)
		if absf(destination.x - position.x) > 0.5:
			facing = signf(destination.x - position.x)
		if distance <= travel:
			position = destination
			route.pop_front()
			travel -= distance
		else:
			position = position.move_toward(destination, travel)
			travel = 0.0
		movement_clock += delta * 9.0
	queue_redraw()


func status_text() -> String:
	match state:
		TaskState.MOVING: return "前往%s" % target_label
		TaskState.WAITING: return "等待%s空闲" % target_label
		TaskState.WORKING: return "正在%s · %d%%" % [task_label, int(progress() * 100)]
		TaskState.BLOCKED: return "路径阻塞 · 请取消后重派"
		TaskState.RETURNING: return feedback.replace("等待安排", "让出位置")
		TaskState.DEAD: return "已死亡 · 无法执行任务"
		TaskState.AWAY: return "外出探索中"
		_: return feedback


func progress() -> float:
	return clampf(work_elapsed / work_duration, 0.0, 1.0)


func effort_factor() -> float:
	# Slower work is visible and recoverable; eat and sleep never slow down.
	return (0.8 if hunger >= 80 else 1.0) * (0.7 if fatigue >= 85 else 1.0) * (0.85 if injury >= 50 else 1.0) * person.emotional_effort()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if Rect2(-22, -76, 44, 80).has_point(local_point):
			clicked.emit(self)
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if health <= 0:
		draw_line(Vector2(-23, -8), Vector2(22, -8), Color("57615d"), 10, true)
		draw_circle(Vector2(26, -8), 7, Color("72756a"))
		return
	var stride := sin(movement_clock) * 7.0 if state in [TaskState.MOVING, TaskState.RETURNING] else 0.0
	draw_ellipse_shadow()
	if selected:
		draw_arc(Vector2(0, -3), 25, 0, TAU, 40, Color("d6b584"), 1.5, true)
		draw_colored_polygon(PackedVector2Array([Vector2(-5, -89), Vector2(5, -89), Vector2(0, -83)]), Color("e4bf86"))
	# Original geometric placeholder characters; coat, pack, limbs and head.
	if state == TaskState.WORKING and not orders.is_empty() and orders[0] == "sleep":
		draw_set_transform(Vector2(-40, -23), PI / 2)
	draw_line(Vector2(-5, -24), Vector2(-7 + stride, -3), Color("242d30"), 7, true)
	draw_line(Vector2(6, -24), Vector2(9 - stride, -3), Color("242d30"), 7, true)
	draw_line(Vector2(-11 + stride, -2), Vector2(-2 + stride, -2), Color("9b9e92"), 3, true)
	draw_line(Vector2(5 - stride, -2), Vector2(14 - stride, -2), Color("9b9e92"), 3, true)
	draw_rect(Rect2(-17 * facing - 4, -53, 11, 28), tint.darkened(0.45))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -56), Vector2(10, -56), Vector2(13, -23), Vector2(-12, -23)]), tint)
	var working := state == TaskState.WORKING
	var eating := working and not orders.is_empty() and orders[0] == "eat"
	var hand := Vector2(12 * facing, -58 + sin(visual_time * 2) * 3) if eating else Vector2(21 * facing, -40 + sin(visual_time * 5) * 7 if working else -26 + sin(visual_time * 1.4) * 2)
	if working and not orders.is_empty() and orders[0] in ["repair", "craft"]:
		draw_line(hand, hand + Vector2(9 * facing, -12), Color("a1a78f"), 3, true)
		draw_line(hand + Vector2(4 * facing, -12), hand + Vector2(14 * facing, -12), Color("a1a78f"), 4, true)
	if working and not orders.is_empty() and orders[0] == "heal":
		draw_line(hand + Vector2(-5, -3), hand + Vector2(5, -3), Color("ecdbba"), 3)
		draw_line(hand + Vector2(0, -8), hand + Vector2(0, 2), Color("ecdbba"), 3)
	draw_line(Vector2(7 * facing, -50), hand, tint.lightened(0.1), 6, true)
	draw_circle(hand, 3, Color("bdab91"))
	draw_rect(Rect2(-3, -61, 7, 9), Color("ad987e"))
	draw_circle(Vector2(0, -66), 9, Color("c7b294"))
	draw_arc(Vector2(0, -68), 9, PI, TAU, 16, Color("333b3b"), 5, true)
	draw_line(Vector2(-8, -59), Vector2(8, -56), tint.darkened(0.35), 4, true)
	draw_set_transform(Vector2.ZERO)
	if selected or health < 60:
		draw_rect(Rect2(-26, -117, 52, 5), Color("172320"))
		draw_rect(Rect2(-26, -117, 52 * health / 100.0, 5), Color("d48f75") if health < 40 else Color("9dbb9b"))
	if selected:
		draw_string(FONT, Vector2(-22, 22), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e4d0a8"))
	if state == TaskState.WORKING:
		draw_string(FONT, Vector2(-26, -87), "用药中" if not orders.is_empty() and orders[0] == "heal" else task_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c8cbb1"))
		draw_rect(Rect2(-23, -102, 46, 4), Color("273236"))
		draw_rect(Rect2(-23, -102, 46 * progress(), 4), Color("d6b584"))


func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, 24, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
