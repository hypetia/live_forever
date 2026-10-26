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
var climate_label: Label
var workshop_button: Button
var workshop_panel: Panel
var workshop_pause := false
var workshop_open := false
var map_page := 0
var part_button: Button
var ammo_label: Label
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
	workshop_button = button(root, "装备 / 战役 K", Vector2(1212, 150), Vector2(200, 42), toggle_workshop)
	climate_label = label(root, "", Vector2(32, 151), Vector2(990, 62), 15)
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
	workshop_button.visible = game.cycle.phase == "day"
	climate_label.visible = game.cycle.phase == "day"
	if climate_label.visible:
		climate_label.text = "战役第%d/35天 · 室外 %d℃ / 室内 %d℃  %s\n%s" % [game.expansion.day(game), game.expansion.outside(game), game.expansion.outside(game) + 8 + (18 if game.expansion.heater_remaining > 0 else 0), "炉火剩余%d分" % int(game.expansion.heater_remaining * 2) if game.expansion.heater_remaining > 0 else "炉火未点燃", game.expansion.objective(game)]
	build_button.visible = game.cycle.phase == "day" and not game.expedition.active
	placement_hint.visible = not game.placement.is_empty() and game.cycle.phase == "day"
	if placement_hint.visible: placement_hint.text = "放置%s：点击绿色建设位置；右键或Esc取消。" % CampaignCycle.RECIPES[game.placement]["name"]
	var mode: String = game.cycle.phase if game.cycle.phase in ["planning", "dawn"] else "loot" if game._loot_open else ""
	if shown != mode or (force and not mode.is_empty()):
		if workshop_open: close_workshop()
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
	button(overlay, "‹ 上一组", Vector2(770, 122), Vector2(150, 34), _page_maps.bind(-1))
	label(overlay, "%d / 3" % (map_page + 1), Vector2(935, 122), Vector2(100, 32))
	button(overlay, "下一组 ›", Vector2(1040, 122), Vector2(150, 34), _page_maps.bind(1))
	button(overlay, "装备 / 战役 K", Vector2(1200, 122), Vector2(195, 34), toggle_workshop)
	for index in range(3):
		var id: String = LocationCatalog.ALL_IDS[map_page * 3 + index]
		var area := LocationCatalog.area(id)
		var x := 38.0 + index * 458
		panel(overlay, Vector2(x, 169), Vector2(440, 145), Color(str(area["color"])).darkened(0.15))
		label(overlay, area["name"] + "  /  风险" + area["risk"], Vector2(x + 16, 181), Vector2(405, 30), 21)
		var summary := label(overlay, area["summary"] if game.expansion.unlocked(game, id) else "尚未开放：" + game.expansion.lock_reason(id), Vector2(x + 16, 220), Vector2(405, 46), 14)
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
	label(overlay, "精神：床眠+65，地铺+35；守夜−28，搜刮−35。\n武器、护甲各占1格；弹药每8发占1格。冬衣穿在身上。", Vector2(746, 757), Vector2(650, 44), 13)
	ammo_label = label(overlay, "", Vector2(746, 714), Vector2(430, 30), 15)
	button(overlay, "−8发", Vector2(1195, 714), Vector2(90, 32), _ammo.bind(-8))
	button(overlay, "+8发", Vector2(1300, 714), Vector2(90, 32), _ammo.bind(8))
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
		role_stats[index].text = "生命%d 精神%d 饱腹%d · %s%d · %d格" % [Vitals.value(actor,"health"), Vitals.value(actor,"vigor"), Vitals.value(actor,"fullness"), actor.weapon().get("name", "徒手"), actor.weapon_item.get("durability", 0), CampaignCycle.BAGS[actor.person.persona]]
	var total := 0
	for amount in game.cycle.loadout.values(): total += int(amount)
	total += game.expansion.reserved_slots(game)
	ammo_label.text = "弹药库存%d / 携带%d；取暖：%s" % [game.expansion.ammo, game.expansion.ammo_loadout, "预留燃料" if game.expansion.use_night_heat else "关闭（K调整）"]
	plan_capacity.text = "随身 %d / %d格  ·  据点库存不会在此刻扣除" % [total, game.cycle.capacity(game)]
	for key in supply_labels:
		var amount := int(game.cycle.loadout.get(key, 0))
		supply_labels[key].text = "%s    库存%d    携带%d" % [ShelterInventory.NAMES[key], game.inventory.amount(key), amount]
		supply_buttons[key][0].disabled = amount <= 0
		supply_buttons[key][1].disabled = total >= game.cycle.capacity(game) or amount >= game.inventory.amount(key)
	for id in map_buttons:
		map_buttons[id].text = "✓ 当前目的地" if id == game.expedition.location_id else "选择地点"
		map_buttons[id].disabled = not game.expansion.unlocked(game, id)
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
	game.expansion.ammo_loadout = 0
	refresh()


