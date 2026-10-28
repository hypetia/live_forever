class_name CommandCenter
extends AcceptDialog
## Pause menu with real destination choices, upkeep, event decisions and guide.

var game: Node2D
var new_button: Button
var load_button: Button
var tabs: TabContainer
var map_labels: Dictionary = {}
var map_buttons: Dictionary = {}
var structure_label: Label
var upgrade_button: Button
var repair_button: Button
var event_label: Label
var accept_event: Button
var decline_event: Button
var records: Label
var effects_check: CheckBox
var ambience_check: CheckBox
var fullscreen_check: CheckBox
var volume_slider: HSlider
var _paused_before := false
var roster_picker: OptionButton
var person_text: Label
var drink_button: Button
var routine_toggle: CheckBox
var cooking_toggle: CheckBox
var support_picker: OptionButton
var support_button: Button
var aid_button: Button
var relationship_text: Label
var candidate_picker: OptionButton
var candidate_text: Label
var recruit_button: Button
var storage_text: Label
var guide_text: Label
var guide_toggle: CheckBox
var guide_people_button: Button
var story_text: Label
var story_paid: Button
var story_free: Button
var story_history: Label
var goal_picker: OptionButton
var goal_text: Label
var goal_button: Button
var trade_text: Label
var trade_buttons: Dictionary = {}


