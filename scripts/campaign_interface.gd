class_name CampaignInterface
extends CanvasLayer
## Night assignment, deliberate loot transfer, construction and dawn report.
var game: Node2D
var root: Control
var overlay: Panel
var build_panel: Panel
var build_button: Button
var placement_hint: Label
var role_options: Array[OptionButton] = []
var role_stats: Array[Label] = []
var supply_buttons: Dictionary = {}
var supply_labels: Dictionary = {}
var plan_error: Label
var plan_capacity: Label
var depart_button: Button
var map_buttons: Dictionary = {}
var loot_buttons: Dictionary = {}
var loot_returns: Dictionary = {}
var loot_title: Label
var loot_counts: Label
var shown := ""
var has_move_target := false
var target_x := 110.0
var target_floor := 0
var target_site := -1
var target_enemy := -1
var target_run := false
var build_open := false


func _ready() -> void:
	layer = 8
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	build_button = button(root, "建设 B", Vector2(1040, 150), Vector2(160, 42), toggle_build_menu)
	placement_hint = label(root, "", Vector2(32, 246), Vector2(1000, 38), 17, game.GOLD)
	refresh(true)


func label(parent: Node, text: String, point: Vector2, size: Vector2, font_size: int = 16, color: Color = Color("d8ded7")) -> Label:
	var node := Label.new()
	node.text = text
	node.position = point
	node.size = size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", game.FONT)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	node.size = size
	return node