func _create_dawn() -> void:
	label(overlay, "第%d天 · 天亮了" % ExpeditionState.day_at(game.simulation_time), Vector2(80, 48), Vector2(1250, 58), 34, game.GOLD)
	overlay.add_theme_stylebox_override("panel",game._style(Color(0.035,0.055,0.06,0.94),Color("465047")))
	for index in range(game.survivors.size()):
		var card := SurvivorCard.new()
		card.game = game
		card.member_id = index
		card.position = Vector2(80+(index%3)*425,180+(index/3)*143)
		card.size = Vector2(390,96)
		card.tooltip_text = Vitals.summary(game.survivors[index])
		for state in ["normal","hover","pressed"]:card.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		overlay.add_child(card)
		var role: String = game.cycle.roles[index] if index < game.cycle.roles.size() else "floor"
		label(overlay,CampaignCycle.ROLE_NAMES[CampaignCycle.ROLES.find(role)],card.position+Vector2(0,101),Vector2(390,24),14)
	var summary: Array[String] = []
	for line: String in game.cycle.report:
		if "已归来" in line or "未能归来" in line or "尸群" in line or "撤离成功" in line or "窗口已关闭" in line: summary.append(line)
	label(overlay,"\n\n".join(summary).left(220),Vector2(83,508),Vector2(1240,170),19)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(75,173)
	scroll.size = Vector2(1290,525)
	scroll.add_theme_stylebox_override("panel",game._style(Color("12201f"),Color("626950")))
	overlay.add_child(scroll)
	var lines := Label.new()
	lines.text = "\n\n".join(game.cycle.report)
	lines.add_theme_font_override("font",game.FONT)
	lines.add_theme_font_size_override("font_size",18)
	lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lines)
	scroll.hide()
	button(overlay,"查看 / 收起纪要",Vector2(80,731),Vector2(250,38),func(): scroll.visible = not scroll.visible)
	var begin := button(overlay, "开始白天的生活 →", Vector2(950, 812), Vector2(400, 50), game.begin_day)
	begin.disabled = game.game_over or (not game.expansion.outcome.is_empty() and not game.expansion.endless)
	if not game.expansion.outcome.is_empty() and not game.expansion.endless:
		begin.text = "继续无尽生存 →"
		begin.disabled = game.game_over
		for connection in begin.pressed.get_connections(): begin.pressed.disconnect(connection["callable"])
		begin.pressed.connect(func(): game.expansion.endless = true; game.begin_day())
	button(overlay, "保存 F6", Vector2(80, 812), Vector2(180, 50), func(): game.save_game())
	button(overlay, "读取存档 F9", Vector2(280, 812), Vector2(200, 50), game.request_load)
	if game.game_over: button(overlay, "新的一局", Vector2(500, 812), Vector2(200, 50), game.request_new_game)


func _create_loot() -> void:
	overlay.add_theme_stylebox_override("panel", game._style(Color(0.02, 0.04, 0.04, 0.48), Color("52634c")))
	panel(overlay, Vector2(190, 210), Vector2(1060, 535))
	loot_title = label(overlay, "", Vector2(218, 230), Vector2(610, 34), 23, game.GOLD)
	loot_counts = label(overlay, "", Vector2(840, 230), Vector2(370, 34), 20, game.GOLD)
	label(overlay, "容器里的物资", Vector2(220, 279), Vector2(500, 26), 16)
	label(overlay, "随身背包", Vector2(850, 279), Vector2(350, 26), 16)
	var row := 0
	for key in ShelterInventory.NAMES:
		var point := Vector2(230+(row%4)*112,328+(row/4)*110)
		var take := button(overlay,"",point,Vector2(100,96),_take.bind(key))
		var put := button(overlay,"",point+Vector2(550,0),Vector2(100,96),_put.bind(key))
		take.draw.connect(_loot_icon.bind(take,key))
		put.draw.connect(_loot_icon.bind(put,key))
		loot_buttons[key] = take
		loot_returns[key] = put
		row += 1
	part_button = button(overlay, "", Vector2(230, 572), Vector2(986, 46), func(): game.expansion.take_part(game); refresh())
	label(overlay, "点击拿取或放回 · 空格暂停", Vector2(220, 665), Vector2(1000, 28), 13)
	button(overlay, "尽量全部拿走 F", Vector2(220, 704), Vector2(300, 36), _take_all)
	button(overlay, "关闭，继续行动 Esc", Vector2(850, 704), Vector2(370, 36), game.close_loot)