func _ready() -> void:
	title = "街区手册"
	min_size = Vector2i(1040, 650)
	get_label().hide()
	ok_button_text = "返回游戏  [Esc]"
	var skin := GameUi.theme()
	skin.default_font = preload("res://assets/fonts/interface.otf")
	skin.default_font_size = 18
	theme = skin
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(1000, 550)
	add_child(tabs)
	var maps := _page("探索地点")
	_text(maps, "每个地点独立保存。物资不会因换地点重置；出发前先安排留守工作。", 16)
	for id in LocationCatalog.IDS:
		var area := LocationCatalog.area(id)
		var label := _text(maps, "", 17)
		map_labels[id] = label
		var button := _action(maps, "准备去" + area["name"], _prepare.bind(id))
		map_buttons[id] = button
	var base := _page("庇护所")
	structure_label = _text(base, "", 18)
	repair_button = _action(base, "安排当前角色修整 · 材料1 → 结构+18", _repair)
	upgrade_button = _action(base, "", _upgrade)
	_text(base, "低于40%结构，生产会降速；吃饭、睡觉和治疗不受影响。升级降低磨损、提高生产速度，不能让物资自给自足。", 14)
	event_label = _text(base, "", 16)
	accept_event = _action(base, "", _event.bind(true))
	decline_event = _action(base, "保留物资 / 放弃这次机会", _event.bind(false))
	var history := _page("生存记录")
	records = _text(history, "", 16)
	var help := _page("操作指南")
	_text(help, "第一次游玩", 23)
	if game.has_method("_compact_card"):
		_text(help, "1. 白天点设施安排制作、饮食和休息；A/D移动，楼梯口W/S上下楼，Shift奔跑。\n2. 20:00安排搜刮、守夜和睡眠；K页制作、分配装备。开局三张地图，后续按战役开放，共九张。\n3. 夜里A/D或鼠标走动，Ctrl潜行，W/S爬梯；点箱柜或靠近后按住E搜索，F尽量全拿。\n4. J攻击，L手枪换弹；手中显示实际武器。点人物卡右侧装备图标，暂停查看耐久与效果。\n5. 走到地面左／右最边缘确认离开；T也可安排回左侧出口。确认前不入库，取消继续探索。\n6. R让选中者自己用药，P页可由医护帮助别人；F6保存，F9读档，F11全屏。\n7. U查看街区动态、风险预报与可选委托；实地完成目标后返回接收补给。", 16)
	else:
		_text(help, "1. 给留守者排好任务：F做饭 → G吃饭 → H睡觉。没有熟食时也能预排。\n2. 按3选里昂，再按V选地点；初次建议河湾旧街。装备可选。\n3. A/D移动，Ctrl潜行，Shift奔跑；靠近箱柜按住E搜索。\n4. 看敌人朝向和警觉；J有前摇，有工具时消耗一件击倒，徒手只推开。\n5. 带着物资走回最左侧入口按T，才能带回基地。\n6. 归来会暂停，检查伤势 / 感染，必要时R让归来者给自己用药（医护帮别人请在P页选择双方），再继续。", 16)
	_text(help, "完整操作", 23)
	if game.has_method("plan_self_care"):
		_text(help, "白天：点人物或小卡选人，A/D移动，W/S在楼梯口上下楼；点设施走过去使用，Shift追加任务，Q取消。B建设，K设施与装备，H家园，P人物。\n基本自理默认开启：饱腹、水分≤35或精神≤30时，空闲角色会自行吃饭、喝水或休息；P页可逐人关闭。自动做饭是独立开关，默认关闭，会消耗生食、水和燃料。\n夜间：A/D或左键移动，Ctrl潜行，W/S爬梯，E按住搜索，F尽量拿取，J攻击，L换弹，I背包，B用水，G投诱饵，Y街区图。T安排回程，地面两端确认离开才入库。\n背包按物品种类堆叠；武器、护甲和专属零件占格。死亡永久丢失成员与随身物资。\n通用：空格暂停，F6保存，F9确认读档，F11全屏，Esc菜单；35日撤离战役结束后可继续无尽生存。", 15)
	else:
		_text(help, "基地：1–6或底部人物卡选人；点击场景设施展开行动，E确认；右键地面移动（取消此人任务并退料）；F做饭、G吃饭、H睡觉、C制工具、R让选中者自行用药、Q取消、V出发、M街区手册、P人物。\n外出：A/D或方向键移动，W/S上下梯，E按住搜索，J挥击（命中/挥空会在现场显示）、I展开背包、R急救、B用背包水、T入口撤退；按I展开背包后点击资源丢弃一份，无法拾回。\n通用：空格暂停、F6保存、F9确认读档、F1指南、Esc菜单。外出固定1x。\n背包10格，每份资源和携带装备各占一格；未拿走的东西留在箱中。每日仅两处补给轮换，活动中不刷新。\n死亡永久丢失该成员与背包；没有固定天数结局，里程碑后仍可继续。", 15)
	_text(help, "人物与长期生存", 23)
	if game.has_method("plan_self_care"):
		_text(help, "P查看人物、工艺 / 照护 / 探索成长，每项最多3级，加速最多15%。\n基本自理默认开启，空闲时会走到真实设施吃饭、喝水和休息；手动任务优先。缺饭时自动做饭在P页单独开启，药品与工具由你安排。水分低于20降效、低至5伤生命。\n医护可以消耗药品援助队友，共餐安慰消耗熟食；两种行动都有每人180秒冷却。\n第3、6、9天有不同来访者，需要一级据点、生食2、水2、药品1，最多五人存活在队；不会复活旧成员。\n超额食物每清晨按明确比例损耗，升级只提高有限保鲜容量，不会生产物资。\n徒手推搡消耗疲劳；敌人被推后会短暂稳身，不能连续压制，留意扑咬前摇并后退。", 15)
	else:
		_text(help, "P查看人物、工艺 / 照护 / 探索成长，每项最多3级，加速最多15%。\n可逐人授权自动饮水、做饭、吃饭和睡觉，默认关闭；药品与工具仍由你安排。水分低于20降效、低至5伤生命。\n医护可以消耗药品援助队友，共餐安慰消耗熟食；两种行动都有每人180秒冷却。\n第3、6、9天有不同来访者，需要一级据点、生食2、水2、药品1，最多五人存活在队；不会复活旧成员。\n超额食物每清晨按明确比例损耗，升级只提高有限保鲜容量，不会生产物资。\n徒手推搡消耗疲劳；敌人被推后会短暂稳身，不能连续压制，留意扑咬前摇并后退。", 15)
	var settings := _page("设置 / 退出")
	_text(settings, "暂停中 · 你的队伍和外出现场都会等待", 20)
	effects_check = _check(settings, "操作与事件提示音", game.game_audio.enabled, func(value: bool): game.game_audio.enabled = value; game.game_audio.apply_preferences())
	ambience_check = _check(settings, "风声环境音", game.game_audio.ambience, func(value: bool): game.game_audio.ambience = value; game.game_audio.apply_preferences())
	_text(settings, "音量", 16)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 1
	volume_slider.step = 0.05
	volume_slider.value = game.game_audio.volume
	volume_slider.custom_minimum_size = Vector2(500, 30)
	volume_slider.value_changed.connect(func(value: float): game.game_audio.volume = value; game.game_audio.apply_preferences())
	settings.add_child(volume_slider)
	fullscreen_check = _check(settings, "全屏显示", game.game_audio.fullscreen, _set_fullscreen)
	_action(settings, "保存当前进度 F6", func(): game.save_game())
	load_button = _action(settings, "读取最近存档 F9", func(): close(); game.request_load())
	new_button = _action(settings, "开始新的一局", func(): close(); game.request_new_game())
	_action(settings, "保存并退出游戏", _exit_game)
	_text(settings, "本地自动保存与备份；读档后暂停，无离线消耗。新游戏按钮会另外要求确认。", 14)
	_create_people_page()
	_create_story_page()
	_create_goals_page()
	tabs.tab_changed.connect(func(index: int):
		if index == 5: game.story.note("people")
		if index == 6: _refresh_story()
		if index == 7: _refresh_goals()
	)
	confirmed.connect(_restore_pause)
	canceled.connect(_restore_pause)


