class_name CampaignInterface
extends CanvasLayer
## Night assignment, deliberate loot transfer, construction and dawn report.
var game: Node2D
var root: Control
var overlay: Panel
var build_panel: Panel
var build_button: Button
var placement_hint: Label
var district_button: Button
var outpost_buttons: Dictionary = {}
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
var container_grid: BackpackGrid
var cargo_grid: BackpackGrid
var loot_title: Label
var loot_counts: Label
var climate_label: Label
var workshop_button: Button
var workshop_panel: Panel
var workshop_pause := false
var workshop_open := false
var workshop_section := "workbench"
var workshop_recipes: Dictionary = {}
var workshop_upgrade: Button
var workshop_summary: Label
var kitchen_batches: SpinBox
var workshop_scroll: ScrollContainer
var briefing_button: Button
var plan_forecast: Label
var map_page := 0
var part_button: Button
var survey_button: Button
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
	briefing_button = button(root,"街区动态 U",Vector2(1218,748),Vector2(190,36),func(): game.briefing.toggle())
	district_button = button(root,"街区 Y",Vector2(32,90),Vector2(134,34),func(): game.district_view.toggle())
	refresh(true)


func label(parent: Node, text: String, point: Vector2, size: Vector2, font_size: int = 18, color: Color = GameUi.TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.position = point
	node.size = size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.add_theme_font_override("font", game.FONT)
	node.add_theme_font_size_override("font_size", maxi(17,font_size))
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
	GameUi.button(node)
	node.pressed.connect(action)
	parent.add_child(node)
	node.size = size
	return node


func panel(parent: Node, point: Vector2, size: Vector2, color: Color = GameUi.PANEL) -> Panel:
	var node := Panel.new()
	node.theme = GameUi.theme()
	node.position = point
	node.size = size
	node.add_theme_stylebox_override("panel",GameUi.box(color))
	parent.add_child(node)
	node.size = size
	return node


func refresh(force: bool = false) -> void:
	if not is_instance_valid(root): return
	district_button.visible = game.cycle.phase in ["day","scavenge","returning"]
	briefing_button.visible = game.cycle.phase == "day" and game.placement.is_empty() and not game.context_open
	briefing_button.text = "补给待领取 U" if game.director.status == "ready" else "街区动态 U"
	workshop_button.visible = game.cycle.phase == "day"
	climate_label.visible = game.cycle.phase == "day"
	if climate_label.visible:
		climate_label.text = "战役第%d/35天 · 室外 %d℃ / 室内 %d℃  %s\n%s" % [game.expansion.day(game), game.expansion.outside(game), game.expansion.outside(game) + game.residence.indoor_bonus() + (18 if game.expansion.heater_remaining > 0 else 0), "炉火剩余%d分" % int(game.expansion.heater_remaining * 2) if game.expansion.heater_remaining > 0 else "炉火未点燃", game.expansion.objective(game)]
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
	plan_forecast = label(overlay,"",Vector2(38,80),Vector2(1300,30),18,GameUi.SECONDARY)
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
		var summary := label(overlay, LocationEnvironment.BRIEFS[id]+"\n"+game.regions[id].condition_name() if game.expansion.unlocked(game, id) else "尚未开放：" + game.expansion.lock_reason(id), Vector2(x + 16, 220), Vector2(405, 46), 14)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		map_buttons[id] = button(overlay, "选择地点", Vector2(x + 16, 267), Vector2(405, 35), func(): game.choose_destination(id); refresh())
		map_buttons[id].tooltip_text = area["summary"]+"\n"+LocationEnvironment.route_hint(id)+"\n通路状态："+("已打通" if game.regions[id].route_open else "待清障；原有楼梯始终可用")
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
		option.add_theme_font_size_override("font_size", 18)
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
	label(overlay, "精神：床眠+65，地铺+35；守夜−28，搜刮−35，轮值−45。\n武器、护甲各占1格；弹药每8发占1格。冬衣穿在身上。", Vector2(746, 757), Vector2(650, 44), 13)
	ammo_label = label(overlay, "", Vector2(746, 714), Vector2(430, 30), 15)
	button(overlay, "−8发", Vector2(1195, 714), Vector2(90, 32), _ammo.bind(-8))
	button(overlay, "+8发", Vector2(1300, 714), Vector2(90, 32), _ammo.bind(8))
	plan_error = label(overlay, "", Vector2(38, 786), Vector2(1100, 28), 15, Color("dca184"))
	button(overlay, "全员留守 · 不携带物资", Vector2(38, 829), Vector2(320, 44), _stay_home)
	button(overlay,"检查安防 Z",Vector2(380,829),Vector2(220,44),func(): game.security_view.toggle())
	button(overlay,"街区 / 轮值 Y",Vector2(620,829),Vector2(240,44),func(): game.district_view.toggle())
	depart_button = button(overlay, "开始这一夜 →", Vector2(1035, 829), Vector2(360, 44), func(): game.start_expedition())


func _set_role(index: int, role: String) -> void:
	if role == "dead" and game.survivors[index].health > 0: return
	if role in ["scavenge","outpost"]:
		for other in range(game.cycle.roles.size()):
			if game.cycle.roles[other] == role: game.cycle.roles[other] = "floor"
	game.cycle.roles[index] = role
	refresh()


func _refresh_plan() -> void:
	if role_options.size() != game.survivors.size(): return
	plan_forecast.text = game.night_forecast()
	for index in range(role_options.size()):
		var actor: Survivor = game.survivors[index]
		role_options[index].select(CampaignCycle.ROLES.find(game.cycle.roles[index]))
		role_options[index].disabled = actor.health <= 0 or not game.residence.convoy.is_empty()
		role_options[index].set_item_disabled(4, actor.health > 0)
		role_options[index].set_item_disabled(5,not game.districts.regions[game.districts.target]["built"])
		role_options[index].get_popup().set_item_tooltip(5,"先在现场建立前哨，Y选择轮值目标。每夜预留燃料1，轮值者不能同时守夜或睡眠。")
		role_stats[index].text = "生命%d 精神%d 饱腹%d · %s%d · %d格" % [Vitals.value(actor,"health"), Vitals.value(actor,"vigor"), Vitals.value(actor,"fullness"), actor.weapon().get("name", "徒手"), actor.weapon_item.get("durability", 0), CampaignCycle.BAGS[actor.person.persona]]
	var total := BackpackStacks.slots(game.cycle.loadout)
	total += game.expansion.reserved_slots(game)
	ammo_label.text = "弹药库存%d / 携带%d；取暖：%s" % [game.expansion.ammo, game.expansion.ammo_loadout, "预留燃料" if game.expansion.use_night_heat else "关闭（K调整）"]
	plan_capacity.text = "随身 %d / %d格 · %s" % [total,game.cycle.capacity(game),"轮值预留燃料1："+LocationCatalog.area(game.districts.target)["name"] if game.districts.operator(game) >= 0 else "据点库存确认出发才扣除"]
	for key in supply_labels:
		var amount := int(game.cycle.loadout.get(key, 0))
		supply_labels[key].text = "%s    库存%d    携带%d" % [ShelterInventory.NAMES[key], game.inventory.amount(key), amount]
		supply_buttons[key][0].disabled = amount <= 0
		supply_buttons[key][1].disabled = BackpackStacks.room(game.cycle.loadout,key,game.cycle.capacity(game),game.expansion.reserved_slots(game)) <= 0 or amount >= game.inventory.amount(key)
	for id in map_buttons:
		map_buttons[id].text = "✓ 当前目的地" if id == game.expedition.location_id else "选择地点"
		map_buttons[id].disabled = not game.expansion.unlocked(game, id)
	var error: String = game.cycle.plan_error(game)
	plan_error.text = "车队迁往" + ResidenceSystem.HOMES[game.residence.convoy]["name"] + "：全员整夜行军，不能搜刮或睡眠。" if not game.residence.convoy.is_empty() and error.is_empty() else error if not error.is_empty() else "岗位和装备已就绪。留守者不会在夜里继续白天的生产任务。"
	depart_button.disabled = not error.is_empty()
	depart_button.text = "出发迁居 →" if not game.residence.convoy.is_empty() else "开始搜刮 →" if game.cycle.scavenger() >= 0 else "留守并度过这一夜 →"


func _change_loadout(key: String, change: int) -> void:
	if change > 0 and (int(game.cycle.loadout.get(key,0)) >= game.inventory.amount(key) or BackpackStacks.room(game.cycle.loadout,key,game.cycle.capacity(game),game.expansion.reserved_slots(game)) <= 0): return
	var amount := maxi(0, int(game.cycle.loadout.get(key, 0)) + change)
	if amount == 0: game.cycle.loadout.erase(key)
	else: game.cycle.loadout[key] = amount
	refresh()


func _stay_home() -> void:
	var beds: int = game.cycle.bed_count()
	for index in range(game.cycle.roles.size()):
		if game.survivors[index].health <= 0: game.cycle.roles[index] = "dead"
		elif index == 0 or not game.residence.convoy.is_empty(): game.cycle.roles[index] = "guard"
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
	button(overlay,"安防复盘 Z",Vector2(350,731),Vector2(230,38),func(): game.security_view.toggle())
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
	panel(overlay,Vector2(100,130),Vector2(1240,650))
	loot_title = label(overlay,"",Vector2(135,151),Vector2(730,36),25,game.GOLD)
	loot_counts = label(overlay,"",Vector2(905,151),Vector2(390,36),21,game.GOLD)
	label(overlay,"容器",Vector2(150,201),Vector2(450,30),19)
	label(overlay,"随身背包",Vector2(815,201),Vector2(450,30),19)
	container_grid = BackpackGrid.new()
	container_grid.position = Vector2(150,240)
	container_grid.activated = _grid_take
	container_grid.available = _can_grid_take
	overlay.add_child(container_grid)
	cargo_grid = BackpackGrid.new()
	cargo_grid.position = Vector2(815,240)
	cargo_grid.activated = _grid_put
	cargo_grid.available = _can_grid_put
	overlay.add_child(cargo_grid)
	part_button = button(overlay, "", Vector2(150,607), Vector2(1108,38), func(): game.expansion.take_part(game); refresh())
	survey_button = button(overlay,"勘察新住处",Vector2(150,650),Vector2(1108,34),func(): game.residence.survey(game); refresh())
	outpost_buttons.clear()
	for index in range(3):
		var action: String = ["build","repair","suppress"][index]
		outpost_buttons[action] = button(overlay,"",Vector2(150+index*371,650),Vector2(357,34),func(): game.districts.begin_work(game,action))
	label(overlay, "点击转移1份 · Shift点击本格 · 空格暂停", Vector2(150,689), Vector2(1108,28), 13)
	button(overlay, "尽量全部拿走 F", Vector2(150,731), Vector2(300,36), _take_all)
	button(overlay, "返程 T", Vector2(470,731),Vector2(280,36), game.expedition_retreat)
	button(overlay, "关闭，继续行动 Esc", Vector2(815,731),Vector2(440,36), game.close_loot)


func _refresh_loot() -> void:
	var field: ExpeditionState = game.expedition
	if field.loot_site < 0: return
	var survey: String = game.residence.survey_target(field)
	survey_button.visible = not survey.is_empty()
	survey_button.disabled = not game.residence.carried.is_empty() or game.paused or (game.residence.surveyed.has(survey) and not game.residence.prepared.has(survey))
	if not survey.is_empty(): survey_button.text = ("已记录，须活着返回：" if game.residence.carried == survey else "确认清理（附近须无感染者）：" if game.residence.prepared.has(survey) else "勘察新住处：") + ResidenceSystem.HOMES[survey]["name"]
	var part_name := ""
	for key in GearCatalog.PARTS:
		var part: Dictionary = GearCatalog.PARTS[key]
		if part["map"] == field.location_id and part["site"] == field.loot_site and not game.expansion.collected.has(key): part_name = ("放回：" if game.expansion.carried.has(key) else "拿取：") + part["name"]
	part_button.text = "战役零件：%s（占1格，须活着带回）" % part_name if not part_name.is_empty() else "此处没有未收集的战役零件 · 随身%d件" % game.expansion.carried.size()
	part_button.visible = not part_name.is_empty()
	part_button.disabled = part_name.is_empty() or (field.used_capacity() >= field.capacity and not part_name.begins_with("放回"))
	var at_outpost: bool = field.loot_site == DistrictSystem.POINTS[field.location_id]
	for action in outpost_buttons:
		var node: Button = outpost_buttons[action]
		node.visible = at_outpost
		node.text = {"build":"建立前哨 · 材料5 工具1","repair":"修整前哨 · 材料2","suppress":"清理街区 · 材料1 燃料1"}[action]
		node.add_theme_font_size_override("font_size",17)
		var action_error: String = game.districts.action_error(game,action)
		node.disabled = not action_error.is_empty()
		node.tooltip_text = action_error if node.disabled else DistrictSystem.ACTION_NAMES[action]+" · %.0f秒，完成时扣除背包用料。" % DistrictSystem.SECONDS[action]
	var site: Dictionary = field.sites[field.loot_site]
	loot_title.text = field.site_definitions()[field.loot_site]["name"]
	loot_counts.text = "背包 %d / %d格%s" % [field.used_capacity(), field.capacity, " · 已暂停" if game.paused else ""]
	var contents := BackpackStacks.entries(site["contents"])
	for key in GearCatalog.PARTS:
		var part: Dictionary = GearCatalog.PARTS[key]
		if part["map"] == field.location_id and part["site"] == field.loot_site and not game.expansion.collected.has(key) and not game.expansion.carried.has(key):
			contents.append({"kind":"part","key":key,"count":1,"limit":1})
	container_grid.render(contents,16)
	cargo_grid.render(BackpackStacks.carried(field,game.survivors[field.actor_id],game.expansion.carried),field.capacity)
	loot_buttons = container_grid.first_resources
	loot_returns = cargo_grid.first_resources


func _can_grid_take(entry: Dictionary) -> bool:
	return game.expedition.room_for(entry["key"]) > 0 if entry["kind"] == "resource" else game.expedition.used_capacity() < game.expedition.capacity


func _can_grid_put(entry: Dictionary) -> bool:
	if entry["kind"] == "part":
		var part: Dictionary = GearCatalog.PARTS[entry["key"]]
		return part["map"] == game.expedition.location_id and part["site"] == game.expedition.loot_site
	if entry["kind"] != "resource": return false
	var site: Dictionary = game.expedition.sites[game.expedition.loot_site]
	var bound: int = game.expedition.site_definitions()[game.expedition.loot_site]["items"].get(entry["key"],0)
	return int(site["contents"].get(entry["key"],0)) < bound


func _grid_take(entry: Dictionary, count: int) -> void:
	if entry["kind"] == "resource": game.expedition.take_loot(entry["key"],count,game.survivors[game.expedition.actor_id])
	else: game.expansion.take_part(game)
	refresh()


func _grid_put(entry: Dictionary, count: int) -> void:
	if entry["kind"] == "resource": game.expedition.put_loot(entry["key"],count)
	elif entry["kind"] == "part": game.expansion.take_part(game)
	refresh()


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
	workshop_panel = WorkshopView.render(self)


func _loot_icon(action: Button, resource: String) -> void:
	HudIcons.draw(action,resource,Vector2(50,30),29,Color("637064") if action.disabled else game.GOLD)