func button(parent: Node, text: String, point: Vector2, size: Vector2, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = point
	node.size = size
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_override("font", game.FONT)
	node.add_theme_font_size_override("font_size", 15)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = game._style(Color("27382f") if state in ["hover", "pressed"] else Color("172522"), game.GOLD if state in ["hover", "pressed"] else Color("516052"))
		if size.y <= 36:
			box.content_margin_top = 3
			box.content_margin_bottom = 3
		node.add_theme_stylebox_override(state, box)
	node.pressed.connect(action)
	parent.add_child(node)
	node.size = size
	return node


func panel(parent: Node, point: Vector2, size: Vector2, color: Color = Color("14201f")) -> Panel:
	var node := Panel.new()
	node.position = point
	node.size = size
	node.add_theme_stylebox_override("panel", game._style(color, Color("586450")))
	parent.add_child(node)
	node.size = size
	return node


func refresh(force: bool = false) -> void:
	if not is_instance_valid(root): return
	build_button.visible = game.cycle.phase == "day" and not game.expedition.active
	placement_hint.visible = not game.placement.is_empty() and game.cycle.phase == "day"
	if placement_hint.visible: placement_hint.text = "放置%s：点击绿色建设位置；右键或Esc取消。" % CampaignCycle.RECIPES[game.placement]["name"]
	var mode: String = game.cycle.phase if game.cycle.phase in ["planning", "dawn"] else "loot" if game._loot_open else ""
	if shown != mode or (force and not mode.is_empty()):
		shown = mode
		if is_instance_valid(overlay):
			overlay.hide()
			overlay.queue_free()
		role_options.clear()
		role_stats.clear()
		supply_buttons.clear()
		supply_labels.clear()
		map_buttons.clear()
		loot_buttons.clear()
		loot_returns.clear()
		if not mode.is_empty():
			build_open = false
			if is_instance_valid(build_panel): build_panel.hide()
			overlay = panel(root, Vector2.ZERO, Vector2(1440, 900), Color("101b1c"))
			if mode == "planning": _create_plan()
			elif mode == "dawn": _create_dawn()
			else: _create_loot()
	if mode == "planning": _refresh_plan()
	elif mode == "loot": _refresh_loot()
	elif mode == "dawn" and force:
		# Rebuild the summary only when its saved ledger changes.
		pass


func _create_plan() -> void:
	label(overlay, "第%d夜 · 谁去，谁留下" % game.cycle.night_day, Vector2(36, 24), Vector2(900, 48), 30, game.GOLD)
	label(overlay, "先选搜刮地点，再安排每个人的夜晚。随身物资出发时才扣；每晚只能搜刮一次。", Vector2(38, 80), Vector2(1300, 28), 16)
	button(overlay, "保存 F6", Vector2(1260, 30), Vector2(140, 42), func(): game.save_game())
	label(overlay, "目的地", Vector2(38, 129), Vector2(600, 30), 19, game.GOLD)
	for index in range(LocationCatalog.IDS.size()):
		var id: String = LocationCatalog.IDS[index]
		var area := LocationCatalog.area(id)
		var x := 38.0 + index * 458
		panel(overlay, Vector2(x, 169), Vector2(440, 145), Color(str(area["color"])).darkened(0.15))
		label(overlay, area["name"] + "  /  风险" + area["risk"], Vector2(x + 16, 181), Vector2(405, 30), 21)
		var summary := label(overlay, area["summary"], Vector2(x + 16, 220), Vector2(405, 46), 14)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		map_buttons[id] = button(overlay, "选择地点", Vector2(x + 16, 267), Vector2(405, 35), func(): game.choose_destination(id); refresh())
	label(overlay, "夜间岗位  /  一名搜刮者 · 床位%d" % game.cycle.bed_count(), Vector2(38, 334), Vector2(650, 30), 19, game.GOLD)
	for index in range(game.survivors.size()):
		var actor: Survivor = game.survivors[index]
		var y := 377.0 + index * 66
		panel(overlay, Vector2(38, y), Vector2(665, 58))
		label(overlay, actor.display_name + " · " + actor.speciality, Vector2(53, y + 4), Vector2(220, 24), 16, actor.tint.lightened(0.2))
		role_stats.append(label(overlay, "", Vector2(53, y + 30), Vector2(455, 24), 13))
		var option := OptionButton.new()
		option.position = Vector2(510, y + 9)
		option.size = Vector2(178, 40)
		option.add_theme_font_override("font", game.FONT)
		option.add_theme_font_size_override("font_size", 15)
		for name in CampaignCycle.ROLE_NAMES: option.add_item(name)
		option.item_selected.connect(func(item: int): _set_role(index, CampaignCycle.ROLES[item]))
		overlay.add_child(option)
		role_options.append(option)
	label(overlay, "携带物资 · 出发前可反复调整", Vector2(746, 334), Vector2(640, 30), 19, game.GOLD)
	plan_capacity = label(overlay, "", Vector2(746, 374), Vector2(650, 30), 17)
	var row := 0
	for key in ShelterInventory.NAMES:
		var y := 416.0 + row * 42
		supply_labels[key] = label(overlay, "", Vector2(746, y), Vector2(450, 30), 16)
		var minus := button(overlay, "−", Vector2(1210, y - 2), Vector2(66, 34), _change_loadout.bind(key, -1))
		var plus := button(overlay, "+", Vector2(1290, y - 2), Vector2(100, 34), _change_loadout.bind(key, 1))
		supply_buttons[key] = [minus, plus]
		row += 1
	label(overlay, "床眠恢复65疲劳，地铺35；守夜+28，搜刮+35。\n第3夜起可能遭袭；无守夜者时，物资和同伴更危险。\n装备与物资每份占一格；工具破锁或命中仍会消耗。", Vector2(746, 721), Vector2(650, 75), 14)
	plan_error = label(overlay, "", Vector2(38, 786), Vector2(1100, 28), 15, Color("dca184"))
	button(overlay, "全员留守 · 不携带物资", Vector2(38, 829), Vector2(320, 44), _stay_home)
	depart_button = button(overlay, "开始这一夜 →", Vector2(1035, 829), Vector2(360, 44), func(): game.start_expedition())


func _set_role(index: int, role: String) -> void:
	if role == "dead" and game.survivors[index].health > 0: return
	if role == "scavenge":
		for other in range(game.cycle.roles.size()):
			if game.cycle.roles[other] == "scavenge": game.cycle.roles[other] = "floor"
	game.cycle.roles[index] = role
	refresh()


func _refresh_plan() -> void:
	if role_options.size() != game.survivors.size(): return
	for index in range(role_options.size()):
		var actor: Survivor = game.survivors[index]
		role_options[index].select(CampaignCycle.ROLES.find(game.cycle.roles[index]))
		role_options[index].disabled = actor.health <= 0
		role_options[index].set_item_disabled(4, actor.health > 0)
		role_stats[index].text = "生命%d · 疲劳%d · 饥饿%d · 背包%d格" % [roundi(actor.health), roundi(actor.fatigue), roundi(actor.hunger), CampaignCycle.BAGS[actor.person.persona]]
	var total := 0
	for amount in game.cycle.loadout.values(): total += int(amount)
	plan_capacity.text = "随身 %d / %d格  ·  据点库存不会在此刻扣除" % [total, game.cycle.capacity(game)]
	for key in supply_labels:
		var amount := int(game.cycle.loadout.get(key, 0))
		supply_labels[key].text = "%s    库存%d    携带%d" % [ShelterInventory.NAMES[key], game.inventory.amount(key), amount]
		supply_buttons[key][0].disabled = amount <= 0
		supply_buttons[key][1].disabled = total >= game.cycle.capacity(game) or amount >= game.inventory.amount(key)
	for id in map_buttons: map_buttons[id].text = "✓ 当前目的地" if id == game.expedition.location_id else "选择地点"
	var error: String = game.cycle.plan_error(game)
	plan_error.text = error if not error.is_empty() else "岗位和装备已就绪。留守者不会在夜里继续白天的生产任务。"
	depart_button.disabled = not error.is_empty()
	depart_button.text = "开始搜刮 →" if game.cycle.scavenger() >= 0 else "留守并度过这一夜 →"


func _change_loadout(key: String, change: int) -> void:
	var amount := maxi(0, int(game.cycle.loadout.get(key, 0)) + change)
	if amount == 0: game.cycle.loadout.erase(key)
	else: game.cycle.loadout[key] = amount
	refresh()


func _stay_home() -> void:
	var beds: int = game.cycle.bed_count()
	for index in range(game.cycle.roles.size()):
		if game.survivors[index].health <= 0: game.cycle.roles[index] = "dead"
		elif index == 0: game.cycle.roles[index] = "guard"
		elif beds > 0:
			game.cycle.roles[index] = "bed"
			beds -= 1
		else: game.cycle.roles[index] = "floor"
	game.cycle.loadout.clear()
	refresh()


func _create_dawn() -> void:
	label(overlay, "第%d天 · 天亮了" % ExpeditionState.day_at(game.simulation_time), Vector2(80, 48), Vector2(1250, 58), 34, game.GOLD)
	label(overlay, "一夜的分工、收获与代价", Vector2(83, 121), Vector2(1200, 32), 19)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 183)
	scroll.size = Vector2(1280, 535)
	overlay.add_child(scroll)
	var lines := Label.new()
	lines.text = "\n\n".join(game.cycle.report)
	lines.add_theme_font_override("font", game.FONT)
	lines.add_theme_font_size_override("font_size", 20)
	lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lines)
	label(overlay, "本轮结果已结算并随存档保留；重开窗口不会重复发放或再次扣除。", Vector2(83, 741), Vector2(1250, 30), 15)
	var begin := button(overlay, "开始白天的生活 →", Vector2(950, 812), Vector2(400, 50), game.begin_day)
	begin.disabled = game.game_over
	button(overlay, "保存 F6", Vector2(80, 812), Vector2(180, 50), func(): game.save_game())
	button(overlay, "读取存档 F9", Vector2(280, 812), Vector2(200, 50), game.request_load)
	if game.game_over: button(overlay, "新的一局", Vector2(500, 812), Vector2(200, 50), game.request_new_game)