func _page(label: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = label
	tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]: margin.add_theme_constant_override(side, 20)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(column)
	return column


func _text(parent: Node, message: String, size: int) -> Label:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",maxi(17,size))
	label.add_theme_color_override("font_color",GameUi.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _action(parent: Node, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _check(parent: Node, label: String, state: bool, callback: Callable) -> CheckBox:
	var button := CheckBox.new()
	button.text = label
	button.button_pressed = state
	button.toggled.connect(callback)
	parent.add_child(button)
	return button


func open(page: int = 0) -> void:
	if game.has_method("siege_snapshot") and game.siege.active: return
	if visible: return
	_paused_before = game.paused
	game.paused = true
	refresh()
	tabs.current_tab = clampi(page, 0, tabs.get_tab_count() - 1)
	if page == 5: game.story.note("people")
	popup_centered()
	game._refresh_hud()


func close() -> void:
	hide()
	_restore_pause()


func _restore_pause() -> void:
	game.paused = _paused_before or game.game_over
	game._refresh_hud()


func refresh() -> void:
	for id in LocationCatalog.IDS:
		var world: ExpeditionState = game.regions[id]
		var remaining := 0
		for site in world.sites:
			for amount in site["contents"].values(): remaining += int(amount)
		var info := world.area()
		map_labels[id].text = "%s  /  风险%s  /  已知余量%d份\n%s" % [info["name"], info["risk"], remaining, info["summary"]]
		map_buttons[id].disabled = game.expedition.active or game.game_over or game.survivors[game.selected_id].health <= 0
	var progress: ShelterProgress = game.upkeep
	structure_label.text = "庇护所结构 %d%%  /  等级 %d / 3  /  生产效率 %d%%\n每天缓慢磨损，大风日更快；修整完成才恢复结构。" % [ceili(progress.integrity), progress.level, roundi(progress.efficiency() * 100)]
	upgrade_button.text = "升级已满：仍需维护与外出补给" if progress.level >= 3 else "升级到%d级：%s" % [progress.level + 1, ShelterInventory.describe(ShelterProgress.UPGRADE_COSTS[progress.level])]
	upgrade_button.disabled = game.expedition.active or game.game_over or progress.level >= 3 or not game.inventory.can_take(ShelterProgress.UPGRADE_COSTS[progress.level])
	repair_button.disabled = game.expedition.active or game.game_over or game.survivors[game.selected_id].health <= 0 or not game.scheduler.can_plan_materials(game.survivors[game.selected_id], "repair")
	if progress.pending_event >= 0:
		var id: int = progress.pending_event
		event_label.text = "第%d天 · %s\n%s\n接受：消耗%s；%s。%s" % [progress.event_day, ShelterProgress.EVENT_TITLES[id], ShelterProgress.EVENT_TEXTS[id], ShelterInventory.describe(ShelterProgress.EVENT_COSTS[id]), "结构+8" if id == 2 else "获得" + ShelterInventory.describe(ShelterProgress.EVENT_OUTPUTS[id]), "放弃：结构-8。" if id == 2 else "放弃不扣资源。"]
		accept_event.text = "接受并支付：" + ShelterInventory.describe(ShelterProgress.EVENT_COSTS[id])
		accept_event.disabled = game.expedition.active or game.game_over or not game.inventory.can_take(ShelterProgress.EVENT_COSTS[id])
	else:
		event_label.text = "暂时没有待处理事件。新一天会带来交换、天气准备或街区求助。"
	accept_event.visible = progress.pending_event >= 0
	decline_event.visible = progress.pending_event >= 0
	decline_event.disabled = game.expedition.active or game.game_over
	var lines: Array[String] = ["可选里程碑 · 达成后仍可继续生存\n"]
	for entry in progress.milestones(game): lines.append(("✓ " if entry[1] else "○ ") + entry[0] + "\n    " + entry[2])
	lines.append("\n据点记录\n" + "\n".join(progress.journal))
	records.text = "\n\n".join(lines)
	_refresh_people()
	_refresh_story()
	_refresh_goals()


func _prepare(id: String) -> void:
	if not game.choose_destination(id): return
	close()
	if game.has_method("campaign_snapshot"):
		game._log("今晚目的地已设为" + LocationCatalog.area(id)["name"] + "；结束白天后安排岗位与装备。")
	else: game.request_expedition()


func _repair() -> void:
	if game.expedition.active: return
	game.assign_task("repair")
	close()


func _upgrade() -> void:
	if game.expedition.active or game.game_over: return
	if not game.upkeep.upgrade(game.inventory): game._log("升级未执行：物资不足或等级已满。")
	refresh()
	game._refresh_hud()


func _event(accept: bool) -> void:
	if game.expedition.active or game.game_over: return
	if not game.upkeep.resolve_event(accept, game.inventory): game._log("事件未处理：缺少所需物资。")
	refresh()
	game._refresh_hud()


func _set_fullscreen(value: bool) -> void:
	game.game_audio.fullscreen = value
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
	game.game_audio.apply_preferences()
	fullscreen_check.set_pressed_no_signal(value)


func _exit_game() -> void:
	close()
	game.get_window().close_requested.emit()


func _create_people_page() -> void:
	var page := _page("人物 P")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	page.add_child(columns)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for column in [left, right]:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.custom_minimum_size.x = 440
		column.add_theme_constant_override("separation", 10)
		columns.add_child(column)
	roster_picker = OptionButton.new()
	left.add_child(roster_picker)
	roster_picker.item_selected.connect(func(index: int): game.select_survivor(index); refresh())
	person_text = _text(left, "", 15)
	if game.has_method("chronicle_snapshot"):
		_action(left,"人物志与专属计划 F3",func(): close();game.chronicle_view.show_page("people"))
	drink_button = _action(left, "给此人饮水 · 水1 / 水分+60", _drink)
	if game.has_method("plan_self_care"):
		routine_toggle = _check(left, "基本自理：吃饭、喝水、休息", true, func(value: bool): game.self_care.set_enabled(game,game.survivors[game.selected_id],value))
		routine_toggle.tooltip_text = "默认开启。空闲时饱腹或水分≤35、精神≤30，自行走到餐桌、水桶或空床。手动命令优先，取消后让出8秒；不擅自用药、工具或生食。关闭会中止本人自理。"
		cooking_toggle = _check(left,"缺饭时自行做饭（消耗燃料）",false,func(value: bool): game.survivors[game.selected_id].person.routine = value)
		cooking_toggle.tooltip_text = "独立开关，默认关闭。允许此人在需要吃饭却没有熟食时，实际走到灶台制作基础饭食，再去餐桌吃。已有饭菜在制作时会等待，不重复开锅。F4可另行授权为同伴备餐及医护照护。"
	else:
		routine_toggle = _check(left, "自动照料：饮水、吃饭、做饭、休息", false, func(value: bool): game.survivors[game.selected_id].person.routine = value)
		routine_toggle.tooltip_text = "饮水按需要即时使用；做饭、吃饭、睡觉只在空闲时排队。可能消耗食物、水、燃料；不自动花药品或工具。外出前授权的留守照料会继续。随时可关闭。"
	relationship_text = _text(left, "", 14)
	support_picker = OptionButton.new()
	left.add_child(support_picker)
	support_picker.item_selected.connect(func(_index: int): _refresh_support())
	var aid_row := HBoxContainer.new()
	aid_row.add_theme_constant_override("separation", 12)
	left.add_child(aid_row)
	support_button = _action(aid_row, "共餐 · 熟食1", _support)
	aid_button = _action(aid_row, "治疗所选同伴 · 药品1", _aid)
	for button in [support_button, aid_button]: button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	support_button.tooltip_text = "共餐安慰：心境+10、压力−20、信任+10；每人180秒冷却，不代替日常进食。"
	aid_button.tooltip_text = "由当前医护援助所选同伴：生命+20至26、伤势−40、感染−35、疾病−35。消耗药品1，每人180秒冷却。"
	_text(left, "心境低于25、压力达到80会降效，但不会随机拒绝命令或离队。照顾需求、休息、治疗与共餐都能帮助恢复。", 13)
	candidate_picker = OptionButton.new()
	right.add_child(candidate_picker)
	candidate_picker.item_selected.connect(func(_index: int): _refresh_candidate())
	candidate_text = _text(right, "", 15)
	recruit_button = _action(right, "接纳来访者", _recruit)
	storage_text = _text(right, "", 14)


func _refresh_people() -> void:
	if not is_instance_valid(roster_picker): return
	var actor: Survivor = game.survivors[game.selected_id]
	roster_picker.clear()
	for member: Survivor in game.survivors:
		roster_picker.add_item("%d  %s / %s%s" % [member.survivor_id + 1, member.display_name, member.speciality, " · 已故" if member.health <= 0 else ""])
	roster_picker.select(game.selected_id)
	roster_picker.disabled = game.expedition.active
	var person := actor.person
	var definition: Dictionary = PeopleCatalog.DATA[person.persona]
	person_text.text = "%s\n生命%d 饱腹%d 水分%d 精神%d（满分100）\n工艺 Lv%d（%d/180） · 照护 Lv%d（%d/180）\n探索 Lv%d（%d/180）\n%s" % [definition["bio"],Vitals.value(actor,"health"),Vitals.value(actor,"fullness"),Vitals.value(actor,"hydration"),Vitals.value(actor,"vigor"), person.level("craft"), roundi(person.experience["craft"]), person.level("care"), roundi(person.experience["care"]), person.level("scout"), roundi(person.experience["scout"]), (CharacterAbilities.description(person.persona) if actor.metabolism < 1 else definition["traits"]) + "\n" + definition["traits"]]
	drink_button.disabled = game.expedition.active or game.game_over or actor.health <= 0 or person.thirst <= 0 or game.inventory.amount("water") < 1
	routine_toggle.set_pressed_no_signal(game.self_care.enabled(actor) if game.has_method("plan_self_care") else person.routine)
	routine_toggle.disabled = game.expedition.active or game.game_over or actor.health <= 0
	if is_instance_valid(cooking_toggle):
		cooking_toggle.set_pressed_no_signal(person.routine)
		cooking_toggle.disabled = routine_toggle.disabled or not game.self_care.enabled(actor)
	var trust: Array[String] = []
	support_picker.clear()
	for other: Survivor in game.survivors:
		if other == actor: continue
		trust.append("%s%d" % [other.display_name, game.people.relationship(actor.survivor_id, other.survivor_id)])
		if other.health > 0:
			support_picker.add_item(other.display_name)
			support_picker.set_item_metadata(support_picker.item_count - 1, other.survivor_id)
	relationship_text.text = "与同伴的信任：" + " / ".join(trust)
	_refresh_support()
	candidate_picker.clear()
	for id in game.people.offers(game):
		candidate_picker.add_item(PeopleCatalog.DATA[id]["name"] + " / " + PeopleCatalog.role(id))
		candidate_picker.set_item_metadata(candidate_picker.item_count - 1, id)
	if candidate_picker.item_count == 0:
		candidate_picker.add_item("暂时没有新来访者")
		candidate_picker.set_item_metadata(0, "")
	candidate_picker.disabled = game.expedition.active or candidate_picker.get_item_metadata(0) == ""
	_refresh_candidate()
	var protected: Dictionary = game.people.protected_food(game)
	var loss_raw := ceili(maxi(0, game.inventory.amount("raw_food") - int(protected["raw_food"])) * 0.15)
	var loss_meals := ceili(maxi(0, game.inventory.amount("meals") - int(protected["meals"])) * 0.25)
	storage_text.text = "保鲜容量：生食%d / 熟食%d\n超额部分每清晨损耗15%% / 25%%，向上取整。\n按当前库存预计下次损耗：生食%d、熟食%d。\n升级提高容量，少量现做可减少浪费。\n成长每项最多3级，技能速度加成最多15%%；不能免除食物、药品和装备成本。" % [protected["raw_food"], protected["meals"], loss_raw, loss_meals]
	if not game.people.daily.is_empty():
		var latest: Dictionary = game.people.daily.back()
		storage_text.text += "\n最近记录：第%d天结束，在队%d人，平均饱腹%d、心境%d。" % [latest["day"], latest["alive"], roundi(100-latest["hunger"]), roundi(latest["morale"])]


func _refresh_support() -> void:
	var disabled: bool = game.expedition.active or game.game_over or support_picker.item_count == 0
	var actor: Survivor = game.survivors[game.selected_id]
	if not disabled:
		var target: Survivor = game.survivors[int(support_picker.get_item_metadata(support_picker.selected))]
		disabled = actor.health <= 0 or game.simulation_time - actor.person.last_support < 180 or game.simulation_time - target.person.last_support < 180 or game.inventory.amount("meals") < 1
	support_button.disabled = disabled
	var aid_disabled: bool = game.expedition.active or game.game_over or support_picker.item_count == 0 or actor.health <= 0 or actor.speciality != "医护" or game.inventory.amount("medicine") < 1
	if not aid_disabled:
		var patient: Survivor = game.survivors[int(support_picker.get_item_metadata(support_picker.selected))]
		aid_disabled = (patient.health >= 100 and patient.injury <= 0 and patient.infection <= 0 and patient.illness <= 0) or game.simulation_time - actor.person.last_aid < 180 or game.simulation_time - patient.person.last_aid < 180
	aid_button.disabled = aid_disabled
	aid_button.text = "%s → %s · 药品1" % [actor.display_name, game.survivors[int(support_picker.get_item_metadata(support_picker.selected))].display_name] if support_picker.item_count > 0 else "没有可治疗的同伴"
	aid_button.tooltip_text = "施治者：%s（需要医护）。接受治疗者：下拉框中的同伴。即时消耗药品1，生命+20至26、伤势−40、感染−35、疾病−35；双方180秒冷却。" % actor.display_name
	if game.has_method("campaign_snapshot"): aid_button.tooltip_text += "\n饱腹20以下时先吃饭：用药仍处理伤势、感染与疾病，但不恢复生命。"
	support_picker.tooltip_text = "选择接受共餐安慰或医疗援助的同伴。上方当前角色是行动发起者。"
	support_picker.disabled = game.expedition.active or support_picker.item_count == 0


func _support() -> void:
	if support_picker.item_count == 0: return
	if not game.people.support(game, int(support_picker.get_item_metadata(support_picker.selected))): game._log("共餐未执行：检查食物、同伴状态与冷却。")
	refresh()
	game._refresh_hud()


func _create_story_page() -> void:
	var page := _page("故事 / 引导 N")
	_text(page, "把日子过下去，也听听身边的人", 22)
	_text(page, "新手目标按实际行动记录，顺序不限；可随时隐藏提示。谈话不抢暂停、不限时、不自动花物资，每章只发生一次。", 14)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	page.add_child(columns)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for column in [left, right]:
		column.custom_minimum_size.x = 440
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 12)
		columns.add_child(column)
	guide_toggle = _check(left, "在游戏中显示下一步引导", true, func(value: bool): game.story.guide_hidden = not value; game._refresh_hud())
	guide_people_button = _action(left, "查看人物与照料授权 [P]", func(): tabs.current_tab = 5; game.story.note("people"); refresh())
	guide_text = _text(left, "", 15)
	story_text = _text(right, "", 16)
	story_paid = _action(right, "", _story_choice.bind(true))
	story_free = _action(right, "", _story_choice.bind(false))
	story_history = _text(right, "", 14)


func _refresh_story() -> void:
	if not is_instance_valid(guide_text): return
	guide_toggle.set_pressed_no_signal(not game.story.guide_hidden)
	var lines: Array[String] = []
	for index in range(StoryCatalog.GUIDE_IDS.size()):
		lines.append(("✓ " if game.story.guide.has(StoryCatalog.GUIDE_IDS[index]) else "○ ") + StoryCatalog.GUIDE_TITLES[index] + "\n" + StoryCatalog.GUIDE_HINTS[index])
	guide_text.text = "\n\n".join(lines)
	var pending: Dictionary = game.story.pending
	story_paid.visible = not pending.is_empty()
	story_free.visible = not pending.is_empty()
	if pending.is_empty():
		story_text.text = "暂时没有待处理谈话。\n和同伴一起生存、完成工作、接纳新人后，会逐渐遇见各自的故事。\n眼下可以先照顾需求、维护据点，再准备下一次外出。"
	else:
		var definition: Dictionary = StoryCatalog.DATA[pending["id"]]
		story_text.text = "第%d天 · %s\n%s 与 %s\n\n%s\n\n付费选择：双方心境+%d、压力%d、创伤−5、信任+%d。\n保留物资：双方心境+2、压力−3、创伤−1、信任+2。\n两种选择都不代替吃饭、饮水或睡眠。" % [pending["day"], definition["title"], game.survivors[int(pending["actor"])].display_name, game.survivors[int(pending["target"])].display_name, definition["text"], definition["morale"], definition["stress"], definition["trust"]]
		story_paid.text = definition["a"] + " · " + ShelterInventory.describe(definition["cost"])
		story_free.text = definition["b"] + " · 不耗物资"
		for button in [story_paid, story_free]:
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size.y = 60
		var paid_error: String = game.story.choice_error(game, true)
		story_paid.disabled = not paid_error.is_empty()
		story_paid.tooltip_text = paid_error
		story_free.disabled = not game.story.choice_error(game, false).is_empty()
		if not paid_error.is_empty(): story_text.text += "\n" + paid_error
	lines.clear()
	for entry in game.story.history:
		var definition: Dictionary = StoryCatalog.DATA[entry["id"]]
		var result: String = "谈话未能完成，同伴的记忆被留下。" if entry["outcome"] == "lost" else definition["result_a"] if entry["outcome"] == "a" else definition["result_b"]
		lines.push_front("第%d天 · %s\n%s" % [entry["day"], definition["title"], result])
	story_history.text = "已留下的故事\n" + ("\n\n".join(lines) if not lines.is_empty() else "还没有故事记录。")


func _story_choice(paid: bool) -> void:
	if not game.story.resolve(game, paid): game._log("谈话未执行：" + game.story.choice_error(game, paid))
	refresh()
	game._refresh_hud()


func _create_goals_page() -> void:
	var page := _page("目标 / 互助 O")
	_text(page, "留一个值得明天继续的目标", 22)
	_text(page, "三条路线都可自由选择，完成后继续生存。勘查要真正搜索并带回净补给；建设与互助使用现有库存，不自动扣料。", 14)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	page.add_child(columns)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for column in [left, right]:
		column.custom_minimum_size.x = 440
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 12)
		columns.add_child(column)
	goal_picker = OptionButton.new()
	left.add_child(goal_picker)
	for id in GoalCatalog.IDS: goal_picker.add_item(GoalCatalog.NAMES[id])
	goal_picker.item_selected.connect(func(index: int): game.goals.tracked = GoalCatalog.IDS[index]; _refresh_goals(); game._refresh_hud())
	goal_button = _action(left, "完成当前阶段", _advance_goal)
	goal_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_button.custom_minimum_size.y = 62
	goal_text = _text(left, "", 16)
	_text(right, "邻里互助 · 所有交换共用两日间隔", 18)
	trade_text = _text(right, "", 14)
	for id in GoalCatalog.TRADE_IDS:
		var definition: Dictionary = GoalCatalog.TRADES[id]
		var button := _action(right, definition["title"] + "\n" + ShelterInventory.describe(definition["cost"]) + " → " + ShelterInventory.describe(definition["output"]), _trade.bind(id))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 62
		trade_buttons[id] = button
	_text(right, "互助不是自产。保留治疗、修缮和日常生产所需的应急物资；没有库存不会赊账，也不能反复点按钮领取补给。", 14)


