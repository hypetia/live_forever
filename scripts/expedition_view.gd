class_name ExpeditionView
extends Node2D
## Original procedural expedition scene and HUD. Never advances simulation.

const FONT := preload("res://assets/fonts/interface.otf")
const INK := Color("d8ded7")
const GOLD := Color("d6b584")
const MUTED := Color("85928e")
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
var capacity_label: Label
var feedback_label: Label
var log_label: Label
var search_bar: ProgressBar
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
var bag_button: Button
var impact_time := 0.0
var impact_kind := ""
var impact_point := Vector2.ZERO
var impact_damage := 0


func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	for world: ExpeditionState in game.regions.values(): world.combat_resolved.connect(_on_combat_resolved)
	title_label = _label("", Vector2(32, 151), Vector2(680, 34), 22, INK)
	alert_label = _label("", Vector2(730, 155), Vector2(650, 28), 15, GOLD)
	area_hint = _label("", Vector2(32, 191), Vector2(1370, 42), 13, MUTED)
	area_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	area_hint.clip_text = true
	context_label = _label("", Vector2(32, 739), Vector2(1370, 30), 15, GOLD)
	actor_label = _label("", Vector2(32, 788), Vector2(190, 32), 23, INK)
	role_label = _label("", Vector2(32, 828), Vector2(300, 22), 13, MUTED)
	stats_label = _label("", Vector2(250, 786), Vector2(480, 48), 14, INK)
	search_button = _button("按住搜索 E", Vector2(760, 784), Vector2(160, 42), func(): pass)
	search_button.button_down.connect(func(): search_held = true)
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
	var actor: Survivor = game.survivors[state.actor_id]
	if last_attempt != state.attempts or last_actor != state.actor_id or last_health < 0:
		last_attempt = state.attempts
		last_actor = state.actor_id
		last_health = actor.health
	if actor.health < last_health - 0.1:
		damage_amount = ceili(last_health - actor.health)
		hurt_time = 0.4
	last_health = actor.health
	title_label.text = "%s  /  第 %d 次外出" % [state.area()["name"], state.attempts]
	area_hint.text = "%s  /  %s · %s" % [state.area()["summary"], state.weather()["name"], state.weather()["hint"]]
	var alert := 0.0
	for enemy in state.enemies:
		if enemy["hp"] > 0: alert = maxf(alert, float(enemy["suspicion"]))
	alert_label.text = "噪声 %d  /  警觉 %d  /  %s" % [int(state.noise), int(alert), "藏身中" if state.in_cover() else "潜行" if state.sneaking else "暴露"]
	actor_label.text = actor.display_name
	role_label.text = "搜寻者 · 搜索+20% / 脚步声−20%" if actor.speciality == "搜寻者" else actor.speciality + " / 单人实时探索"
	stats_label.text = "生命 %d · 饥饿 %d · 疲劳 %d\n伤势 %d · 感染 %d · 口渴%d" % [ceili(actor.health), ceili(actor.hunger), ceili(actor.fatigue), ceili(actor.injury), ceili(actor.infection), roundi(actor.person.thirst)]
	stats_label.add_theme_color_override("font_color", Color("dca184") if actor.health < 40 or actor.infection >= 30 else MUTED)
	for node in bag_nodes: node.visible = bag_open
	bag_button.text = "%d/%d I" % [state.used_capacity(), ExpeditionState.CAPACITY]
	capacity_label.text = "背包 %d / %d" % [state.used_capacity(), ExpeditionState.CAPACITY]
	for resource in drop_buttons:
		drop_buttons[resource].text = "%s   %d                           −1" % [ShelterInventory.NAMES[resource], state.bag[resource]]
		drop_buttons[resource].disabled = state.bag[resource] <= 0
	search_bar.value = state.search_progress / state.search_duration * 100 if state.search_duration > 0 else 0
	retreat_button.disabled = game.paused
	search_button.disabled = game.paused
	attack_button.disabled = game.paused or state.attack_cooldown > 0 or state.climb_target != -1
	attack_button.text = ("工具挥击 J" if state.bag["tools"] > 0 else "徒手推搡 J") if state.attack_cooldown <= 0 else "冷却 %.1f" % state.attack_cooldown
	attack_button.tooltip_text = "有工具：消耗1件，命中造成40伤害。徒手：只推开、不扣生命。面向敌人，75范围内生效；前摇0.2秒，冷却1.1秒。"
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
	draw_set_transform(game.WORLD_OFFSET, 0, game.WORLD_SCALE)
	draw_rect(Rect2(0, 210, 1095, 490), Color("142126"))
	for index in range(18):
		var x := fposmod(index * 107.0 - camera * 0.22, 1150) - 50
		draw_rect(Rect2(x, 305 + index % 3 * 22, 80, 322), Color("1b2b2e"))
	var upper := state.upper_left()
	var width: float = state.area()["width"]
	var wall := Color(str(state.area()["color"]))
	var accent := Color(str(state.area()["accent"]))
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
	for definition in state.area()["covers"]:
		var y := 570 if definition[2] == 0 else 350
		var cover := Rect2(definition[0], y, definition[1] - definition[0], 50)
		_rect_world(cover, Color("646c59"))
		_rect_world(Rect2(cover.position + Vector2(4, 5), cover.size - Vector2(8, 10)), Color("424c41"))
	_text(Vector2(145 - camera, 660), "← 入口 · E/T 撤退", 14, GOLD)
	_rect_world(Rect2(90, 535, 55, 85), Color("344b41"))
	_rect_world(Rect2(96, 540, 43, 72), Color("142b29"))
	for index in range(state.site_definitions().size()):
		var definition: Dictionary = state.site_definitions()[index]
		var point := Vector2(float(definition["x"]) - camera, ExpeditionState.FLOOR_Y[int(definition["floor"])])
		if point.x < 0 or point.x > 1065: continue
		var contents: Dictionary = state.sites[index]["contents"]
		var empty := contents.values().all(func(amount: int): return amount == 0)
		draw_rect(Rect2(point + Vector2(-22, -38), Vector2(44, 38)), Color("414c42") if empty else accent.darkened(0.2))
		draw_rect(Rect2(point + Vector2(-18, -34), Vector2(36, 30)), Color("59614e") if empty else accent, false, 2)
		if state.sites[index]["locked"]:
			draw_circle(point + Vector2(0, -23), 6, Color("d8c28c"))
		_text(point + Vector2(-47, 27), definition["name"] + (" · 空" if empty else ""), 12, MUTED if empty else GOLD)
	_draw_landmarks(state, camera, accent)
	for enemy in state.enemies:
		_draw_enemy(enemy, camera, state)
	var actor: Survivor = game.survivors[state.actor_id]
	_draw_player(Vector2(state.player_x - camera, state.player_y), actor, state)
	if state.attack_windup > 0 or state.attack_cooldown > 0.76:
		var swing := Vector2(state.player_x - camera, state.player_y - 38)
		if swing.x >= 55 and swing.x <= 1010:
			var angle := 0.0 if state.facing > 0 else PI
			var windup := state.attack_windup > 0
			var sweep := (1.1 - state.attack_cooldown) / 0.34
			var color := Color("cba96b") if windup else Color("f1dfb3")
			draw_arc(swing, 72, angle - 0.85, angle + 0.85, 24, Color(color, 0.25) if windup else color, 1.5 if windup else 4, true)
			var hand := swing + Vector2.from_angle(angle - 1.0 + sweep * 2.0) * 44
			draw_line(swing, hand, actor.tint.lightened(0.2), 6, true)
			if state.bag["tools"] > 0 or impact_kind == "hit" and impact_time > 0.6:
				draw_line(hand, hand + Vector2(0, -19), Color("d5d7bf"), 4, true)
	_draw_weather(state)
	if SurvivalRules.is_night(game.simulation_time):
		draw_rect(Rect2(0, 264, 1070, 420), Color(0, 0.02, 0.04, 0.10))

	if hurt_time > 0:
		draw_rect(Rect2(0, 264, 1070, 420), Color(0.75, 0.20, 0.12, hurt_time * 0.22))
		_text(Vector2(clampf(state.player_x - camera - 35, 55, 960), state.player_y - 116), "受伤 −%d" % damage_amount, 19, Color("edaf93"))
	_draw_impact(camera)
	draw_set_transform(Vector2.ZERO)
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