func _create_loot() -> void:
	overlay.add_theme_stylebox_override("panel", game._style(Color(0.04, 0.07, 0.07, 0.82), Color("52634c")))
	panel(overlay, Vector2(190, 210), Vector2(1060, 470))
	loot_title = label(overlay, "", Vector2(218, 230), Vector2(610, 34), 23, game.GOLD)
	loot_counts = label(overlay, "", Vector2(840, 230), Vector2(370, 34), 20, game.GOLD)
	label(overlay, "容器里的物资", Vector2(220, 279), Vector2(500, 26), 16)
	label(overlay, "随身背包", Vector2(850, 279), Vector2(350, 26), 16)
	var row := 0
	for key in ShelterInventory.NAMES:
		var y := 317.0 + row * 38
		loot_buttons[key] = button(overlay, "", Vector2(220, y), Vector2(485, 32), _take.bind(key))
		loot_returns[key] = button(overlay, "", Vector2(735, y), Vector2(485, 32), _put.bind(key))
		row += 1
	label(overlay, "整理时场景继续；空格可暂停。只可放回容器原有种类，其余物品可在I背包丢弃。", Vector2(220, 589), Vector2(1000, 28), 13)
	button(overlay, "尽量全部拿走 F", Vector2(220, 626), Vector2(300, 36), _take_all)
	button(overlay, "关闭，继续行动 Esc", Vector2(850, 626), Vector2(370, 36), game.close_loot)