func _refresh_goals() -> void:
	if not is_instance_valid(goal_picker): return
	goal_picker.select(GoalCatalog.IDS.find(game.goals.tracked))
	var id: String = game.goals.tracked
	var current: int = game.goals.stages[id]
	var lines: Array[String] = [GoalCatalog.NAMES[id] + " · %d/3" % current]
	for index in range(3):
		var step: Dictionary = GoalCatalog.STAGES[id][index]
		lines.append(("✓ " if index < current else "○ ") + step["title"] + "\n" + step["hint"] + "\n费用：" + ShelterInventory.describe(step["cost"]))
	var error: String = game.goals.progress_error(game, id)
	goal_text.text = "\n\n".join(lines) + "\n\n" + ("当前阶段可以完成。" if error.is_empty() else error)
	goal_button.disabled = not error.is_empty()
	goal_button.text = "路线已完成 · 继续生存" if current >= 3 else "确认完成：" + GoalCatalog.STAGES[id][current]["title"] + "\n费用：" + ShelterInventory.describe(GoalCatalog.STAGES[id][current]["cost"])
	var day := ExpeditionState.day_at(game.simulation_time)
	trade_text.text = "至少1级据点、第4天起开放；接应后再等两个日历日。\n当前第%d天，下一次接应不早于第%d天。\n已用于目标与互助：材料%d、药品%d。" % [day, game.goals.next_trade_day, game.goals.spent["materials"], game.goals.spent["medicine"]]
	for key in trade_buttons:
		var quote: Dictionary = GoalCatalog.TRADES[key]
		trade_buttons[key].text = quote["title"] + "\n" + ShelterInventory.describe(quote["cost"]) + " → " + ShelterInventory.describe(game.goals.trade_output(game,key))
		var reason: String = game.goals.trade_error(game, key)
		trade_buttons[key].disabled = not reason.is_empty()
		trade_buttons[key].tooltip_text = reason if not reason.is_empty() else "确认支付完整费用并接回物资；所有互助共用两日间隔。"