func _refresh_loot() -> void:
	var field: ExpeditionState = game.expedition
	if field.loot_site < 0: return
	var part_name := ""
	for key in GearCatalog.PARTS:
		var part: Dictionary = GearCatalog.PARTS[key]
		if part["map"] == field.location_id and part["site"] == field.loot_site and not game.expansion.collected.has(key): part_name = ("放回：" if game.expansion.carried.has(key) else "拿取：") + part["name"]
	part_button.text = "战役零件：%s（占1格，须活着带回）" % part_name if not part_name.is_empty() else "此处没有未收集的战役零件 · 随身%d件" % game.expansion.carried.size()
	part_button.disabled = part_name.is_empty() or (field.used_capacity() >= field.capacity and not part_name.begins_with("放回"))
	var site: Dictionary = field.sites[field.loot_site]
	loot_title.text = field.site_definitions()[field.loot_site]["name"]
	loot_counts.text = "背包 %d / %d格%s" % [field.used_capacity(), field.capacity, " · 已暂停" if game.paused else ""]
	for key in loot_buttons:
		loot_buttons[key].text = "\n\n%d" % site["contents"].get(key,0)
		loot_buttons[key].tooltip_text = ShelterInventory.NAMES[key]+" · 点击拿取1"
		loot_buttons[key].disabled = int(site["contents"].get(key, 0)) <= 0 or field.used_capacity() >= field.capacity
		loot_returns[key].text = "\n\n%d" % field.bag[key]
		loot_returns[key].tooltip_text = ShelterInventory.NAMES[key]+" · 点击放回1"
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
		build_panel = panel(root, Vector2(32, 270), Vector2(370, 535))
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


func _page_maps(direction: int) -> void:
	map_page = posmod(map_page + direction, 3)
	refresh(true)


func _ammo(change: int) -> void:
	game.expansion.ammo_loadout = clampi(game.expansion.ammo_loadout + change, 0, mini(120, game.expansion.ammo))
	refresh()


func toggle_workshop() -> void:
	if workshop_open:
		close_workshop()
		return
	if not game.cycle.phase in ["day", "planning"]: return
	workshop_pause = game.paused
	game.paused = true
	workshop_open = true
	_create_workshop()


func close_workshop() -> void:
	if not workshop_open: return
	workshop_open = false
	if is_instance_valid(workshop_panel):
		workshop_panel.hide()
		workshop_panel.queue_free()
	if game.cycle.phase == "day": game.paused = workshop_pause