func _refresh_loot() -> void:
	var field: ExpeditionState = game.expedition
	if field.loot_site < 0: return
	var site: Dictionary = field.sites[field.loot_site]
	loot_title.text = field.site_definitions()[field.loot_site]["name"]
	loot_counts.text = "背包 %d / %d格%s" % [field.used_capacity(), field.capacity, " · 已暂停" if game.paused else ""]
	for key in loot_buttons:
		loot_buttons[key].text = "%s   %d       拿取1 →" % [ShelterInventory.NAMES[key], site["contents"].get(key, 0)]
		loot_buttons[key].disabled = int(site["contents"].get(key, 0)) <= 0 or field.used_capacity() >= field.capacity
		loot_returns[key].text = "← 放回1       %s   %d" % [ShelterInventory.NAMES[key], field.bag[key]]
		loot_returns[key].disabled = field.bag[key] <= 0 or not site["contents"].has(key) or int(site["contents"].get(key, 0)) >= int(field.site_definitions()[field.loot_site]["items"].get(key, 0))


func _take(key: String) -> void:
	game.expedition.take_loot(key, 1, game.survivors[game.expedition.actor_id])
	refresh()


func _put(key: String) -> void:
	game.expedition.put_loot(key, 1)
	refresh()


func _take_all() -> void:
	for key in ShelterInventory.NAMES: game.expedition.take_loot(key, 1000, game.survivors[game.expedition.actor_id])
	refresh()


func set_target(x: float, floor_level: int, run: bool, site: int) -> void:
	has_move_target = true
	target_x = x
	target_floor = floor_level
	target_site = site
	target_enemy = -1
	target_run = run
	game.expedition_view.search_held = false


func toggle_build_menu() -> void:
	build_open = not build_open
	if not is_instance_valid(build_panel):
		build_panel = panel(root, Vector2(32, 270), Vector2(370, 430))
		label(build_panel, "建设 · 选设施，再点场景位置", Vector2(16, 16), Vector2(340, 30), 17, game.GOLD)
		var row := 0
		for type in CampaignCycle.RECIPES:
			var recipe: Dictionary = CampaignCycle.RECIPES[type]
			var action := button(build_panel, recipe["name"] + " · " + ShelterInventory.describe(recipe["cost"]), Vector2(16, 60 + row * 115), Vector2(338, 42), _select_build.bind(type))
			action.add_theme_font_size_override("font_size", 14)
			var hint := label(build_panel, recipe["hint"], Vector2(16, 107 + row * 115), Vector2(338, 53), 13)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row += 1
	build_panel.visible = build_open


func _select_build(type: String) -> void:
	game.placement = type
	build_open = false
	build_panel.hide()
	refresh()
