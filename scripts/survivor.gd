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
var illness := 0.0
var cold_exposure := 0.0
var weapon_item: Dictionary = {}
var armor_item: Dictionary = {}
var coat_item: Dictionary = {}
var warned := {"hunger": false, "fatigue": false, "health": false, "infection": false}
var feedback := "等待你的安排"
var movement_clock := 0.0
var facing := 1.0
var metabolism := 1.0
var move_multiplier := 1.0
var manual_walking := false
var activity: Dictionary = {}
var self_care_kind := ""
var self_care_wait := ""
const MOVE_SPEED := 150.0
const FONT := preload("res://assets/fonts/interface.otf")
var visual_time := 0.0
var visual_health := -1.0
var death_age := 1.0
var hurt_age := 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var game := get_parent().get_parent()
	if visual_health>0 and health<=0: death_age=0.0
	elif visual_health>0 and visual_health-health>=1: hurt_age=.4
	visual_health=health
	if not game.paused:
		visual_time += delta * game.speed
		death_age=minf(1,death_age+delta*game.speed);hurt_age=maxf(0,hurt_age-delta*game.speed)
	queue_redraw()


func advance_route(delta: float) -> void:
	var travel := MOVE_SPEED * effort_factor() * move_multiplier * delta
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
	if manual_walking: return "移动中"
	if not self_care_kind.is_empty():
		var labels := {"drink":"自行饮水","eat":"自行吃饭","cook_eat":"自行备餐","sleep":"自行休息","cook_shared":"为同伴备餐","aid":"照护同伴"}
		return labels.get(self_care_kind,"") + (" · 行走中" if not route.is_empty() else " · 等待设施" if state == TaskState.WAITING else "")
	if not activity.is_empty(): return "%s · %d%%" % [activity["label"], roundi(activity["progress"] * 100)]
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


func weapon() -> Dictionary:
	if weapon_item.is_empty() or weapon_item["durability"] <= 0: return {}
	return GearCatalog.ITEMS[weapon_item["kind"]]


func protection() -> float:
	if armor_item.is_empty() or armor_item["durability"] <= 0: return 0.0
	return float(GearCatalog.ITEMS[armor_item["kind"]].get("protection", 0))


func warmth() -> float:
	var total := 0.0
	for item in [armor_item, coat_item]:
		if not item.is_empty() and item["durability"] > 0: total += float(GearCatalog.ITEMS[item["kind"]].get("warmth", 0))
	return total


func effort_factor() -> float:
	# Slower work is visible and recoverable; eat and sleep never slow down.
	return (0.65 if illness >= 50 else 1.0) * (0.8 if hunger >= 80 else 1.0) * (0.7 if fatigue >= 85 else 1.0) * (0.85 if injury >= 50 else 1.0) * person.emotional_effort()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if Rect2(-22, -76, 44, 80).has_point(local_point):
			clicked.emit(self)
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if health <= 0:
		CharacterMotion.draw(self,Vector2.ZERO,self,CharacterMotion.pose('dead',visual_time,CharacterMotion.death_progress(death_age,get_parent().get_parent().game_over),facing))
		return
	var quiet: bool = get_parent().get_parent().has_method("_compact_card")
	var stride := sin(movement_clock) * 7.0 if state in [TaskState.MOVING, TaskState.RETURNING] or manual_walking else 0.0
	draw_ellipse_shadow()
	if quiet and not selected and Rect2(-22,-76,44,80).has_point(get_local_mouse_position()):
		var hover_ring := PackedVector2Array()
		for i in range(33): hover_ring.append(Vector2(cos(i*TAU/32)*22,sin(i*TAU/32)*6-2))
		draw_polyline(hover_ring,Color("c5cec7"),1.5,true)
	if selected:
		if quiet:
			var ring := PackedVector2Array()
			for i in range(33): ring.append(Vector2(cos(i*TAU/32)*20,sin(i*TAU/32)*5-2))
			draw_polyline(ring,Color("b8a781"),1,true)
		else: draw_arc(Vector2(0, -3),25,0,TAU,40,Color("d6b584"),1.5,true)
		draw_colored_polygon(PackedVector2Array([Vector2(-5, -89), Vector2(5, -89), Vector2(0, -83)]), Color("e4bf86"))
	var game := get_parent().get_parent()
	var context:=CharacterMotion.shelter_context(self,game)
	if hurt_age>0:context={'mode':'hurt','progress':1-hurt_age/.4}
	CharacterMotion.draw(self,Vector2.ZERO,self,CharacterMotion.pose(context['mode'],game.simulation_time,context['progress'],facing,str(weapon_item.get('kind',''))),game.has_method('siege_snapshot') and game.siege.active)
	if selected or health < 60:
		draw_rect(Rect2(-26, -117, 52, 5), Color("172320"))
		draw_rect(Rect2(-26, -117, 52 * health / 100.0, 5), Color("d48f75") if health < 40 else Color("9dbb9b"))
	if selected and not quiet:
		draw_string(FONT, Vector2(-22, 22), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e4d0a8"))
	if not activity.is_empty():
		if not quiet: draw_string(FONT, Vector2(-26, -87), activity["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c8cbb1"))
		draw_rect(Rect2(-23, -102, 46, 4), Color("273236"))
		draw_rect(Rect2(-23, -102, 46 * activity["progress"], 4), Color("d6b584"))
	elif state == TaskState.WORKING:
		if not quiet: draw_string(FONT, Vector2(-26, -87), "用药中" if not orders.is_empty() and orders[0] == "heal" else task_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c8cbb1"))
		draw_rect(Rect2(-23, -102, 46, 4), Color("273236"))
		draw_rect(Rect2(-23, -102, 46 * progress(), 4), Color("d6b584"))
	if not self_care_kind.is_empty():
		HudIcons.draw(self,"hydration" if self_care_kind == "drink" else "vigor" if self_care_kind == "sleep" else "fullness",Vector2(29,-91),13,Color("b9c5ac"))


func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.25))
	draw_circle(Vector2.ZERO, 24, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
