class_name ExpeditionView
extends Node2D
## Original procedural expedition scene and HUD. Never advances simulation.

const FONT := preload("res://assets/fonts/interface.otf")
const INK := Color("d8ded7")
const GOLD := Color("d6b584")
const MUTED := Color("85928e")
var quiet := false
var game: Node2D
var layer: CanvasLayer
var hud: Control
var title_label: Label
var area_hint: Label
var alert_label: Label
var context_label: Label
var actor_label: Label
var role_label: Label
var stats_label: Label
var gear_label: Label
var capacity_label: Label
var feedback_label: Label
var log_label: Label
var search_bar: ProgressBar
var decoy_button: Button
var search_button: Button
var attack_button: Button
var medicine_button: Button
var drink_button: Button
var retreat_button: Button
var drop_buttons: Dictionary = {}
var search_held := false
var hurt_time := 0.0
var damage_amount := 0
var last_health := -1.0
var last_attempt := -1
var last_actor := -1
var bag_open := false
var bag_nodes: Array[Control] = []
var stack_panel: Panel
var stack_grid: BackpackGrid
var stack_capacity: Label
var bag_button: Button
var impact_time := 0.0
var impact_kind := ""
var impact_point := Vector2.ZERO
var impact_damage := 0
var equipment_buttons: Array[Button] = []
var equipment_name: Label
var equipment_dialog: AcceptDialog
var _equipment_pause_before := false
var _equipment_opened := false
var combat_effects := CombatEffects.new()
var effects_location := ""
var effects_attempt := -1


func _ready() -> void:
	quiet = game.has_method("_compact_card")
	layer = CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	for world: ExpeditionState in game.regions.values():
		world.combat_resolved.connect(_on_combat_resolved)
		world.enemy_damaged.connect(_on_enemy_damaged.bind(world))
		world.player_hurt.connect(_on_player_hurt.bind(world))
	title_label = _label("", Vector2(32, 151), Vector2(680, 34), 22, INK)
	alert_label = _label("", Vector2(730, 155), Vector2(650, 28), 15, GOLD)
	gear_label = _label("", Vector2(1050, 151), Vector2(355, 42), 13, GOLD)
	area_hint = _label("", Vector2(32, 191), Vector2(1370, 42), 13, MUTED)
	area_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	area_hint.clip_text = true
	context_label = _label("", Vector2(32, 739), Vector2(1370, 30), 15, GOLD)
	actor_label = _label("", Vector2(32, 788), Vector2(190, 32), 23, INK)
	role_label = _label("", Vector2(32, 828), Vector2(300, 22), 13, MUTED)
	stats_label = _label("", Vector2(250, 786), Vector2(480, 48), 14, INK)
	search_button = _button("按住搜索 E", Vector2(760, 784), Vector2(160, 42), func(): pass)
	search_button.button_down.connect(func():
		if game.has_method("neighborhood_snapshot") and not game.neighborhood.nearby(game).is_empty() and game.expedition.interior.nearby(game.expedition)<0:game.neighborhood_view.open_at(game.neighborhood.nearby(game))
		else:search_held=true)
	search_button.button_up.connect(func(): search_held = false)
	attack_button = _button("推搡 J", Vector2(930, 784), Vector2(150, 42), game.expedition_attack)
	medicine_button = _button("急救 R", Vector2(1090, 784), Vector2(100, 42), game.expedition_medicine)
	drink_button = _button("饮水 B", Vector2(1200, 784), Vector2(100, 42), func(): game.people.drink(game, game.selected_id))
	bag_button = _button("背包 I", Vector2(1310, 784), Vector2(100, 42), toggle_bag)
	retreat_button = _button("回入口撤退 T", Vector2(1180, 841), Vector2(230, 38), game.expedition_retreat)
	feedback_label = _label("", Vector2(350, 838), Vector2(810, 43), 14, GOLD)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.clip_text = true
	feedback_label.mouse_filter = Control.MOUSE_FILTER_PASS
	log_label = _label("", Vector2(32, 879), Vector2(1300, 20), 11, MUTED)
	search_bar = ProgressBar.new()
	search_bar.show_percentage = false
	search_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_bar.position = Vector2(760, 831)
	var background := _box(Color("2b3838"), Color("2b3838"))
	var fill := _box(GOLD, GOLD)
	background.set_content_margin_all(0)
	fill.set_content_margin_all(0)
	search_bar.add_theme_stylebox_override("background", background)
	search_bar.add_theme_stylebox_override("fill", fill)
	hud.add_child(search_bar)
	search_bar.size = Vector2(320, 5)
	var start := hud.get_child_count()
	var panel := Panel.new()
	panel.position = Vector2(1065, 244)
	panel.size = Vector2(345, 478)
	panel.add_theme_stylebox_override("panel", _box(Color("172321"), GOLD))
	hud.add_child(panel)
	capacity_label = _label("", Vector2(1085, 265), Vector2(280, 28), 19, GOLD)
	_button("×", Vector2(1364, 256), Vector2(30, 32), toggle_bag, true)
	_label("点击一行丢弃1份，无法拾回。", Vector2(1085, 303), Vector2(300, 24), 13, MUTED)
	var row := 0
	for resource in ShelterInventory.NAMES:
		var button := _button("", Vector2(1085, 343 + row * 43), Vector2(300, 36), game.expedition_drop.bind(resource), true)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		drop_buttons[resource] = button
		row += 1
	_label("回到最左侧入口才可入库。", Vector2(1085, 675), Vector2(300, 24), 13, MUTED)
	for index in range(start, hud.get_child_count()):
		var node: Control = hud.get_child(index)
		node.hide()
		bag_nodes.append(node)
	if quiet:
		stack_panel = Panel.new()
		stack_panel.position = Vector2(925,205)
		stack_panel.size = Vector2(495,535)
		stack_panel.theme = GameUi.theme()
		stack_panel.add_theme_stylebox_override("panel",GameUi.box())
		hud.add_child(stack_panel)
		stack_capacity = Label.new()
		stack_capacity.position = Vector2(20,18); stack_capacity.size = Vector2(390,32)
		stack_capacity.add_theme_font_size_override("font_size",23)
		stack_panel.add_child(stack_capacity)
		var close := Button.new()
		close.text = "×"; close.position = Vector2(435,16); close.size = Vector2(42,36)
		GameUi.button(close); close.pressed.connect(toggle_bag); stack_panel.add_child(close)
		stack_grid = BackpackGrid.new(); stack_grid.position = Vector2(20,68)
		stack_grid.resource_hint = "点击丢弃1份，无法拾回"
		stack_grid.activated = func(entry: Dictionary,_count: int):
			if entry["kind"] == "resource": game.expedition_drop(entry["key"])
		stack_grid.available = func(entry: Dictionary): return entry["kind"] == "resource"
		stack_panel.add_child(stack_grid)
		var hint := Label.new()
		hint.text = "点击丢弃1份 · 此处无法拾回"
		hint.position = Vector2(20,467); hint.size = Vector2(450,30)
		stack_panel.add_child(hint)
		stack_panel.hide()
		decoy_button = _button("\n诱饵 G",Vector2(934,816),Vector2(104,62),game.expedition_decoy)
		decoy_button.draw.connect(func():
			var at := Vector2(52,19)
			decoy_button.draw_circle(at,5,GOLD)
			for r in [10,16]: decoy_button.draw_arc(at,r,-.9,.9,14,GOLD,1.5,true)
		)
		equipment_name = _label("",Vector2(350,788),Vector2(340,23),15,GOLD)
		for index in range(3):
			var button := _button("",Vector2(350+index*76,817),Vector2(66,60),show_equipment)
			button.draw.connect(_equipment_icon.bind(button,index))
			equipment_buttons.append(button)
		equipment_dialog = AcceptDialog.new()
		equipment_dialog.title = "随身装备"
		equipment_dialog.min_size = Vector2i(620,240)
		var theme := GameUi.theme()
		theme.default_font = FONT
		theme.default_font_size = 18
		equipment_dialog.theme = theme
		equipment_dialog.ok_button_text = "继续探索"
		equipment_dialog.confirmed.connect(close_equipment)
		equipment_dialog.canceled.connect(close_equipment)
		add_child(equipment_dialog)
		for entry in [[search_button,"search"],[attack_button,"attack"],[medicine_button,"medicine"],[drink_button,"water"],[bag_button,"bag"],[retreat_button,"exit"]]:
			entry[0].draw.connect(_action_icon.bind(entry[0],entry[1]))
	layer.visible = false
	visible = false