func _draw_enemy(enemy: Dictionary, camera: float, state: ExpeditionState) -> void:
	var point := Vector2(float(enemy["x"]) - camera, ExpeditionState.FLOOR_Y[int(enemy["floor"])])
	if point.x < -80 or point.x > 1140: return
	if enemy["hp"] <= 0:
		_text(point + Vector2(-22, -38), "已击倒", 12, MUTED)
		if impact_kind == "hit" and impact_time > 0.65 and absf(impact_point.x - float(enemy["x"])) < 2:
			var fall := clampf((1 - impact_time) / 0.35, 0, 1)
			var up := Vector2.UP.rotated(float(enemy["direction"]) * PI * 0.5 * fall)
			var hip := point + Vector2(0, -22 * (1 - fall))
			var flash := Color("f6dfb2") if impact_time > 0.84 else Color("707b61")
			draw_line(hip, hip + up * 30, flash, 14, true)
			draw_circle(hip + up * 42, 9, flash)
			draw_line(hip, point + Vector2(-10, -2), Color("556152"), 7, true)
			draw_line(hip, point + Vector2(14, -2), Color("556152"), 7, true)
		else:
			draw_line(point + Vector2(-22, -5), point + Vector2(22, -5), Color("4a5347"), 10, true)
		return
	var reach := 115.0 if state.sneaking else 290.0
	if state.in_cover(): reach = 52
	reach = maxf(55, reach * float(state.weather()["vision"]))
	var direction: float = enemy["direction"]
	if enemy["mode"] == "windup":
		var windup := clampf(1.0 - float(enemy["timer"]) / 0.8, 0, 1)
		point.x += direction * windup * 8
		draw_arc(point + Vector2(0, -30), 47, -PI / 2 if direction > 0 else PI / 2, PI / 2 if direction > 0 else PI * 1.5, 24, Color(0.95, 0.45, 0.26, 0.6), 3, true)
	draw_colored_polygon(PackedVector2Array([point + Vector2(0, -50), point + Vector2(direction * reach, -85), point + Vector2(direction * reach, -5)]), Color(0.75, 0.36, 0.25, 0.055))
	if enemy["brace"] > 0 and enemy["mode"] != "stunned": _text(point + Vector2(25, -72), "稳", 11, GOLD)
	var stride := sin(state.elapsed * 5) * 5
	draw_line(point + Vector2(-5, -23), point + Vector2(-8 + stride, -2), Color("3b4942"), 7, true)
	draw_line(point + Vector2(5, -23), point + Vector2(8 - stride, -2), Color("3b4942"), 7, true)
	draw_colored_polygon(PackedVector2Array([point + Vector2(-11, -49), point + Vector2(10, -53), point + Vector2(13, -22), point + Vector2(-9, -21)]), Color("707b61"))
	draw_circle(point + Vector2(direction * 5, -58), 9, Color("a1a186"))
	draw_line(point + Vector2(5 * direction, -44), point + Vector2((42 if enemy["mode"] == "windup" else 23) * direction, -37), Color("c4a185") if enemy["mode"] == "windup" else Color("899174"), 6, true)
	# Health and awareness have separate positions, colors and explicit labels.
	_text(point + Vector2(-28, -128), "生命 %d/40" % enemy["hp"], 12, Color("e5a68b"))
	draw_rect(Rect2(point + Vector2(-28, -118), Vector2(62, 7)), Color("1a2422"))
	draw_rect(Rect2(point + Vector2(-28, -118), Vector2(62 * clampf(float(enemy["hp"]) / 40.0, 0, 1), 7)), Color("ce7c6b"))
	if enemy["suspicion"] > 0:
		draw_rect(Rect2(point + Vector2(-28, -105), Vector2(62 * float(enemy["suspicion"]) / 100, 3)), GOLD)
	if enemy["mode"] == "windup":
		draw_arc(point + Vector2(0, -30), 42, 0, TAU, 40, Color("e4a078"), 2, true)
		_text(point + Vector2(32, -68), "扑咬!", 13, Color("e4a078"))
	elif enemy["mode"] == "stunned":
		_text(point + Vector2(32, -68), "失衡", 13, GOLD)


