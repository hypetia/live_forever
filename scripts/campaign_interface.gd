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
var production_counts:Dictionary={}
var production_modes:Dictionary={}
var production_actions:Dictionary={}
var role_options: Array[OptionButton] = []
var role_stats: Array[Label] = []
var plan_stock_labels: Dictionary = {}
var plan_rows: Dictionary = {}
var plan_ammo_stock: Label
var plan_heat: CheckBox
var role_equipment_buttons: Dictionary = {}
var equipment_button: Button
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
var workshop_owner_choices: Dictionary = {}
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
var target_door_state := -1
var target_door_side := 0
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
	workshop_button = button(root, "制作 / 战役 K", Vector2(1212, 150), Vector2(200, 42), toggle_workshop)
	climate_label = label(root, "", Vector2(32, 151), Vector2(990, 62), 15)
	briefing_button = button(root,"委托 U",Vector2(1218,748),Vector2(190,36),func(): game.briefing.toggle())
	district_button = button(root,"街区 Y",Vector2(32,90),Vector2(134,34),func(): game.district_view.toggle())
	equipment_button = button(root,"装备 O",Vector2(850,748),Vector2(140,36),func(): game.equipment_view.open_for())
	refresh(true)


func label(parent: Node, text: String, point: Vector2, size: Vector2, font_size: int = 18, color: Color = GameUi.TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.position = point
	node.size = size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.add_theme_font_override("font",GameUi.heading_font() if font_size>=24 else game.FONT)
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
	briefing_button.text = "领取报酬 U" if game.director.status == "ready" else "委托 U"
	equipment_button.visible = game.cycle.phase == "day"
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
		plan_stock_labels.clear()
		plan_rows.clear()
		role_equipment_buttons.clear()
		supply_buttons.clear()
		supply_labels.clear()
		map_buttons.clear()
		loot_buttons.clear()
		loot_returns.clear()
		if not mode.is_empty():
			build_open = false
			if is_instance_valid(build_panel): build_panel.hide()
			overlay = panel(root, Vector2.ZERO, Vector2(1440, 900), GameUi.PANEL)
			if mode == "planning": _create_plan()
			elif mode == "dawn": _create_dawn()
			else: _create_loot()
	if mode == "planning": _refresh_plan()
	elif mode == "loot": _refresh_loot()
	elif mode == "dawn" and force:
		# Rebuild the summary only when its saved ledger changes.
		pass


func _create_plan() -> void:
	GameUi.paper(overlay,Rect2(0,0,1440,900))
	label(overlay,"夜间准备",Vector2(36,24),Vector2(500,45),30)
	label(overlay,"第 %02d 夜   /   20:00—06:00"%game.cycle.night_day,Vector2(36,70),Vector2(700,28),17,GameUi.SECONDARY)
	button(overlay,"保存 F6",Vector2(1260,30),Vector2(144,38),func():game.save_game())
	GameUi.line(overlay,Vector2(36,112),Vector2(1404,112))
	plan_forecast=label(overlay,"",Vector2(36,122),Vector2(1368,28),17,GameUi.SECONDARY)
	label(overlay,"探索地点",Vector2(36,163),Vector2(330,28),20,game.GOLD)
	label(overlay,"人员安排",Vector2(408,163),Vector2(300,28),20,game.GOLD)
	label(overlay,"床位 %d"%game.cycle.bed_count(),Vector2(900,163),Vector2(120,28),17,GameUi.SECONDARY)
	label(overlay,"出行背包",Vector2(1044,163),Vector2(280,28),20,game.GOLD)
	GameUi.line(overlay,Vector2(395,163),Vector2(395,774))
	GameUi.line(overlay,Vector2(1032,163),Vector2(1032,774))
	for index in range(LocationCatalog.ALL_IDS.size()):
		var id: String=LocationCatalog.ALL_IDS[index]
		var row:=button(overlay,"",Vector2(36,203+index*63),Vector2(348,59),func():game.choose_destination(id);refresh())
		var totals: Dictionary={}
		for site in LocationCatalog.area(id)["sites"]:
			for key in site["items"]:totals[key]=int(totals.get(key,0))+int(site["items"][key])
		var resources: Array=totals.keys();resources.sort_custom(func(a,b):return totals[a]>totals[b])
		row.set_meta("resources",resources.slice(0,2))
		row.draw.connect(_draw_plan_map.bind(row,id))
		row.tooltip_text=LocationCatalog.area(id)["summary"]+"\n"+RegionalThreats.brief(game,id)+"\n"+LocationEnvironment.route_hint(id)+"\n"+("通路已清理" if game.regions[id].route_open else "通路尚未清理")
		map_buttons[id]=row
	var live_row:=0
	for index in range(game.survivors.size()):
		var actor: Survivor=game.survivors[index]
		var y:=203.0+live_row*112
		var row_start:=overlay.get_child_count()
		var card:=panel(overlay,Vector2(408,y),Vector2(612,103),GameUi.SURFACE.darkened(.25))
		card.draw.connect(func():
			ActorVisual.portrait(card,actor.person.persona,Rect2(12,10,50,82))
			if game.cycle.roles[index]=="scavenge":card.draw_rect(Rect2(0,0,3,103),game.GOLD)
		)
		plan_rows[index]=card
		label(overlay,actor.display_name,Vector2(484,y+9),Vector2(250,26),21)
		role_stats.append(label(overlay,"",Vector2(484,y+40),Vector2(283,25),16,GameUi.SECONDARY))
		label(overlay,actor.speciality+"  /  背包%d格"%CampaignCycle.BAGS[actor.person.persona],Vector2(484,y+72),Vector2(275,22),15,GameUi.MUTED)
		role_equipment_buttons[index]=[]
		for slot_index in range(4):
			var gear_button:=button(overlay,"",Vector2(778+slot_index*59,y+53),Vector2(54,44),func():game.equipment_view.open_for(index,slot_index))
			gear_button.draw.connect(_draw_plan_gear.bind(gear_button,index,slot_index))
			role_equipment_buttons[index].append(gear_button)
		var option:=OptionButton.new();option.position=Vector2(792,y+9);option.size=Vector2(210,34)
		option.add_theme_font_override("font",game.FONT);option.add_theme_font_size_override("font_size",18)
		for name in CampaignCycle.ROLE_NAMES:option.add_item(name)
		var hints: Array=["单人搜刮；精神消耗35","守夜；精神消耗28","休息恢复最多65精神；需要床位","休息恢复最多35精神","已故","驻守前哨；需要燃料1"]
		for item in range(hints.size()):option.get_popup().set_item_tooltip(item,hints[item])
		option.item_selected.connect(func(item: int):_set_role(index,CampaignCycle.ROLES[item]))
		overlay.add_child(option);role_options.append(option)
		for child in overlay.get_children().slice(row_start):child.visible=actor.health>0
		if actor.health>0:live_row+=1
	plan_capacity=label(overlay,"",Vector2(1044,200),Vector2(360,28),19)
	plan_capacity.mouse_filter=Control.MOUSE_FILTER_PASS
	plan_capacity.tooltip_text="武器、护甲、工具各占1格，弹药每8发占1格；衣物不占格。\n睡床恢复精神65，地铺恢复35；守夜消耗28，搜刮35，驻守45。"
	label(overlay,"物资",Vector2(1056,242),Vector2(120,24),16,GameUi.MUTED)
	label(overlay,"库存",Vector2(1190,242),Vector2(48,24),16,GameUi.MUTED)
	label(overlay,"携带",Vector2(1292,242),Vector2(80,24),16,GameUi.MUTED)
	var row:=0
	for key in ShelterInventory.NAMES:
		var y:=279.0+row*43
		overlay.draw.connect(func():HudIcons.draw(overlay,key,Vector2(1066,y+14),18,GameUi.SECONDARY))
		label(overlay,ShelterInventory.NAMES[key],Vector2(1090,y),Vector2(95,28),17)
		plan_stock_labels[key]=label(overlay,"",Vector2(1190,y),Vector2(48,28),18,GameUi.SECONDARY)
		supply_labels[key]=label(overlay,"",Vector2(1296,y),Vector2(40,28),18)
		supply_labels[key].horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		supply_buttons[key]=[button(overlay,"−",Vector2(1254,y-2),Vector2(34,32),_change_loadout.bind(key,-1)),button(overlay,"+",Vector2(1344,y-2),Vector2(34,32),_change_loadout.bind(key,1))]
		row+=1
	GameUi.line(overlay,Vector2(1044,600),Vector2(1404,600))
	label(overlay,"弹药",Vector2(1056,618),Vector2(125,28),18)
	plan_ammo_stock=label(overlay,"",Vector2(1190,618),Vector2(48,28),18,GameUi.SECONDARY)
	ammo_label=label(overlay,"",Vector2(1296,618),Vector2(40,28),18);ammo_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button(overlay,"−8",Vector2(1250,616),Vector2(42,34),_ammo.bind(-8))
	button(overlay,"+8",Vector2(1340,616),Vector2(42,34),_ammo.bind(8))
	plan_heat=CheckBox.new();plan_heat.text="夜间取暖";plan_heat.position=Vector2(1048,680);plan_heat.size=Vector2(330,40);plan_heat.focus_mode=Control.FOCUS_NONE
	plan_heat.tooltip_text="取暖炉每份燃料维持8小时。燃料在出发时扣除。"
	plan_heat.toggled.connect(func(value: bool):game.expansion.use_night_heat=value);overlay.add_child(plan_heat)
	var help:=label(overlay,"负重规则",Vector2(1056,738),Vector2(340,26),15,GameUi.MUTED)
	help.tooltip_text=plan_capacity.tooltip_text;help.mouse_filter=Control.MOUSE_FILTER_PASS
	GameUi.line(overlay,Vector2(36,794),Vector2(1404,794))
	plan_error=label(overlay,"",Vector2(36,802),Vector2(960,26),17,GameUi.DANGER)
	button(overlay,"安防 Z",Vector2(36,842),Vector2(120,38),func():game.security_view.toggle())
	button(overlay,"前哨 Y",Vector2(168,842),Vector2(120,38),func():game.district_view.toggle())
	button(overlay,"装备 O",Vector2(300,842),Vector2(120,38),func():game.equipment_view.open_for())
	button(overlay,"取消外出",Vector2(1016,838),Vector2(164,44),_stay_home)
	depart_button=button(overlay,"出发",Vector2(1196,838),Vector2(208,44),func():game.start_expedition());GameUi.primary(depart_button)


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
		role_stats[index].text = "生命 %d   精神 %d   饱腹 %d" % [Vitals.value(actor,"health"),Vitals.value(actor,"vigor"),Vitals.value(actor,"fullness")]
		role_stats[index].add_theme_color_override("font_color",GameUi.DANGER if mini(Vitals.value(actor,"health"),mini(Vitals.value(actor,"vigor"),Vitals.value(actor,"fullness")))<=20 else GameUi.SECONDARY)
		plan_rows[index].tooltip_text=Vitals.summary(actor)+"\n背包%d格"%CampaignCycle.BAGS[actor.person.persona]
		plan_rows[index].queue_redraw()
		for slot_index in range(4):
			var entry: Dictionary = EquipmentArt.slots(actor)[slot_index]
			var gear_button: Button = role_equipment_buttons[index][slot_index]
			gear_button.tooltip_text = EquipmentLoadout.SLOT_NAMES[slot_index]+"："+entry["name"]+" · 点击分配"
			gear_button.queue_redraw()

	var total := BackpackStacks.slots(game.cycle.loadout)
	total += game.expansion.reserved_slots(game)
	ammo_label.text=str(game.expansion.ammo_loadout)
	plan_ammo_stock.text=str(game.expansion.ammo)
	plan_capacity.text="%d / %d 格"%[total,game.cycle.capacity(game)]
	plan_capacity.tooltip_text="武器、护甲、工具各占1格，弹药每8发占1格；衣物不占格。"
	if game.districts.operator(game)>=0:plan_capacity.tooltip_text+="\n轮值预留燃料1："+LocationCatalog.area(game.districts.target)["name"]
	plan_heat.set_pressed_no_signal(game.expansion.use_night_heat)
	plan_heat.disabled=not game.cycle.has_build("heater")
	if plan_heat.disabled:plan_heat.tooltip_text="需要建造取暖炉"
	for key in supply_labels:
		var amount := int(game.cycle.loadout.get(key, 0))
		supply_labels[key].text=str(amount)
		plan_stock_labels[key].text=str(game.inventory.amount(key))
		supply_buttons[key][0].disabled = amount <= 0
		supply_buttons[key][1].disabled = BackpackStacks.room(game.cycle.loadout,key,game.cycle.capacity(game),game.expansion.reserved_slots(game)) <= 0 or amount >= game.inventory.amount(key)
	for id in map_buttons:
		map_buttons[id].queue_redraw()
		GameUi.tab(map_buttons[id],id==game.expedition.location_id)
		map_buttons[id].disabled = not game.expansion.unlocked(game, id)
	var error: String = game.cycle.plan_error(game)
	plan_error.text="迁往 "+ResidenceSystem.HOMES[game.residence.convoy]["name"]+" · 全员行军" if not game.residence.convoy.is_empty() and error.is_empty() else error
	depart_button.disabled=not error.is_empty()
	depart_button.text="迁居" if not game.residence.convoy.is_empty() else "出发" if game.cycle.scavenger()>=0 else "留守过夜"
	depart_button.tooltip_text=error if not error.is_empty() else "确认人员、装备与携带物资，开始夜间行动。"



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
	GameUi.paper(overlay,Rect2(0,0,1440,900))
	label(overlay,"行动报告",Vector2(36,24),Vector2(1000,45),30)
	label(overlay,"第 %02d 天  /  06:00"%ExpeditionState.day_at(game.simulation_time),Vector2(36,75),Vector2(1000,28),17,GameUi.SECONDARY)
	GameUi.line(overlay,Vector2(36,120),Vector2(1404,120))
	label(overlay,"人员状态",Vector2(36,141),Vector2(410,30),20,game.GOLD)
	label(overlay,"夜间记录",Vector2(472,141),Vector2(900,30),20,game.GOLD)
	var live_row:=0
	for index in range(game.survivors.size()):
		var actor:Survivor=game.survivors[index]
		var card:=SurvivorCard.new();card.game=game;card.member_id=index
		card.position=Vector2(36,190+live_row*115);card.size=Vector2(400,86);card.tooltip_text=Vitals.summary(actor);overlay.add_child(card)
		var role:String=game.cycle.roles[index] if index<game.cycle.roles.size() else "floor"
		label(overlay,CampaignCycle.ROLE_NAMES[CampaignCycle.ROLES.find(role)],card.position+Vector2(61,86),Vector2(330,24),15,GameUi.SECONDARY)
		live_row+=1
	var scroll:=ScrollContainer.new();scroll.position=Vector2(472,190);scroll.size=Vector2(932,579);overlay.add_child(scroll)
	var lines:=Label.new();lines.text=_report_text(false);lines.add_theme_font_override("font",game.FONT);lines.add_theme_font_size_override("font_size",18);lines.add_theme_color_override("font_color",GameUi.TEXT);lines.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;lines.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(lines)
	GameUi.line(overlay,Vector2(450,141),Vector2(450,774));GameUi.line(overlay,Vector2(36,807),Vector2(1404,807))
	button(overlay,"保存 F6",Vector2(36,838),Vector2(144,44),func():game.save_game())
	button(overlay,"读取 F9",Vector2(196,838),Vector2(144,44),game.request_load)
	button(overlay,"安防记录 Z",Vector2(356,838),Vector2(164,44),func():game.security_view.toggle())
	var detail:=button(overlay,"完整记录",Vector2(536,838),Vector2(144,44),func():pass)
	detail.pressed.connect(func():var full:bool=detail.text=="完整记录";lines.text=_report_text(full);detail.text="简要记录" if full else "完整记录")
	var begin:=button(overlay,"进入白天",Vector2(1196,838),Vector2(208,44),game.begin_day);GameUi.primary(begin)
	begin.disabled=game.game_over or (not game.expansion.outcome.is_empty() and not game.expansion.endless)
	if not game.expansion.outcome.is_empty() and not game.expansion.endless:
		begin.text="继续生存";begin.disabled=game.game_over
		for connection in begin.pressed.get_connections():begin.pressed.disconnect(connection["callable"])
		begin.pressed.connect(func():game.expansion.endless=true;game.begin_day())
	if game.game_over:
		begin.hide()
		GameUi.primary(button(overlay,"新建战役",Vector2(1196,838),Vector2(208,44),game.request_new_game))


func _create_loot() -> void:
	overlay.add_theme_stylebox_override("panel", game._style(Color(0.02, 0.04, 0.04, 0.48), Color("52634c")))
	panel(overlay,Vector2(100,130),Vector2(1240,650))
	loot_title = label(overlay,"",Vector2(135,151),Vector2(730,36),25,game.GOLD)
	loot_counts = label(overlay,"",Vector2(905,151),Vector2(390,36),21,game.GOLD)
	label(overlay,"容器",Vector2(150,201),Vector2(450,30),19)
	label(overlay,"随身背包",Vector2(815,201),Vector2(450,30),19)
	container_grid = BackpackGrid.new()
	container_grid.position = Vector2.ZERO
	container_grid.activated = _grid_take
	container_grid.available = _can_grid_take
	var container_scroll:=ScrollContainer.new();container_scroll.position=Vector2(150,240);container_scroll.size=Vector2(475,355);container_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;overlay.add_child(container_scroll);container_scroll.add_child(container_grid)
	cargo_grid = BackpackGrid.new()
	cargo_grid.position = Vector2.ZERO
	cargo_grid.activated = _grid_put
	cargo_grid.available = _can_grid_put
	var cargo_scroll:=ScrollContainer.new();cargo_scroll.position=Vector2(815,240);cargo_scroll.size=Vector2(475,355);cargo_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;overlay.add_child(cargo_scroll);cargo_scroll.add_child(cargo_grid)
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
		node.text = {"build":"建立前哨 · 材料5 零件1","repair":"修整前哨 · 材料2","suppress":"清理街区 · 材料1 燃料1"}[action]
		node.add_theme_font_size_override("font_size",17)
		var action_error: String = game.districts.action_error(game,action)
		node.disabled = not action_error.is_empty()
		node.tooltip_text = action_error if node.disabled else DistrictSystem.ACTION_NAMES[action]+" · %.0f秒，完成时扣除背包用料。" % DistrictSystem.SECONDS[action]
	var site: Dictionary = field.sites[field.loot_site]
	loot_title.text = field.site_definitions()[field.loot_site]["name"]
	loot_counts.text = "背包 %d / %d格%s" % [field.used_capacity(), field.capacity, " · 已暂停" if game.paused else ""]
	var contents := BackpackStacks.entries(site["contents"])
	if game.camp.enabled:contents.append_array(game.camp.food.cache_entries(game))
	for key in GearCatalog.PARTS:
		var part: Dictionary = GearCatalog.PARTS[key]
		if part["map"] == field.location_id and part["site"] == field.loot_site and not game.expansion.collected.has(key) and not game.expansion.carried.has(key):
			contents.append({"kind":"part","key":key,"count":1,"limit":1})
	contents.append_array(game.production.cache_entries(game))
	container_grid.render(contents,16)
	var carried:=BackpackStacks.carried(field,game.survivors[field.actor_id],game.expansion.carried,game.camp.food.cargo_entries() if game.camp.enabled else [])
	carried.append_array(game.production.cargo_entries())
	cargo_grid.render(carried,field.capacity)
	loot_buttons = container_grid.first_resources
	loot_returns = cargo_grid.first_resources


func _can_grid_take(entry: Dictionary) -> bool:
	if entry["kind"]=="provision":return game.camp.food.room(game,entry["key"])>0
	return game.expedition.room_for(entry["key"]) > 0 if entry["kind"] == "resource" else game.expedition.used_capacity() < game.expedition.capacity


func _can_grid_put(entry: Dictionary) -> bool:
	if entry["kind"]=="provision":return game.camp.food.cache_room(game,entry["key"])>0
	if entry["kind"]=="tool_cache":return game.production.cache_entries(game).is_empty() and WorkshopProduction.CACHES[entry["cache"]]["map"]==game.expedition.location_id and WorkshopProduction.CACHES[entry["cache"]]["site"]==game.expedition.loot_site
	if entry["kind"] == "part":
		var part: Dictionary = GearCatalog.PARTS[entry["key"]]
		return part["map"] == game.expedition.location_id and part["site"] == game.expedition.loot_site
	if entry["kind"] != "resource": return false
	var site: Dictionary = game.expedition.sites[game.expedition.loot_site]
	var bound: int = game.expedition.site_definitions()[game.expedition.loot_site]["items"].get(entry["key"],0)
	return int(site["contents"].get(entry["key"],0)) < bound


func _grid_take(entry: Dictionary, count: int) -> void:
	if entry["kind"]=="tool_cache":game.production.transfer(game,entry["cache"])
	elif entry["kind"]=="provision":game.camp.food.transfer(game,entry["key"],count)
	elif entry["kind"] == "resource": game.expedition.take_loot(entry["key"],count,game.survivors[game.expedition.actor_id])
	else: game.expansion.take_part(game)
	refresh()


func _grid_put(entry: Dictionary, count: int) -> void:
	if entry["kind"]=="tool_cache":game.production.transfer(game,entry["cache"],true)
	elif entry["kind"]=="provision":game.camp.food.transfer(game,entry["key"],count,true)
	elif entry["kind"] == "resource": game.expedition.put_loot(entry["key"],count)
	elif entry["kind"] == "part": game.expansion.take_part(game)
	refresh()


func _take(key: String) -> void:
	game.expedition.take_loot(key, 1, game.survivors[game.expedition.actor_id])
	refresh()


func _put(key: String) -> void:
	game.expedition.put_loot(key, 1)
	refresh()


func _take_all() -> void:
	for entry in game.production.cache_entries(game):game.production.transfer(game,entry["cache"])
	for key in ShelterInventory.NAMES: game.expedition.take_loot(key, 1000, game.survivors[game.expedition.actor_id])
	if game.camp.enabled:
		for key in CampFoodCatalog.ITEMS:game.camp.food.transfer(game,key,1000)
	refresh()


func set_target(x: float, floor_level: int, run: bool, site: int) -> void:
	has_move_target = true
	target_door_state = -1
	target_door_side = 0
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

func _draw_plan_gear(button_node: Button, actor_id: int, slot_index: int) -> void:
	var entry: Dictionary=EquipmentArt.slots(game.survivors[actor_id])[slot_index]
	EquipmentArt.icon(button_node,entry,Vector2(26,14))
	button_node.draw_string(game.FONT,Vector2(1,37),("开锁器" if entry["kind"]=="lockpick" else entry["name"]),HORIZONTAL_ALIGNMENT_CENTER,52,12,GameUi.TEXT)
	if not entry["kind"].is_empty():
		button_node.draw_rect(Rect2(4,40,46,2),GameUi.BORDER)
		button_node.draw_rect(Rect2(4,40,46*entry["ratio"],2),GameUi.ACCENT if not entry["broken"] else GameUi.DANGER)

func _draw_plan_map(row: Button,id: String) -> void:
	var area:=LocationCatalog.area(id)
	var tile: int=RealismAssets.LOCATIONS[id]
	row.draw_texture_rect_region(RealismAssets.PLACES,Rect2(9,8,48,43),Rect2((tile%3)*512+128,(tile/3)*256,256,256),Color(.78,.78,.7))
	var unlocked: bool=game.expansion.unlocked(game,id)
	var resources: Array=row.get_meta("resources",[])
	for index in range(resources.size()):HudIcons.draw(row,resources[index],Vector2(292+index*31,19),14,GameUi.SECONDARY if unlocked else GameUi.MUTED)
	row.draw_string(game.FONT,Vector2(69,23),area["name"],HORIZONTAL_ALIGNMENT_LEFT,208,19,GameUi.TEXT if unlocked else GameUi.MUTED)
	row.draw_string(game.FONT,Vector2(69,46),RegionalThreats.brief(game,id) if unlocked else "未开放",HORIZONTAL_ALIGNMENT_LEFT,264,15,GameUi.SECONDARY if unlocked else GameUi.MUTED)

func _report_text(full: bool) -> String:
	var lines: PackedStringArray=[]
	for line: String in game.cycle.report:
		if full:lines.append(line);continue
		if "F5可查看食材保鲜" in line:continue
		if "疾病0、寒冷0、衣物保暖+0℃" in line:continue
		if "这一夜没有尸群袭击，没有物资损失，也未损耗安防耐久" in line:line="安防：未遭袭击。"
		line=line.replace("，需处理后饮用。","")
		lines.append(line)
	return "\n\n".join(lines)
