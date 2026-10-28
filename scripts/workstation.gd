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
var tier := 1


func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	var game:=get_parent().get_parent()
	if not game.paused: animation_time += delta*game.speed
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
	if facility_id in ['water','table','stove','workbench']:_draw_painted()
	elif facility_id=='exit':RealismAssets.door(self,Rect2(-22,-87,44,87))
	# The bed is drawn once in the room at its actual interaction anchor.


func cooking_state() -> Dictionary:
	if facility_id!='stove':return {}
	var game:=get_parent().get_parent()
	if occupant_id>=0 and occupant_id<game.survivors.size():
		var worker:Survivor=game.survivors[occupant_id]
		if worker.state==Survivor.TaskState.WORKING and not worker.orders.is_empty() and worker.orders[0]=='cook':return {'actor':occupant_id,'progress':worker.progress()}
	if 'camp' in game and game.camp.enabled:
		for task in game.camp.food.jobs:
			var recipe:Dictionary=CampFoodCatalog.RECIPES[task['kind']]
			if recipe['station']=='stove' and recipe.get('heat',false) and float(task['elapsed'])>0:return {'actor':int(task['actor']),'progress':float(task['elapsed'])/float(recipe['seconds'])}
	var job:=_external_job()
	if not job.is_empty() and FacilitySystem.RECIPES.get(job['kind'],{}).has('output'):
		return {'actor':int(job['actor']),'progress':float(job['elapsed'])/float(job['duration'])}
	return {}


func _draw_interaction() -> void:
	var quiet: bool = get_parent().get_parent().has_method("_compact_card")
	var job := _external_job()
	if quiet and not hovered and occupant_id < 0 and job.is_empty(): return
	var point := Vector2(34,-112) if facility_id=="stove" else Vector2(0,-118)
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
	elif quiet and not job.is_empty():
		draw_arc(point,19,-PI/2,-PI/2+TAU*float(job["elapsed"])/float(job["duration"]),30,Color("eed2a0"),2.5,true)
	if quiet and facility_id in ["workbench","stove"]:
		for level in range(3): draw_circle(point+Vector2((level-1)*8,27),2.5,Color("d5bd88") if level < tier else Color("44514b"))
	if occupant_id >= 0:
		draw_circle(point + Vector2(14, 12), 4, Color("9abca1"))


func _external_job() -> Dictionary:
	var game := get_parent().get_parent()
	if not game.has_method("facilities_snapshot"): return {}
	for job in game.expansion.jobs:
		if FacilitySystem.station_for(job["kind"]) != facility_id: continue
		var actor: Survivor = game.survivors[int(job["actor"])]
		return job if occupant_id < 0 and actor.route.is_empty() and actor.position.distance_to(SurvivalExpansion.job_position(job["kind"])) <= 10 else {}
	return {}


func interaction_rect() -> Rect2:
	return Rect2(-28, -135, 56, 140) if facility_id in ["water", "exit"] else Rect2(-70, -135, 150, 140)


func interaction_ready(actor: Survivor) -> bool:
	var target := position if facility_id == "water" else work_position()
	return facility_id != "exit" and actor.position.distance_to(target) <= 1.0


func _draw_painted() -> void:
	if facility_id=='water':
		RealismAssets.prop(self,12,Rect2(-29,-52,58,52))
		draw_line(Vector2(-17,-17),Vector2(12,-17),Color('738f92'),3,true)
	elif facility_id=='table':
		RealismAssets.prop(self,3,Rect2(-59,-51,118,51))
		draw_arc(Vector2(-8,-43),8,0,TAU,20,Color('c0b49c'),2,true)
	elif facility_id=='workbench':
		RealismAssets.prop(self,1,Rect2(-60,-61,120,61))
		for radius in range(78,10,-9):draw_circle(Vector2(23,-53),radius,Color(.87,.71,.42,.007))
		draw_line(Vector2(34,-52),Vector2(34,-91),Color('8c7b5d'),2,true)
		draw_line(Vector2(34,-91),Vector2(15,-91),Color('9b8964'),2,true)
		draw_colored_polygon(PackedVector2Array([Vector2(11,-92),Vector2(22,-92),Vector2(27,-83),Vector2(5,-83)]),Color('c7b98a'))
		if tier>=2:
			draw_rect(Rect2(-41,-102,43,28),Color('35413b'))
			for x in [-33,-20,-7]:draw_line(Vector2(x,-98),Vector2(x+4,-78),Color('a0a392'),2,true)
		if tier>=3:RealismAssets.prop(self,8,Rect2(-39,-54,31,19))
	else:
		RealismAssets.prop(self,2,Rect2(-23,-65,90,65),Color.WHITE,false,true)
		var cooking:=cooking_state()
		if not cooking.is_empty():
			var progress:float=cooking['progress'];var heat:=smoothstep(.15,.32,progress)
			if heat>0:
				for radius in range(42,4,-6):draw_circle(Vector2(-6,-45),radius,Color(.97,.56,.20,.008*heat))
				for i in range(4):
					var phase:=fposmod(animation_time*.6+i*.24,1)
					draw_arc(Vector2(-8+sin(phase*4+i)*6,-60-phase*25),3+phase*4,0,PI,12,Color(.85,.85,.78,(1-phase)*.35*heat),1.2,true)
			if progress<.3:
				draw_rect(Rect2(-38,-43,24,4),Color('a88b5e'))
				for i in range(4):draw_circle(Vector2(-34+i*5,-45),2,Color('8e9b68') if i%2 else Color('a47a68'))
			elif progress>.82:draw_arc(Vector2(-27,-45),9,0,PI,14,Color('c6b492'),4,true)
		if tier>=2:draw_line(Vector2(52,-46),Vector2(52,-105),Color('777f73'),7,true)
		if tier>=3:RealismAssets.prop(self,8,Rect2(31,-54,29,17))