func _draw_player(point: Vector2, actor: Survivor, state: ExpeditionState) -> void:
	var crouch := 20.0 if state.sneaking else 0.0
	var stride := sin(state.elapsed * 10) * 6 if state.moving else 0.0
	var tint := actor.tint.lightened(0.35) if state.invulnerable > 0 and int(state.elapsed * 12) % 2 else actor.tint
	draw_arc(point + Vector2(0, -3), 23, 0, TAU, 40, GOLD, 1, true)
	draw_line(point + Vector2(-5, -24 + crouch * 0.5), point + Vector2(-8 + stride, -3), Color("31403b"), 7, true)
	draw_line(point + Vector2(5, -24 + crouch * 0.5), point + Vector2(10 - stride, -3), Color("31403b"), 7, true)
	draw_colored_polygon(PackedVector2Array([point + Vector2(-10, -55 + crouch), point + Vector2(10, -55 + crouch), point + Vector2(13, -22 + crouch * 0.5), point + Vector2(-12, -22 + crouch * 0.5)]), tint)
	draw_circle(point + Vector2(0, -65 + crouch), 9, Color("c7b294"))
	if state.attack_cooldown <= 0.76:
		draw_line(point + Vector2(8 * state.facing, -48 + crouch), point + Vector2(23 * state.facing, -30 + crouch), tint.lightened(0.1), 6, true)
	if state.bag["tools"] > 0 and state.attack_cooldown <= 0.76:
		draw_line(point + Vector2(23 * state.facing, -32 + crouch), point + Vector2(25 * state.facing, -52 + crouch), Color("c4c9b4"), 3, true)
	draw_rect(Rect2(point + Vector2(-26, -111 + crouch), Vector2(52, 5)), Color("21332e"))
	draw_rect(Rect2(point + Vector2(-26, -111 + crouch), Vector2(52 * actor.health / 100, 5)), Color("9ab997"))
	draw_colored_polygon(PackedVector2Array([point + Vector2(-5, -89 + crouch), point + Vector2(5, -89 + crouch), point + Vector2(0, -83 + crouch)]), GOLD)