func _box(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.set_content_margin_all(8)
	return box


func _label(text: String, position_at: Vector2, extent: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position_at
	label.size = extent
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(label)
	return label


func _button(text: String, at: Vector2, extent: Vector2, action: Callable, compact: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 12 if compact else 14)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("566861"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := _box(Color("20302d") if state in ["hover", "pressed"] else Color("182626"), GOLD if state in ["hover", "pressed"] else Color("33413b"))
		if compact:
			box.content_margin_top = 2
			box.content_margin_bottom = 2
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(action)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hud.add_child(button)
	button.size = extent
	return button


func _process(delta: float) -> void:
	if not game.paused:
		hurt_time = maxf(0, hurt_time - delta)
		impact_time = maxf(0, impact_time - delta)
		combat_effects.step(delta)
	visible = game.expedition.active
	layer.visible = visible
	if not visible:
		search_held = false
		return
	refresh()
	queue_redraw()


func refresh() -> void:
	var state: ExpeditionState = game.expedition
	if not state.active:
		return
	_sync_combat_effects(state)
	var actor: Survivor = game.survivors[state.actor_id]
	if last_attempt != state.attempts or last_actor != state.actor_id or last_health < 0:
		last_attempt = state.attempts
		last_actor = state.actor_id
		last_health = actor.health
	if actor.health < last_health - 0.1:
		damage_amount = ceili(last_health - actor.health)
		hurt_time = 0.4
	last_health = actor.health
	if quiet:
		_refresh_quiet(state,actor)
		return
	title_label.text = "%s  /  第 %d 次外出" % [state.area()["name"], state.attempts]
	area_hint.text = "%s  /  %s · %s" % [state.area()["summary"], state.weather()["name"], state.weather()["hint"]]
	var alert := 0.0
	for enemy in state.enemies:
		if enemy["hp"] > 0: alert = maxf(alert, float(enemy["suspicion"]))
	alert_label.text = "噪声 %d  /  警觉 %d  /  %s" % [int(state.noise), int(alert), "藏身中" if state.in_cover() else "潜行" if state.sneaking else "暴露"]
	actor_label.text = actor.display_name
	role_label.text = "搜寻者 · 搜索+20% / 脚步声−20%" if actor.speciality == "搜寻者" else actor.speciality + " / 单人实时探索"
	stats_label.text = "生命%d · 饱腹%d · 精神%d\n水分%d · 伤势%d · 感染%d" % [Vitals.value(actor,"health"),Vitals.value(actor,"fullness"),Vitals.value(actor,"vigor"),Vitals.value(actor,"hydration"),roundi(actor.injury),roundi(actor.infection)]
	gear_label.visible = actor.metabolism < 1
	if actor.metabolism < 1:
		stats_label.text = "生命%d · 饱腹%d · 精神%d · 水分%d\n伤%d · 感染%d · 疾病%d · 寒冷%d" % [Vitals.value(actor,"health"),Vitals.value(actor,"fullness"),Vitals.value(actor,"vigor"),Vitals.value(actor,"hydration"), roundi(actor.injury), roundi(actor.infection), roundi(actor.illness), roundi(actor.cold_exposure)]
		gear_label.text = "%s · 耐久%d%s\n室外%d℃ · 保暖+%d℃%s" % [actor.weapon().get("name", "徒手"), actor.weapon_item.get("durability", 0), " · 弹匣%d+%d" % [state.magazine, state.reserve_ammo] if actor.weapon().has("magazine") else "", game.expansion.outside(game), actor.warmth(), " · 换弹中" if state.reload_remaining > 0 else ""]
	stats_label.add_theme_color_override("font_color", Color("dca184") if actor.health < 40 or actor.infection >= 30 else MUTED)
	for node in bag_nodes: node.visible = bag_open
	bag_button.text = "%d/%d I" % [state.used_capacity(), state.capacity]
	capacity_label.text = "背包 %d / %d" % [state.used_capacity(), state.capacity]
	for resource in drop_buttons:
		drop_buttons[resource].text = "%s   %d                           −1" % [ShelterInventory.NAMES[resource], state.bag[resource]]
		drop_buttons[resource].disabled = state.bag[resource] <= 0
	search_bar.value = state.search_progress / state.search_duration * 100 if state.search_duration > 0 else 0
	retreat_button.disabled = false if quiet else game.paused
	search_button.disabled = game.paused
	attack_button.disabled = game.paused or state.attack_cooldown > 0 or state.climb_target != -1
	attack_button.text = (actor.weapon().get("name", "徒手推搡") + " J") if actor.metabolism < 1 else ("工具挥击 J" if state.bag["tools"] > 0 else "徒手推搡 J")
	if state.attack_cooldown > 0: attack_button.text = "冷却 %.1f" % state.attack_cooldown
	attack_button.tooltip_text = (GearCatalog.describe(actor.weapon_item["kind"]) + "；L换弹" if not actor.weapon().is_empty() else "徒手只推开，工具用于破锁和制作。") if actor.metabolism < 1 else "有工具：消耗1件，命中造成40伤害。徒手：只推开、不扣生命。面向敌人，75范围内生效；前摇0.2秒，冷却1.1秒。"
	drink_button.disabled = game.paused or state.bag["water"] <= 0 or actor.person.thirst <= 0
	medicine_button.disabled = game.paused or state.bag["medicine"] <= 0 or state.medicine_cooldown > 0
	retreat_button.text = "撤退并带回物资 [T]" if state.floor_level == 0 and state.player_x <= 145 else "回入口撤退 [T]"
	feedback_label.text = state.feedback
	feedback_label.tooltip_text = state.feedback
	var index := state.nearby_site()
	context_label.text = "%s  /  按住 E 搜索，剩余：%s" % [state.site_definitions()[index]["name"], ShelterInventory.describe(state.sites[index]["contents"])] if index >= 0 else "← 最左侧为撤退入口  /  靠近容器搜索；梯子旁 W/S 上下楼"
	log_label.text = "A/D 移动 · Ctrl 潜行 · Shift 奔跑 · W/S 梯子 · J 挥击 · I 背包 · 空格暂停"
	var route := "先回梯子下楼，再向左" if state.floor_level != 0 else "向左返回"
	area_hint.text += "  /  %s · 入口约%d步" % [route, ceili(maxf(0, state.player_x - 145) / 10)]
	area_hint.tooltip_text = area_hint.text


func _camera() -> float:
	return clampf(game.expedition.player_x - 500, 0, float(game.expedition.area()["width"]) - 1060)


func _rect_world(rect: Rect2, color: Color) -> void:
	var translated := Rect2(rect.position - Vector2(_camera(), 0), rect.size)
	var clip := translated.intersection(Rect2(0, 264, 1070, 420))
	if clip.has_area(): draw_rect(clip, color)


func _text(point: Vector2, text: String, size: int = 12, color: Color = MUTED) -> void:
	if point.x > 20 and point.x < 1010:
		draw_string(FONT, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw() -> void:
	if not is_instance_valid(game) or not game.expedition.active:
		return
	var state: ExpeditionState = game.expedition
	var camera := _camera()
	draw_set_transform(game.world_offset()+combat_effects.shake(), 0, game.world_scale())
	var accent := Color(str(state.area()["accent"]))
	if quiet:
		game.scene_art.expedition(self,state,camera)
	else:
		draw_rect(Rect2(0, 210, 1095, 490), Color("142126"))
		for index in range(18):
			var x := fposmod(index * 107.0 - camera * 0.22, 1150) - 50
			draw_rect(Rect2(x, 305 + index % 3 * 22, 80, 322), Color("1b2b2e"))
		var upper := state.upper_left()
		var width: float = state.area()["width"]
		var wall := Color(str(state.area()["color"]))
		# Each place has its own floor access, props, patrols and resource layout.
		_rect_world(Rect2(160, 429, 850, 192), Color("2b3430"))
		_rect_world(Rect2(upper, 285, width - upper - 120, 335), wall)
		for x in [215, 430, 670, 890, 1300, 1560, 1810, 2060, 2340]:
			_rect_world(Rect2(x, 452 if x < 1000 else 305, 70, 64), Color("52615b"))
			_rect_world(Rect2(x + 4, 456 if x < 1000 else 309, 62, 56), Color("1a2c32"))
			_rect_world(Rect2(x + 32, 452 if x < 1000 else 305, 4, 64), Color("607064"))
		_rect_world(Rect2(upper, 400, width - upper - 120, 12), wall.lightened(0.20))
		_rect_world(Rect2(0, 620, width, 14), Color("535d50"))
		for y in range(408, 620, 18):
			_rect_world(Rect2(state.ladder_x() - 12, y, 24, 4), Color("a9af98"))
		_rect_world(Rect2(state.ladder_x() - 14, 400, 3, 220), Color("9da891"))
		_rect_world(Rect2(state.ladder_x() + 12, 400, 3, 220), Color("9da891"))
	if not quiet: _text(Vector2(145 - camera, 660), "← 入口 · E/T 撤退", 14, GOLD)
	_draw_exit(-1,state,camera)
	if quiet: _draw_exit(1,state,camera)
	if not quiet: _draw_landmarks(state,camera,accent)
	else: _draw_route(state,camera)
	if quiet: _draw_district(state,camera)
	_draw_decoys(state,camera)
	for index in range(state.site_definitions().size()):
		if quiet: _draw_site(index,state,camera)
		else:
			var definition: Dictionary = state.site_definitions()[index]
			var point := Vector2(float(definition["x"])-camera,ExpeditionState.FLOOR_Y[int(definition["floor"])])
			if point.x < 0 or point.x > 1065: continue
			var empty := not state.site_has_supplies(index)
			draw_rect(Rect2(point+Vector2(-22,-38),Vector2(44,38)),Color("454545") if empty else accent.darkened(0.2))
			draw_rect(Rect2(point+Vector2(-18,-34),Vector2(36,30)),Color("646464") if empty else accent,false,2)
			if state.sites[index]["locked"]: draw_circle(point+Vector2(0,-23),6,Color("d8c28c"))
			_text(point+Vector2(-47,27),definition["name"]+(" · 空" if empty else ""),12,MUTED if empty else GOLD)
	if quiet: _draw_intent(state,camera)
	if game.has_method("neighborhood_snapshot") and is_instance_valid(game.neighborhood_view):game.neighborhood_view.draw_field(self,camera)
	combat_effects.draw_marks(self,camera)
	if state.environment_active: state.interior.draw(self,state,camera)
	for enemy_index in range(state.enemies.size()):
		_draw_enemy(state.enemies[enemy_index], camera, state, enemy_index)
	var actor: Survivor = game.survivors[state.actor_id]
	_draw_player(Vector2(state.player_x - camera, state.player_y), actor, state)
	for cover in state.area()["covers"]:
		var bottom: float = ExpeditionState.FLOOR_Y[int(cover[2])]
		MapScenery.cover(self,Vector2(float(cover[0])-camera,bottom),float(cover[1])-float(cover[0]),state.location_id)
	if state.attack_windup > 0 or (state.attack_cooldown > maxf(0, float(actor.weapon().get("cooldown", 1.1)) - 0.34)):
		var swing := Vector2(state.player_x - camera, state.player_y - 38)
		if swing.x >= 0 and swing.x <= 1065 and not actor.weapon().has("magazine") and actor.weapon_item.get("kind", "") != "spear" and combat_effects.player_time <= 0:
			var angle := 0.0 if state.facing > 0 else PI
			var windup := state.attack_windup > 0
			var color := Color("cba96b") if windup else Color("f1dfb3")
			draw_arc(swing, minf(92, float(actor.weapon().get("reach", 72))*0.7), angle - 0.85, angle + 0.85, 24, Color(color, 0.2) if windup else Color(color,0.55), 1.5 if windup else 2, true)
	combat_effects.draw_particles(self,camera)
	_draw_weather(state)
	if SurvivalRules.is_night(game.simulation_time):
		draw_rect(Rect2(0, 264, 1070, 420), Color(0, 0.02, 0.04, 0.10))

	if hurt_time > 0:
		draw_rect(Rect2(0, 264, 1070, 420), Color(0.75, 0.20, 0.12, hurt_time * 0.5))
		_text(Vector2(clampf(state.player_x - camera - 35, 55, 960), state.player_y - 116), "受伤 −%d" % damage_amount, 19, Color("edaf93"))
	_draw_impact(camera)
	draw_set_transform(Vector2.ZERO)
	if quiet: return
	draw_rect(Rect2(0, 0, 1440, 143), Color("101a1e"))
	draw_rect(Rect2(0, 772, 1440, 128), Color("101a1e"))
	draw_rect(Rect2(32, 822, 180, 5), Color("34433c"))
	draw_rect(Rect2(32, 822, 180 * actor.health / 100, 5), Color("dca184") if actor.health < 40 else Color("91ac9d"))
	if game.paused:
		draw_style_box(_box(Color("25322d"), GOLD), Rect2(580, 245, 280, 42))
		draw_string(FONT, Vector2(605, 272), "已暂停 · 空格继续", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, GOLD)


func reset_feedback() -> void:
	last_health = -1
	last_attempt = -1
	last_actor = -1
	hurt_time = 0
	impact_time = 0
	bag_open = false
	combat_effects.clear()
	effects_location = ""
	effects_attempt = -1


func _sync_combat_effects(state: ExpeditionState) -> void:
	if state.location_id != effects_location or state.attempts != effects_attempt:
		combat_effects.clear()
		effects_location = state.location_id
		effects_attempt = state.attempts


func _on_enemy_damaged(index: int, point: Vector2, direction: float, damage: int, lethal: bool, field: ExpeditionState) -> void:
	if field != game.expedition or damage <= 0: return
	_sync_combat_effects(field)
	combat_effects.hit(index,point,direction,damage,lethal)
	queue_redraw()


func _on_player_hurt(point: Vector2, direction: float, damage: int, field: ExpeditionState) -> void:
	if field != game.expedition: return
	_sync_combat_effects(field)
	combat_effects.hurt(point,direction)
	hurt_time = 0.4
	damage_amount = damage
	queue_redraw()


func _draw_enemy(enemy: Dictionary, camera: float, state: ExpeditionState, index: int) -> void:
	if state.environment_active and not state.interior.visible(state,float(enemy["x"]),int(enemy["floor"])): return
	var point := Vector2(float(enemy["x"])-camera,state.enemy_y(enemy))
	if point.x < -100 or point.x > 1160: return
	var stationary: bool = state.environment_active and state.interior.enabled and (not state.minds[index]["search"].is_empty() and state.minds[index]["search"]["wait"]>0)
	combat_effects.draw_enemy(self,enemy,index,point,state.elapsed,stationary)
	if enemy["hp"] <= 0: return
	var definition := EnemyCatalog.stats(enemy["kind"])
	var direction: float = enemy["direction"]
	var reach := maxf(55,(52.0 if state.in_cover() else 115.0 if state.sneaking else 290.0)*float(state.weather()["vision"]))
	if int(enemy["climb_target"]) == -1: draw_colored_polygon(PackedVector2Array([point+Vector2(0,-50),point+Vector2(direction*reach,-85),point+Vector2(direction*reach,-5)]),Color(0.75,0.36,0.25,0.055))
	var scale: float = definition["scale"]
	var width := 62.0*scale
	var bar := point+Vector2(-width/2,-105*scale)
	draw_rect(Rect2(bar,Vector2(width,7)),Color("18232a"))
	draw_rect(Rect2(bar,Vector2(width*float(enemy["hp"])/float(definition["health"]),7)),Color("de8a7b"))
	if enemy["kind"] == "brute":
		for value in [30.0,60.0]: draw_line(bar+Vector2(width*value/90,0),bar+Vector2(width*value/90,7),Color("283631"),1,true)
	if enemy["suspicion"] > 0: draw_rect(Rect2(bar+Vector2(0,13),Vector2(width*float(enemy["suspicion"])/100,3)),GOLD)
	var mouse: Vector2 = (get_viewport().get_mouse_position()-game.world_offset())/game.world_scale()
	if not quiet or Rect2(point+Vector2(-40,-145),Vector2(80,145)).has_point(mouse): _text(bar+Vector2(0,-8),"%s %d/%d" % [EnemyMind.label(state,index) if state.environment_active and state.interior.enabled else definition["name"],enemy["hp"],definition["health"]],14,GameUi.TEXT)
	if state.environment_active and state.interior.enabled:
		var role: int = state.minds[index]["role"]
		if role == 0: draw_line(point+Vector2(-9,-73)*scale,point+Vector2(10,-73)*scale,Color("32333d"),5,true)
		elif role == 1:
			for x in [-11,11]: draw_arc(point+Vector2(x,-67)*scale,4,0,TAU,15,Color("b7b99a"),2,true)
		elif role == 2:
			draw_line(point+Vector2(-7,-55)*scale,point+Vector2(8,-55)*scale,Color("a65b4b"),4,true)
			if state.minds[index]["call"]>12: draw_arc(point+Vector2(0,-60),40+(14-float(state.minds[index]["call"]))*45,0,TAU,40,Color(.8,.5,.3,.4),2,true)
		else: draw_rect(Rect2(point+Vector2(-22,-58)*scale,Vector2(12,28)*scale),Color("8d7e5d"))
	if enemy["mode"] == "windup": draw_arc(point+Vector2(0,-35*scale),42*scale,-PI/2,PI/2 if direction > 0 else PI*1.5,30,GameUi.WARNING,3,true)


func _draw_player(point: Vector2, actor: Survivor, state: ExpeditionState) -> void:
	var crouch := 20.0 if state.sneaking else 0.0
	var context:=CharacterMotion.field_context(state,actor,combat_effects.player_time)
	if game.has_method("neighborhood_snapshot") and not game.neighborhood.work.is_empty() and combat_effects.player_time<=0:
		var job:Dictionary=game.neighborhood.work
		context={"mode":"aid" if job["id"]=="rescue" else "search","progress":float(job["elapsed"])/float(NeighborhoodSystem.ACTIONS[job["id"]]["seconds"]),"tool":false}
	var tint:=actor.tint.lightened(.35) if state.invulnerable>0 and int(state.elapsed*12)%2 else actor.tint
	if combat_effects.player_time>.24:tint=tint.lerp(Color('f2ad9a'),.7)
	var pose:=CharacterMotion.pose(context['mode'],state.elapsed,context['progress'],state.facing,str(actor.weapon_item.get('kind','')))
	pose['tool']=context.get('tool',false)
	CharacterMotion.draw(self,point,actor,pose,true,tint,Transform2D(0.0,game.world_scale(),0.0,game.world_offset()+combat_effects.shake()))
	if quiet:
		var ring:=PackedVector2Array()
		for i in range(33):ring.append(point+Vector2(cos(i*TAU/32)*20,sin(i*TAU/32)*5-2))
		draw_polyline(ring,Color('b8a781'),1,true)
	else:draw_arc(point+Vector2(0,-3),23,0,TAU,40,GOLD,1,true)
	draw_rect(Rect2(point + Vector2(-26, -111 + crouch), Vector2(52, 5)), Color("21332e"))
	draw_rect(Rect2(point + Vector2(-26, -111 + crouch), Vector2(52 * actor.health / 100, 5)), Color("9ab997"))
	draw_colored_polygon(PackedVector2Array([point + Vector2(-5, -89 + crouch), point + Vector2(5, -89 + crouch), point + Vector2(0, -83 + crouch)]), GOLD)


func _draw_exit(side: int, state: ExpeditionState, camera: float) -> void:
	var x := 90.0 if side < 0 else state.right_edge(0)
	var ready := state.exit_side() == side
	var color := Color("bed7be") if ready else Color("778d80")
	_rect_world(Rect2(x-23,535,46,85),Color("344b41"))
	_rect_world(Rect2(x-18,540,36,76),Color("142b29"))
	var at := Vector2(x-camera,570)
	draw_rect(Rect2(at+Vector2(-18,-30),Vector2(36,76)),color,false,2 if ready else 1)
	draw_line(at+Vector2(-side*12,0),at+Vector2(side*18,0),color,3,true)
	draw_line(at+Vector2(side*8,-9),at+Vector2(side*18,0),color,3,true)
	draw_line(at+Vector2(side*8,9),at+Vector2(side*18,0),color,3,true)


func _equipment_icon(button: Button, index: int) -> void:
	if not game.expedition.active: return
	var slot := EquipmentArt.slots(game.survivors[game.expedition.actor_id])[index]
	EquipmentArt.icon(button,slot,Vector2(33,24))
	button.draw_rect(Rect2(8,49,50,4),Color("34433c"))
	if not slot["kind"].is_empty():
		button.draw_rect(Rect2(8,49,50*slot["ratio"],4),Color("df9c7c") if slot["ratio"] <= 0.25 else Color("aac2a2"))


func _equipment_description(slot: Dictionary) -> String:
	if slot["kind"].is_empty(): return slot["name"]+(" · 只能推开敌人" if slot["slot"] == "weapon" else "")
	return "%s · 耐久%d/%d%s\n%s" % [slot["name"],slot["durability"],slot["maximum"]," · 已损坏，效果失效" if slot["broken"] else "",GearCatalog.describe(slot["kind"])]


func show_equipment() -> void:
	if not quiet or not game.expedition.active or equipment_dialog.visible or game.departure_dialog.visible: return
	var lines := PackedStringArray()
	for slot in EquipmentArt.slots(game.survivors[game.expedition.actor_id]): lines.append(_equipment_description(slot))
	lines.append("装备在白天或出发前的K页调整。")
	equipment_dialog.dialog_text = "\n\n".join(lines)
	_equipment_pause_before = game.paused
	_equipment_opened = true
	game.paused = true
	search_held = false
	equipment_dialog.popup_centered()
	game._refresh_hud()


func close_equipment() -> void:
	if not _equipment_opened: return
	get_viewport().set_input_as_handled()
	_equipment_opened = false
	equipment_dialog.hide()
	game.paused = _equipment_pause_before or game.game_over
	game._refresh_hud()


func _draw_landmarks(state: ExpeditionState, camera: float, accent: Color) -> void:
	if not quiet: _text(Vector2(230 - camera, 415), str(state.area()["name"]), 22, accent)
	if state.location_id == "clinic":
		_rect_world(Rect2(1080, 302, 55, 15), accent)
		_rect_world(Rect2(1100, 282, 15, 55), accent)
		for x in [1580, 2110]:
			_rect_world(Rect2(x, 365, 90, 10), Color("a5b6af"))
			_rect_world(Rect2(x + 5, 375, 5, 25), Color("819b99"))
			_rect_world(Rect2(x + 80, 375, 5, 25), Color("819b99"))
	elif state.location_id == "works":
		for x in [690, 1510, 2270, 2800]:
			_rect_world(Rect2(x, 440, 28, 180), Color("535448"))
			_rect_world(Rect2(x - 12, 434, 52, 8), accent.darkened(0.2))
		for x in [1850, 2400]:
			_rect_world(Rect2(x, 565, 55, 55), Color("6d604a"))
			_rect_world(Rect2(x, 578, 55, 5), accent.darkened(0.3))
	elif state.location_id == "market":
		for x in [560, 980, 1430, 2310]:
			_rect_world(Rect2(x, 500, 130, 17), accent)
			_rect_world(Rect2(x + 8, 517, 6, 103), accent.darkened(0.4))
			_rect_world(Rect2(x + 116, 517, 6, 103), accent.darkened(0.4))
			_rect_world(Rect2(x, 590, 130, 30), Color("5b6347"))
	elif state.location_id == "waterworks":
		for x in [600, 1850, 2800]:
			_rect_world(Rect2(x, 480, 120, 140), Color("526f6d"))
			_rect_world(Rect2(x + 30, 450, 24, 170), accent.darkened(0.2))
			_rect_world(Rect2(x - 100, 450, 160, 14), accent.darkened(0.2))
	elif state.location_id == "depot":
		for x in [650, 1460, 2950]:
			_rect_world(Rect2(x, 515, 280, 85), Color("6e5d4c"))
			_rect_world(Rect2(x + 15, 530, 245, 6), accent)
			_rect_world(Rect2(x + 30, 600, 38, 20), Color("202b2d"))
			_rect_world(Rect2(x + 205, 600, 38, 20), Color("202b2d"))
	elif state.location_id == "broadcast":
		for height in range(8):
			var point := Vector2(2800 - camera, 380 - height * 36)
			var half_width := 65 - height * 6
			draw_line(point + Vector2(-half_width, 0), point + Vector2(half_width - 5, -36), accent, 3, true)
			draw_line(point + Vector2(half_width, 0), point + Vector2(-half_width + 5, -36), accent, 3, true)
		_rect_world(Rect2(2750, 75, 100, 4), accent.lightened(0.2))
	elif state.location_id == "evac":
		for x in [550, 1640, 2830, 3620]:
			_rect_world(Rect2(x, 540, 12, 80), accent)
			_rect_world(Rect2(x + 145, 540, 12, 80), accent)
			_rect_world(Rect2(x, 550, 157, 5), accent.darkened(0.2))
		_rect_world(Rect2(700, 650, 3200, 25), Color("274b55"))
	elif state.location_id == "residential":
		for x in [710, 1180, 1690, 2040]:
			_rect_world(Rect2(x, 366, 90, 14), Color("96a39b"))
			_rect_world(Rect2(x + 6, 380, 5, 20), accent)
			_rect_world(Rect2(x + 78, 380, 5, 20), accent)

	else:
		for x in [590, 1770]:
			_rect_world(Rect2(x, 450, 95, 18), accent.darkened(0.25))
			_rect_world(Rect2(x + 10, 468, 75, 6), accent.darkened(0.5))


func _draw_weather(state: ExpeditionState) -> void:
	var phase: float = game.weather_time
	if game.has_method("expansion_snapshot") and game.expansion.outside(game) < 0:
		for index in range(35):
			var point := Vector2(fposmod(index * 97.0 - phase * 17, 1080), 260 + fposmod(index * 73.0 + phase * 35, 405))
			draw_circle(point, 1.5, Color(0.8, 0.87, 0.9, 0.3))
		return
	match state.last_refresh_day % 4:
		2:
			for index in range(45):
				var x := fposmod(index * 97.0 - phase * 45, 1050)
				var y := 270 + fposmod(index * 73.0 + phase * 180, 395)
				draw_line(Vector2(x, y), Vector2(x - 4, y + 13), Color(0.65, 0.77, 0.80, 0.18), 1, true)
		3:
			for band in range(5):
				draw_rect(Rect2(0, 300 + band * 65, 1070, 54), Color(0.64, 0.72, 0.70, 0.07))
		0:
			for index in range(12):
				var x := fposmod(index * 191.0 + phase * 150, 1050)
				var y := 330 + index % 5 * 60
				draw_line(Vector2(x, y), Vector2(minf(1060, x + 22), y - 3), Color(0.68, 0.67, 0.53, 0.16), 1, true)


func toggle_bag() -> void:
	bag_open = not bag_open
	refresh()


func _on_combat_resolved(kind: String, point: Vector2, damage: int) -> void:
	impact_kind = kind
	impact_point = point
	impact_damage = damage
	impact_time = 1.0
	if is_instance_valid(game.game_audio): game.game_audio.combat_cue("shot" if kind in ["blocked_shot","shot_miss"] else "blocked" if kind == "obstructed" else kind)
	queue_redraw()


func _draw_impact(camera: float) -> void:
	if impact_time <= 0: return
	var point := impact_point - Vector2(camera, 0)
	var color := Color("f1d4a0") if impact_kind in ["hit", "shot", "push"] else Color("b5b9aa")
	var text: String = {"shot": "−%d" % impact_damage if quiet else "射中 −%d" % impact_damage, "hit": "−%d" % impact_damage if quiet else "命中 −%d" % impact_damage, "push": "推开 · 0伤害", "miss": "挥空", "blocked": "稳身 · 推不动", "blocked_shot": "", "obstructed": ""}.get(impact_kind, "")
	_text(Vector2(clampf(point.x - (18 if quiet else 140), 30, 810), maxf(270, point.y - 100 - (1 - impact_time) * 20)), text, 20, Color(color, minf(1, impact_time * 3)))
	if impact_time > 0.9 and impact_kind in ["shot","blocked_shot","shot_miss"]:
		var muzzle := Vector2(game.expedition.player_x-camera+game.expedition.facing*46,game.expedition.player_y-(38 if game.expedition.sneaking else 58))
		if (point.x-muzzle.x)*game.expedition.facing >= 0:
			draw_line(muzzle,point,Color("eacb92"),2,true)
		for i in range(0 if (point.x-muzzle.x)*game.expedition.facing < 0 else 3):
			var ray: Vector2 = Vector2.from_angle(-0.55+i*0.55)*game.expedition.facing
			draw_line(muzzle,muzzle+ray*10,Color("f5dca4"),2,true)
		if impact_kind == "blocked_shot":
			for i in range(5): draw_line(point,point+Vector2.from_angle(i*TAU/5)*9,Color("e8c997"),1.5,true)
	elif impact_time > 0.8 and impact_kind == "obstructed":
		draw_arc(point,10,PI*0.8,PI*2.2,16,GameUi.WARNING,2,true)
	elif impact_time > 0.9 and impact_kind == "hit":
		draw_line(point+Vector2(-7,6),point+Vector2(7,-6),Color("f2c9b2"),2,true)
	elif impact_time > 0.8 and impact_kind == "push":
		draw_arc(point,16,0,TAU,20,Color("c1c9bb"),2,true)


func _action_icon(button: Button, kind: String) -> void:
	if kind == "attack" and quiet and game.expedition.active:
		EquipmentArt.icon(button,EquipmentArt.slots(game.survivors[game.expedition.actor_id])[0],Vector2(button.size.x/2,19))
		return
	HudIcons.draw(button,kind,Vector2(button.size.x/2,19),19,Color("a5ac98") if button.disabled else GOLD)


func _refresh_quiet(state: ExpeditionState, actor: Survivor) -> void:
	decoy_button.disabled = game.paused or state.climb_target != -1 or state.lure_cooldown > 0 or state.decoys.size() >= 3 or state.bag["materials"] < 1 or state.bag["fuel"] < 1
	decoy_button.tooltip_text = "发声诱饵 G · 背包材料1、燃料1 · 向前投掷，发声18秒。敌人看到或听到你仍会追击。"
	decoy_button.queue_redraw()
	var slots := EquipmentArt.slots(actor)
	equipment_name.text = slots[0]["name"]+(" · 损坏" if slots[0]["broken"] else "")
	for index in range(3):
		equipment_buttons[index].tooltip_text = _equipment_description(slots[index])+"\n点击查看随身装备"
		equipment_buttons[index].queue_redraw()
	for label in [title_label,area_hint,alert_label,gear_label,actor_label,role_label,stats_label,log_label,context_label,feedback_label]: label.hide()
	for node in bag_nodes: node.hide()
	stack_panel.visible = bag_open
	if bag_open:
		stack_capacity.text = "背包 %d / %d格" % [state.used_capacity(),state.capacity]
		stack_grid.render(BackpackStacks.carried(state,actor,game.expansion.carried),state.capacity)
	search_bar.value = state.search_progress/state.search_duration*100 if state.search_duration > 0 else 0
	retreat_button.disabled = false if quiet else game.paused
	search_button.disabled = game.paused or (state.nearby_site() < 0 and not state.route_in_range() and game.neighborhood.nearby(game).is_empty()) or game.cycle.return_requested or game.cycle.phase == "returning"
	attack_button.disabled = game.paused or state.attack_cooldown > 0 or state.climb_target != -1 or state.reload_remaining > 0
	drink_button.disabled = game.paused or state.bag["water"] <= 0 or actor.person.thirst <= 0
	medicine_button.disabled = game.paused or state.bag["medicine"] <= 0 or state.medicine_cooldown > 0
	var actions := [search_button,attack_button,medicine_button,drink_button,bag_button,retreat_button]
	var keys := ["E","J","R","B","I","T"]
	var hints := ["按住搜索 E",actor.weapon().get("name","徒手推搡")+" J · "+("L换弹" if actor.weapon().has("magazine") else "攻击"),"背包用药 R","背包饮水 B","背包 I","回入口撤退 T"]
	for action_index in range(actions.size()):
		var button: Button = actions[action_index]
		button.position = Vector2(1060+action_index*58,816)
		button.size = Vector2(50,62)
		button.text = "\n"+keys[action_index]
		button.tooltip_text = hints[action_index]
	retreat_button.size = Vector2(82,62)
	retreat_button.text = "\n返程 T"
	retreat_button.tooltip_text = "沿实际路线回到左侧出口，确认后离开；再次按T或移动取消。也可自行走到右侧出口离开。"
	search_bar.visible = state.search_index >= 0 and state.site_in_range(state.search_index) and not game._loot_open
	if search_bar.visible:
		var definition: Dictionary = state.site_definitions()[state.search_index]
		var point := Vector2(float(definition["x"])-_camera(),ExpeditionState.FLOOR_Y[int(definition["floor"])])-Vector2(55,61)
		search_bar.position = game.world_offset()+point*game.world_scale()-Vector2(48,0)
		search_bar.size = Vector2(96,7)
	retreat_button.modulate = InteractionFeedback.READY if game.cycle.return_requested or game.cycle.phase == "returning" else Color.WHITE
	bag_button.text = "\n%d/%d" % [state.used_capacity(),state.capacity]
	bag_button.tooltip_text += " · %d/%d格" % [state.used_capacity(),state.capacity]
	attack_button.tooltip_text += "\n耐久%d" % actor.weapon_item.get("durability",0)
	if actor.weapon().has("magazine"):
		attack_button.text = "\n%d/%d" % [state.magazine,state.reserve_ammo]
		attack_button.tooltip_text += "\n弹匣%d / 备用%d" % [state.magazine,state.reserve_ammo]
	if state.reload_remaining > 0: attack_button.text = "\n换弹"
	if not game.neighborhood.nearby(game).is_empty():
		search_button.tooltip_text=NeighborhoodSystem.NODES[game.neighborhood.nearby(game)]["name"]+" · E / 点击物件"
	if state.route_in_range():
		search_button.tooltip_text = LocationEnvironment.route_hint(state.location_id)+"\n按住E或点击通路标记开始；移动取消，松开暂停。"
	if state.route_progress > 0 and state.route_in_range():
		search_bar.visible = true
		search_bar.value = state.route_progress / LocationEnvironment.route_seconds(state.location_id,state.route_tool)*100
		search_bar.position = game.world_offset()+Vector2(state.route_x()-_camera(),516)*game.world_scale()-Vector2(48,0)
		search_bar.size = Vector2(96,7)


	if not game.districts.work.is_empty():
		var w: Dictionary = game.districts.work
		var def: Dictionary = state.site_definitions()[DistrictSystem.POINTS[state.location_id]]
		search_bar.visible = true
		search_bar.value = float(w["elapsed"])/float(DistrictSystem.SECONDS[w["action"]])*100
		search_bar.position = game.world_offset()+Vector2(float(def["x"])-_camera(),ExpeditionState.FLOOR_Y[int(def["floor"])]-102)*game.world_scale()-Vector2(48,0)
		search_bar.size = Vector2(96,7)


func _draw_site(index: int, state: ExpeditionState, camera: float) -> void:
	var room_site: Dictionary = state.site_definitions()[index]
	if state.environment_active and not state.interior.visible(state,float(room_site["x"]),int(room_site["floor"])): return
	var definition: Dictionary = state.site_definitions()[index]
	var world := Vector2(float(definition["x"]),ExpeditionState.FLOOR_Y[int(definition["floor"])])
	var point := world-Vector2(camera,0)
	if point.x < 0 or point.x > 1065: return
	var mouse: Vector2 = (get_viewport().get_mouse_position()-game.world_offset())/game.world_scale()+Vector2(camera,0)
	var hovered: bool = state.site_hit_rect(index).has_point(mouse) and not game._loot_open
	var info := InteractionFeedback.site(game,index,hovered)
	var kind: String = LocationEnvironment.profile(state.location_id)["containers"][index]
	MapScenery.container(self,point,kind,info["body"],info["edge"],not info["supplied"])
	if state.sites[index]["locked"] and info["supplied"]: draw_circle(point+Vector2(0,-23),5,info["edge"])
	if hovered or info["target"]:
		var tint := InteractionFeedback.READY if info["near"] else InteractionFeedback.DISTANT
		draw_rect(Rect2(point+Vector2(-43,-79),Vector2(84,82)),tint,false,1.5)
		var low := maxf(90 if int(definition["floor"]) == 0 else state.upper_left(),world.x-ExpeditionState.INTERACTION_RADIUS)
		var high := minf(state.right_edge(int(definition["floor"])),world.x+ExpeditionState.INTERACTION_RADIUS)
		draw_line(Vector2(low-camera,world.y+5),Vector2(high-camera,world.y+5),Color(tint,0.45),2,true)
		for edge in [low,high]: draw_line(Vector2(edge-camera,world.y+1),Vector2(edge-camera,world.y+9),Color(tint,0.6),1,true)
	var marker := point+Vector2(-55,-83)
	if info["supplied"] or info["pending"] or hovered or info["target"] or info["progress"] > 0:
		var color := InteractionFeedback.READY if info["near"] else InteractionFeedback.DISTANT
		if not info["supplied"] and not info["pending"]: color = InteractionFeedback.EMPTY_EDGE
		draw_circle(marker,14,Color("13201f"))
		draw_arc(marker+Vector2(-2,-2),5,0,TAU,20,color,1.8,true)
		draw_line(marker+Vector2(2,2),marker+Vector2(7,7),color,2.5,true)
		if info["near"]: draw_arc(marker,14,0,TAU,28,color,1.5,true)
	if info["progress"] > 0:
		var searching: bool = not game.paused and info["near"] and (search_held or Input.is_physical_key_pressed(KEY_E))
		var color := InteractionFeedback.READY if searching else InteractionFeedback.DISTANT
		draw_arc(marker,19,-PI/2,-PI/2+TAU*float(info["progress"]),36,color,3,true)
	if info["pending"]:
		draw_colored_polygon(PackedVector2Array([point+Vector2(23,-40),point+Vector2(28,-35),point+Vector2(23,-30),point+Vector2(18,-35)]),Color("91b8c8"))


func _draw_intent(state: ExpeditionState, camera: float) -> void:
	var goal: Vector2
	if game.cycle.return_requested or game.cycle.phase == "returning": goal = Vector2(110,620)
	elif game.interface.has_move_target: goal = Vector2(game.interface.target_x,ExpeditionState.FLOOR_Y[game.interface.target_floor])
	else: return
	var route := InteractionFeedback.route(game,goal)
	for segment in range(1,route.size()):
		var from := route[segment-1]-Vector2(camera,2)
		var to := route[segment]-Vector2(camera,2)
		var distance := from.distance_to(to)
		for step in range(0,int(distance),22):
			var at := from.lerp(to,step/maxf(1,distance))
			if at.x > 20 and at.x < 1050: draw_circle(at,1.5,Color(0.85,0.76,0.56,0.4))
	var destination := goal-Vector2(camera,0)
	if destination.x >= 20 and destination.x <= 1050: draw_arc(destination,12,0,TAU,24,InteractionFeedback.READY,1.5,true)
	elif destination.x < 20: draw_colored_polygon(PackedVector2Array([Vector2(22,590),Vector2(33,583),Vector2(33,597)]),InteractionFeedback.READY)


func _draw_route(state: ExpeditionState,camera: float) -> void:
	var point := Vector2(state.route_x()-camera,620)
	if point.x < 0 or point.x > 1065: return
	var mouse: Vector2 = (get_viewport().get_mouse_position()-game.world_offset())/game.world_scale()+Vector2(camera,0)
	var hovered: bool = state.route_hit_rect().has_point(mouse) and not game._loot_open
	var near := state.route_in_range()
	var color := InteractionFeedback.READY if near else InteractionFeedback.DISTANT
	if not state.route_open:
		var kind: String = LocationEnvironment.profile(state.location_id)["route_kind"]
		if kind == "service":
			draw_rect(Rect2(point+Vector2(-25,-92),Vector2(50,92)),Color("344a4b"))
			for j in range(5): draw_line(point+Vector2(-22+j*11,-89),point+Vector2(-22+j*11,-2),Color("93a395"),2,true)
			for y in [-74,-49,-24]: draw_line(point+Vector2(-25,y),point+Vector2(25,y),Color("93a395"),2,true)
		elif kind == "shutter":
			draw_rect(Rect2(point+Vector2(-27,-91),Vector2(54,91)),Color("637470"))
			for y in range(-86,-1,12): draw_line(point+Vector2(-26,y),point+Vector2(26,y),Color("a3ab94"),2,true)
		else:
			for j in range(3):
				var y := -67+j*22
				draw_line(point+Vector2(-24,y),point+Vector2(24,y+12),Color("99876a"),7,true)
				draw_line(point+Vector2(-23,y-2),point+Vector2(23,y+10),Color("c0ac82"),1,true)
		var marker := point+Vector2(0,-108)
		draw_circle(marker,14,Color("142525"))
		draw_line(marker+Vector2(-5,6),marker+Vector2(4,-5),color,3,true)
		draw_line(marker+Vector2(-1,-6),marker+Vector2(7,0),color,3,true)
		if near or hovered: draw_arc(marker,17,0,TAU,24,color,1.6,true)
		if state.route_progress > 0:
			draw_arc(marker,21,-PI/2,-PI/2+TAU*state.route_progress/LocationEnvironment.route_seconds(state.location_id,state.route_tool),32,color,3,true)
		if near or hovered:
			draw_rect(Rect2(point+Vector2(-31,-100),Vector2(62,103)),Color(color,.5),false,1)
	else:
		# The removed boards stay on the ground; the actual ladder is now usable.
		for j in range(3): draw_line(point+Vector2(-33+j*12,5),point+Vector2(5+j*13,9),Color("7c7965"),3,true)


func _draw_decoys(state: ExpeditionState,camera: float) -> void:
	for d: Dictionary in state.decoys:
		var p := Vector2(float(d["x"])-camera,ExpeditionState.FLOOR_Y[int(d["floor"])]-9)
		if p.x < 0 or p.x > 1065: continue
		draw_circle(p,6,Color("c5aa73"));draw_rect(Rect2(p-Vector2(3,3),Vector2(6,5)),Color("3c4c48"))
		var phase := fposmod(state.elapsed*1.3,1)
		for offset in [0.0,.5]:
			var wave := fposmod(phase+offset,1)
			draw_arc(p,14+wave*43,0,TAU,32,Color(.8,.7,.43,.55*(1-wave)),1.5,true)
		draw_arc(p,9,-PI/2,-PI/2+TAU*float(d["remaining"])/18,24,Color("dfc994"),2,true)


func _draw_district(state: ExpeditionState,camera: float) -> void:
	var definition: Dictionary = state.site_definitions()[DistrictSystem.POINTS[state.location_id]]
	var p := Vector2(float(definition["x"])-camera,ExpeditionState.FLOOR_Y[int(definition["floor"])])
	if p.x < 0 or p.x > 1065: return
	var r: Dictionary = game.districts.regions[state.location_id]
	var tint := Color("9bc5b6") if r["built"] and r["condition"] >= 20 else Color("c0b18d")
	draw_line(p+Vector2(17,-4),p+Vector2(17,-91),tint,2,true)
	var points := PackedVector2Array([p+Vector2(18,-90),p+Vector2(39,-84),p+Vector2(18,-73)])
	if r["built"]: draw_colored_polygon(points,tint)
	else: draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[0]]),tint,1.5,true)
	if r["built"]:
		draw_rect(Rect2(p+Vector2(10,-102),Vector2(32,3)),Color("30423e"))
		draw_rect(Rect2(p+Vector2(10,-102),Vector2(32*float(r["condition"])/100,3)),tint)
	if not game.districts.work.is_empty():
		var w: Dictionary = game.districts.work
		draw_arc(p+Vector2(17,-118),12,-PI/2,-PI/2+TAU*float(w["elapsed"])/float(DistrictSystem.SECONDS[w["action"]]),28,Color("dcca94"),3,true)