func _create_workshop() -> void:
	if is_instance_valid(workshop_panel):
		workshop_panel.hide()
		workshop_panel.queue_free()
	workshop_panel = panel(root, Vector2(25, 20), Vector2(1390, 860))
	label(workshop_panel, "工作台与战役 · 已暂停", Vector2(25, 17), Vector2(1070, 40), 27, game.GOLD)
	button(workshop_panel, "关闭 K", Vector2(1180, 17), Vector2(180, 40), close_workshop)
	label(workshop_panel, "第%d/35天 · %s\n%s" % [game.expansion.day(game), SurvivalExpansion.STAGES[game.expansion.stage], game.expansion.objective(game)], Vector2(25, 70), Vector2(1335, 65), 17)
	for index in range(game.survivors.size()):
		var actor: Survivor = game.survivors[index]
		button(workshop_panel, ("✓ " if game.selected_id == index else "") + actor.display_name, Vector2(25 + index * 150, 142), Vector2(140, 36), func(): game.select_survivor(index); _create_workshop())
	button(workshop_panel, "点燃炉火 · 燃料1", Vector2(810, 142), Vector2(240, 36), func(): game.expansion.ignite(game); _create_workshop())
	button(workshop_panel, "夜间取暖 " + ("开" if game.expansion.use_night_heat else "关"), Vector2(1065, 142), Vector2(295, 36), func(): game.expansion.use_night_heat = not game.expansion.use_night_heat; _create_workshop())
	label(workshop_panel, "夜间取暖出发前扣燃料（每份8小时，最多2份），归来物资不能补烧过去的夜晚。", Vector2(25, 189), Vector2(1040, 26), 14)
	button(workshop_panel, "净水泵 " + ("开：燃料1换水3/日" if game.expansion.pump_on else "关"), Vector2(1065, 187), Vector2(295, 36), func(): game.expansion.pump_on = not game.expansion.pump_on; _create_workshop())
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(25, 235)
	scroll.size = Vector2(1335, 595)
	workshop_panel.add_child(scroll)
	var content := Control.new()
	content.custom_minimum_size = Vector2(1300, 1)
	scroll.add_child(content)
	var y := 0.0
	label(content, "制作需要人物走到工作台并花时间；点击已装备物品可卸下。修理消耗材料2，恢复60耐久。", Vector2(0, y), Vector2(1280, 30), 15, game.GOLD)
	y += 42
	for kind in GearCatalog.ITEMS.keys() + GearCatalog.PROJECTS.keys():
		var recipe := GearCatalog.recipe(kind)
		label(content, recipe["name"] + " · " + ShelterInventory.describe(recipe["cost"]), Vector2(0, y), Vector2(610, 30), 17)
		var hint := GearCatalog.describe(kind) if GearCatalog.ITEMS.has(kind) else "弹药供手枪使用，射击会引来尸群。" if kind == "ammo" else "消耗带回的专属零件，完成后推进战役。"
		label(content, hint, Vector2(0, y + 30), Vector2(1025, 28), 14)
		var make := button(content, "制作 · %d秒" % recipe["seconds"], Vector2(1080, y + 3), Vector2(200, 42), func():
			if game.expansion.start_job(game, kind): close_workshop()
			else: _create_workshop()
		)
		make.disabled = game.cycle.phase != "day" or not game.inventory.can_take(recipe["cost"]) or (recipe.has("part") and not game.expansion.parts.has(recipe["part"])) or (kind == "radio" and game.expansion.stage != 0) or (kind == "pump" and game.expansion.stage != 2) or (kind == "beacon" and (game.expansion.stage != 3 or not game.expansion.parts.has("power_cell")))
		y += 73
	label(content, "装备仓库 · 弹药库存%d · 装备占背包，冬衣保暖不占格" % game.expansion.ammo, Vector2(0, y), Vector2(1200, 30), 21, game.GOLD)
	y += 43
	for item in game.expansion.gear:
		var kind: String = item["kind"]
		var name: String = GearCatalog.ITEMS[kind]["name"]
		label(content, "%s · 耐久%d/%d · %s" % [name, item["durability"], GearCatalog.ITEMS[kind]["durability"], "仓库" if item["owner"] == "" else PeopleCatalog.DATA[item["owner"]]["name"]], Vector2(0, y), Vector2(820, 36), 17)
		button(content, "装备 / 卸下", Vector2(850, y), Vector2(200, 36), func(): game.expansion.equip(game, int(item["id"]), game.selected_id); _create_workshop())
		var repair := button(content, "修理 · 材料2", Vector2(1080, y), Vector2(200, 36), func():
			if game.expansion.start_job(game, "repair", int(item["id"])): close_workshop()
		)
		repair.disabled = game.cycle.phase != "day" or item["durability"] >= GearCatalog.ITEMS[kind]["durability"]
		y += 51
	if game.expansion.gear.is_empty():
		label(content, "暂无装备，请在白天制作。", Vector2(0, y), Vector2(1200, 35))
		y += 45
	content.custom_minimum_size.y = y + 20


func _loot_icon(action: Button, resource: String) -> void:
	HudIcons.draw(action,resource,Vector2(50,30),29,Color("637064") if action.disabled else game.GOLD)