func _draw_landmarks(state: ExpeditionState, camera: float, accent: Color) -> void:
	_text(Vector2(230 - camera, 415), str(state.area()["name"]), 22, accent)
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
	else:
		for x in [590, 1770]:
			_rect_world(Rect2(x, 450, 95, 18), accent.darkened(0.25))
			_rect_world(Rect2(x + 10, 468, 75, 6), accent.darkened(0.5))


func _draw_weather(state: ExpeditionState) -> void:
	var phase: float = game.weather_time
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
	if is_instance_valid(game.game_audio): game.game_audio.combat_cue(kind)
	queue_redraw()


func _draw_impact(camera: float) -> void:
	if impact_time <= 0: return
	var point := impact_point - Vector2(camera, 0)
	var color := Color("f1d4a0") if impact_kind in ["hit", "push"] else Color("b5b9aa")
	var text: String = {"hit": "命中 −%d" % impact_damage, "push": "推开 · 0伤害", "miss": "挥空", "blocked": "稳身 · 推不动"}.get(impact_kind, "")
	_text(Vector2(clampf(point.x - 140, 30, 810), maxf(285, point.y - 155 - (1 - impact_time) * 15)), text, 20, Color(color, minf(1, impact_time * 3)))
	if impact_time > 0.65 and impact_kind in ["hit", "push"]:
		var radius := (1 - impact_time) * 100 + 8
		draw_arc(point, radius, 0, TAU, 24, color, 3, true)
		for index in range(6):
			var ray := Vector2.from_angle(index * TAU / 6)
			draw_line(point + ray * radius, point + ray * (radius + 11), color, 2, true)