func _advance_goal() -> void:
	if not game.goals.advance(game, game.goals.tracked): game._log("目标未执行：" + game.goals.progress_error(game, game.goals.tracked))
	refresh()
	game._refresh_hud()


func _trade(id: String) -> void:
	if not game.goals.trade(game, id): game._log("互助未执行：" + game.goals.trade_error(game, id))
	refresh()
	game._refresh_hud()


func _refresh_candidate() -> void:
	var id: String = candidate_picker.get_item_metadata(candidate_picker.selected)
	var living: int = game.survivors.filter(func(a): return a.health > 0).size()
	if id.is_empty():
		candidate_text.text = "角色池共12人，来访者从第3天至第18天分批出现。每人仅能加入一次，不会替已故成员复活。\n目前在队%d/%d；至少一级据点才可接纳。" % [living, PeopleCatalog.MAX_LIVING]
	else:
		var info: Dictionary = PeopleCatalog.DATA[id]
		candidate_text.text = "%s\n%s\n接纳准备：%s\n到达时饱腹40、精神45，需要继续照料。\n目前在队%d/%d；需要一级据点。" % [info["bio"], info["traits"], ShelterInventory.describe(PeopleCatalog.RECRUIT_COST), living, PeopleCatalog.MAX_LIVING]
	recruit_button.disabled = id.is_empty() or game.expedition.active or game.game_over or living >= PeopleCatalog.MAX_LIVING or game.upkeep.level < 1 or not game.inventory.can_take(PeopleCatalog.RECRUIT_COST)


func _recruit() -> void:
	var id: String = candidate_picker.get_item_metadata(candidate_picker.selected)
	if not game.people.recruit(game, id): game._log("接纳未执行：检查据点、人数、物资与来访时间。")
	refresh()
	game._refresh_hud()


func _drink() -> void:
	if game.has_method("begin_drink"):
		close()
		game.begin_drink()
		return
	if not game.people.drink(game, game.selected_id): game._log("饮水未执行：检查成员状态、物资或外出控制。")
	refresh()
	game._refresh_hud()


func _aid() -> void:
	if support_picker.item_count == 0: return
	if not game.people.aid(game, int(support_picker.get_item_metadata(support_picker.selected))): game._log("医疗援助未执行：需要医护、药品、受伤同伴并等待冷却。")
	refresh()
	game._refresh_hud()
