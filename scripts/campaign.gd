extends "res://scripts/shelter.gd"
## The playable campaign. Shelter remains the shared simulation fixture;
## this scene owns day/night transitions and direct scene interaction.

var _updating_frame := false
var shelter_keyboard := ShelterKeyboard.new()
var compact: CompactHud
var scene_art := SceneArt.new()
var cycle := CampaignCycle.new()
var expansion := SurvivalExpansion.new()
var residence := ResidenceSystem.new()
var residence_view: ResidenceInterface
var interface: CampaignInterface
var end_day_dialog: ConfirmationDialog
var departure_dialog: ConfirmationDialog
var _departure_side := 0
var _departure_pause_before := false
var _edge_latched := 0
var batch_count: SpinBox
var placement := ""
var _settling := false
var _loot_pause_before := false
var _loot_open := false
var _extra_props: Array[Node2D] = []
var _props_signature := ""


func world_scale() -> Vector2:
	return Vector2(1.4,1.4)


func world_offset() -> Vector2:
	return Vector2(-30,-160)


func _draw() -> void:
	if not expedition.active:
		scene_art.shelter(self)
		_draw_day_intent()


func _compact_card(index: int) -> Button:
	var card := SurvivorCard.new()
	card.game = self
	card.member_id = index
	card.pressed.connect(select_survivor.bind(index))
	hud.add_child(card)
	return card


func _region_ids() -> Array:
	for id in LocationCatalog.ALL_IDS:
		if not upkeep.returns.has(id): upkeep.returns[id] = 0
	return LocationCatalog.ALL_IDS


func _ready() -> void:
	expansion.grant("knife", "chen")
	super._ready()
	scheduler.external_busy = _external_busy
	scheduler.station_reserved = func(id: String): return id == "workbench" and expansion.jobs.any(func(job): return job["kind"] != "music" and survivors[int(job["actor"])].route.is_empty() and survivors[int(job["actor"])].position.distance_to(Vector2(485, 640)) <= 10)
	expansion.sync(self)
	get_window().title = "Live Forever · 留一盏灯 v1.3.3"
	for actor in survivors: actor.metabolism = 0.4
	for field: ExpeditionState in regions.values():
		field.manual_loot = true
		field.confirm_exits = true
		field.exit_requested.connect(_offer_departure)
	# Replace the legacy instant water command with a physical action.
	for connection in water_store.clicked.get_connections(): water_store.clicked.disconnect(connection["callable"])
	water_store.clicked.connect(begin_drink)
	end_day_dialog = _confirmation("结束白天", "结束白天并安排夜间岗位？\n未完成工作与建设取消并退料；剩余白天只结算需求，不会免费完成生产。")
	end_day_dialog.confirmed.connect(end_day)
	departure_dialog = _confirmation("离开此地？", "")
	departure_dialog.canceled.disconnect(_cancel_dialog)
	departure_dialog.canceled.connect(cancel_departure)
	departure_dialog.confirmed.connect(confirm_departure)
	departure_dialog.ok_button_text = "带上物资离开"
	departure_dialog.cancel_button_text = "继续探索"
	interface = CampaignInterface.new()
	interface.game = self
	add_child(interface)
	for child in hud.get_children():
		if child is Button and "出门搜刮" in child.text:
			child.text = "结束白天 → 夜晚"
			child.position = Vector2(1212, 202)
			child.size = Vector2(200, 38)
			child.tooltip_text = "结束白天，安排搜刮、守夜和睡眠。"
	for node in context_nodes:
		if node is Panel: node.size.y = 540
	assign_button.position.y = 589
	cancel_button.position.y = 642
	status_label.position.y = 685
	queue_label.position.y = 716
	progress_bar.hide()
	var label := _label("生产批数", Vector2(1075, 548), Vector2(130, 30), 14, GOLD)
	context_nodes.append(label)
	base_hud_nodes.append(label)
	batch_count = SpinBox.new()
	batch_count.position = Vector2(1270, 546)
	batch_count.size = Vector2(120, 32)
	batch_count.min_value = 1
	batch_count.max_value = 3
	batch_count.value = 1
	batch_count.focus_mode = Control.FOCUS_NONE
	hud.add_child(batch_count)
	context_nodes.append(batch_count)
	base_hud_nodes.append(batch_count)
	compact = CompactHud.new()
	compact.game = self
	add_child(compact)
	residence_view = ResidenceInterface.new()
	residence_view.game = self
	add_child(residence_view)
	scheduler.task_finished.connect(func(_id: int, task: String):
		if task in ["craft", "repair", "cook"]: residence.noise = minf(100, residence.noise + (4 if task == "craft" else 2))
	)
	_configure_manual()
	_log("左键走动，双击奔跑；点床与餐桌直接休息或进食，B选择建设。20:00安排夜间岗位。")
	_refresh_hud()


func residence_snapshot() -> Dictionary:
	return residence.snapshot()


func restore_residence(data: Dictionary) -> void:
	residence.restore(data, self)
	expansion.sync(self)
	var loaded_pause := paused
	if is_instance_valid(residence_view): residence_view.close()
	paused = loaded_pause


func expansion_snapshot() -> Dictionary:
	return expansion.snapshot()


func restore_expansion(data: Dictionary) -> void:
	expansion.restore(data, self)
	for id in LocationCatalog.ALL_IDS:
		if not upkeep.returns.has(id): upkeep.returns[id] = 0
	if is_instance_valid(interface): interface.refresh(true)


func choose_destination(id: String) -> bool:
	if not expansion.unlocked(self, id):
		_log(expansion.lock_reason(id))
		return false
	return super.choose_destination(id)


func campaign_snapshot() -> Dictionary:
	return cycle.snapshot()


func restore_campaign(data: Dictionary) -> void:
	shelter_keyboard.reset(self)
	_departure_side = 0
	_edge_latched = 0
	if is_instance_valid(departure_dialog): departure_dialog.hide()
	if is_instance_valid(expedition_view.equipment_dialog):
		expedition_view.equipment_dialog.hide()
		expedition_view._equipment_opened = false
	if data.is_empty():
		cycle = CampaignCycle.new()
		if expedition.active:
			cycle.phase = "scavenge"
			cycle.night_day = maxi(1, ExpeditionState.day_at(simulation_time) - (1 if CampaignCycle.minute(simulation_time) < 360 else 0))
			cycle.night_start = simulation_time
			cycle.night_end = CampaignCycle.next_dawn(simulation_time)
			cycle.roles.resize(survivors.size())
			cycle.roles.fill("floor")
			cycle.roles[expedition.actor_id] = "scavenge"
			for actor in survivors:
				if actor.health <= 0: cycle.roles[actor.survivor_id] = "dead"
			cycle.loadout = upkeep.trip_loadout.duplicate()
		elif CampaignCycle.minute(simulation_time) >= 1200 or CampaignCycle.minute(simulation_time) < 360:
			enter_night_planning()
	else:
		cycle.restore(data)
	for actor in survivors:
		actor.metabolism = 0.4
		actor.activity.clear()
		actor.move_multiplier = 1
	for field: ExpeditionState in regions.values():
		field.manual_loot = true
		field.confirm_exits = true
	_props_signature = ""
	context_open = false
	placement = ""
	_loot_open = expedition.loot_site >= 0
	expedition_view.search_held = false
	if is_instance_valid(interface):
		interface.has_move_target = false
		interface.build_open = false
		if is_instance_valid(interface.build_panel): interface.build_panel.hide()
		interface.refresh(true)


func add_survivor(persona: String) -> Survivor:
	var actor := super.add_survivor(persona)
	actor.metabolism = 0.4
	return actor


func advance_simulation(delta: float) -> void:
	if paused or game_over or delta <= 0 or cycle.phase in ["planning", "dawn"]: return
	var remaining := delta * speed
	while remaining > 0.0000001 and not paused and not game_over:
		var step := minf(remaining, 1.0 / 60.0)
		if cycle.phase == "day":
			var until_sunset := (1200.0 - CampaignCycle.minute(simulation_time)) / 2.0
			if until_sunset <= 0.00001:
				enter_night_planning()
				break
			step = minf(step, until_sunset)
			_day_step(step)
			if CampaignCycle.minute(simulation_time) >= 1200.0 - 0.00001:
				enter_night_planning()
		elif cycle.phase in ["scavenge", "returning"]:
			simulation_time += step
			var actor := survivors[expedition.actor_id]
			expansion.climate(actor, step, expansion.outside(self) - (3 if expedition.location_id == "broadcast" else 0))
			# Night personality pressure is settled here; do not run full People.tick twice.
			if expedition.elapsed > 120:
				actor.person.stress = minf(100, actor.person.stress + step * (0.01 if actor.person.persona == "chen" else 0.005))
			expedition.tick(step, actor, _expedition_controls())
			if expedition.active: expansion.refresh_slots(expedition, actor)
			_check_departure_edge()
			if cycle.phase == "scavenge" and simulation_time >= cycle.night_end:
				cycle.phase = "returning"
				cycle.return_requested = false
				_loot_open = false
				expedition.loot_site = -1
				expedition_view.search_held = false
				if is_instance_valid(interface):
					interface.has_move_target = false
					interface.refresh(true)
				cycle.late_warned = true
				actor.fatigue = minf(100, actor.fatigue + 15)
				actor.person.stress = minf(100, actor.person.stress + 10)
				_log("天亮了！已开始沿实际路线撤回，搜刮停止。迟归增加疲劳与压力，物资仍需到入口才入库。")
			if cycle.phase == "scavenge" and not cycle.late_warned and cycle.night_end - simulation_time < 30:
				cycle.late_warned = true
				_log("距天亮不足一小时，尽快回到入口。天亮后会强制沿路撤离。")
		remaining -= step
		if survivors.all(func(actor): return actor.health <= 0):
			game_over = true
			paused = true
			_log("所有幸存者已死亡。可以读取存档或新开一局。")
	if persistence_enabled and auto_save_allowed and simulation_time - _last_auto_attempt >= 60:
		save_game(true)


func _day_step(step: float) -> void:
	if _day_keyboard_allowed(): shelter_keyboard.step(self,step,super._expedition_controls())
	else: shelter_keyboard.stop(self)
	var policies := {}
	for actor in survivors:
		if _external_busy(actor.survivor_id):
			policies[actor.survivor_id] = actor.person.routine
			actor.person.routine = false
	_advance_world_step(step)
	shelter_keyboard.finish_step(self)
	for id in policies: survivors[int(id)].person.routine = policies[id]
	_tick_external(step)
	expansion.tick_day(self, step)
	residence.noise = maxf(0, residence.noise - step * 0.006)
	for actor in survivors:
		if actor.route.is_empty(): actor.move_multiplier = 1


func request_expedition() -> void:
	if game_over: return
	if cycle.phase == "planning":
		interface.refresh(true)
		return
	if cycle.phase != "day": return
	_dialog_pause_before = paused
	paused = true
	end_day_dialog.popup_centered()


func end_day() -> void:
	if cycle.phase != "day" or game_over: return
	_cancel_all_day_work()
	var policies: Array[bool] = []
	for actor in survivors:
		policies.append(actor.person.routine)
		actor.person.routine = false
	var left := maxf(0, (1200 - CampaignCycle.minute(simulation_time)) / 2.0)
	while left > 0.00001 and not game_over:
		var step := minf(left, 0.5)
		_advance_world_step(step)
		expansion.tick_day(self, step)
		residence.noise = maxf(0, residence.noise - step * 0.006)
		left -= step
		if survivors.all(func(actor): return actor.health <= 0): game_over = true
	for index in range(survivors.size()): survivors[index].person.routine = policies[index] and survivors[index].health > 0
	if not game_over: enter_night_planning()
	_refresh_hud()


func enter_night_planning() -> void:
	if cycle.phase != "day": return
	_cancel_all_day_work()
	cycle.phase = "planning"
	cycle.return_requested = false
	cycle.night_day = maxi(1, ExpeditionState.day_at(simulation_time) - (1 if CampaignCycle.minute(simulation_time) < 360 else 0))
	cycle.night_start = simulation_time
	cycle.night_end = CampaignCycle.next_dawn(simulation_time)
	cycle.loadout.clear()
	cycle.roles.clear()
	cycle.late_warned = false
	var scout := -1
	var best := -1.0
	for actor in survivors:
		cycle.roles.append("floor" if actor.health > 0 else "dead")
		if actor.health <= 0: continue
		var score: float = actor.health - actor.fatigue * 0.6 + (35 if actor.speciality == "搜寻者" else 0)
		if score > best:
			best = score
			scout = actor.survivor_id
	if scout >= 0: cycle.roles[scout] = "scavenge"
	var bed_left := cycle.bed_count()
	var guarded := false
	for actor in survivors:
		if actor.health <= 0 or actor.survivor_id == scout: continue
		if not guarded and actor.fatigue < 65:
			cycle.roles[actor.survivor_id] = "guard"
			guarded = true
		elif bed_left > 0:
			cycle.roles[actor.survivor_id] = "bed"
			bed_left -= 1
	if not residence.convoy.is_empty():
		cycle.roles.clear()
		for actor in survivors: cycle.roles.append("guard" if actor.health > 0 else "dead")
		expansion.ammo_loadout = 0
	paused = true
	context_open = false
	placement = ""
	_log("白天结束。选择一名搜刮者，安排守夜与睡眠，再决定带什么出门。也可以全员留守。")
	if is_instance_valid(interface): interface.refresh(true)


func start_expedition(take_tool: bool = false, take_medicine: bool = false) -> bool:
	_edge_latched = 0
	# Called by the night screen; boolean parameters remain for core API compatibility.
	if cycle.phase != "planning" or not cycle.plan_error(self).is_empty() or game_over: return false
	var id := cycle.scavenger()
	if id < 0:
		expansion.reserve_heat(self)
		_settle_night([])
		return true
	var equipment := cycle.loadout.duplicate()
	if not inventory.try_take(equipment, "夜间出发携带物资"): return false
	expansion.reserve_heat(self)
	select_survivor(id)
	expedition.refresh_for_day(cycle.night_day)
	scheduler.cancel(survivors[id])
	survivors[id].route.clear()
	survivors[id].state = Survivor.TaskState.AWAY
	survivors[id].feedback = "夜间搜刮中"
	upkeep.begin_trip(equipment)
	expedition.capacity = cycle.capacity(self)
	expedition.manual_loot = true
	expedition.begin(id, equipment, 1.0)
	expedition.reserve_ammo = expansion.ammo_loadout
	expansion.ammo -= expansion.ammo_loadout
	expedition.magazine = mini(6, expedition.reserve_ammo) if survivors[id].weapon().has("magazine") else 0
	expedition.reserve_ammo -= expedition.magazine
	expedition.reload_remaining = 0
	expansion.refresh_slots(expedition, survivors[id])
	cycle.phase = "scavenge"
	context_open = false
	speed = 1
	paused = false
	_log("%s夜间前往%s。只能往返一次；天亮前返回入口。" % [survivors[id].display_name, expedition.area()["name"]])
	interface.refresh(true)
	_refresh_hud()
	return true


func expedition_retreat() -> void:
	if is_instance_valid(departure_dialog) and departure_dialog.visible: return
	if not expedition.active or game_over or center.visible or load_dialog.visible or new_dialog.visible or exit_dialog.visible: return
	if cycle.phase == "returning": return
	close_loot()
	expedition_view.search_held = false
	expedition_view.bag_open = false
	interface.has_move_target = false
	interface.target_enemy = -1
	if expedition.exit_side() != 0:
		expedition.request_retreat()
	else:
		cycle.return_requested = not cycle.return_requested
	expedition_view.refresh()
	_refresh_hud()


func _check_departure_edge() -> void:
	if not expedition.active or cycle.phase != "scavenge": return
	var side := 0
	if expedition.floor_level == 0 and expedition.climb_target == -1:
		if expedition.player_x <= 90.5: side = -1
		elif expedition.player_x >= expedition.right_edge(0) - 0.5: side = 1
	if side == 0:
		if expedition.player_x > 105 and expedition.player_x < expedition.right_edge(0) - 15: _edge_latched = 0
		return
	if side != _edge_latched and expedition.moving and expedition.facing == side:
		_edge_latched = side
		_offer_departure(side)


func _offer_departure(side: int) -> void:
	if cycle.phase == "scavenge" and simulation_time >= cycle.night_end: return
	if cycle.phase == "returning":
		expedition.confirm_retreat(side) # Mandatory dawn evacuation keeps moving.
		return
	if not is_instance_valid(departure_dialog) or departure_dialog.visible or expedition.exit_side() != side: return
	_departure_side = side
	_departure_pause_before = paused
	cycle.return_requested = false
	close_loot()
	expedition_view.search_held = false
	interface.has_move_target = false
	interface.target_enemy = -1
	paused = true
	departure_dialog.dialog_text = "从%s出口返回避难所？\n随身物资会带回，今晚无法再次外出。" % ("左侧" if side < 0 else "右侧")
	departure_dialog.popup_centered()
	_refresh_hud()


func cancel_departure() -> void:
	if _departure_side == 0: return
	get_viewport().set_input_as_handled()
	_departure_side = 0
	departure_dialog.hide()
	paused = _departure_pause_before or game_over
	_refresh_hud()


func confirm_departure() -> void:
	if _departure_side == 0: return
	get_viewport().set_input_as_handled()
	var side := _departure_side
	_departure_side = 0
	departure_dialog.hide()
	paused = _departure_pause_before or game_over
	if not expedition.confirm_retreat(side): _refresh_hud()


func _on_expedition_returned(id: int, cargo: Dictionary, survived: bool) -> void:
	_departure_side = 0
	_edge_latched = 0
	if is_instance_valid(departure_dialog): departure_dialog.hide()
	var net := {}
	for key in cargo:
		var quantity := maxi(0, int(cargo[key]) - int(upkeep.trip_loadout.get(key, 0)))
		if quantity > 0: net[key] = quantity
	residence.trip_return(self, survived and survivors[id].health > 0)
	expansion.trip_return(self, id, survived and survivors[id].health > 0)
	super._on_expedition_returned(id, cargo, survived)
	_settle_night(["%s已归来；净带回%s。" % [survivors[id].display_name, ShelterInventory.describe(net)] if survived else "%s未能归来；随身物资、零件和装备全部丢失。" % survivors[id].display_name])


func _settle_night(lines: Array) -> void:
	if _settling or cycle.last_resolved_day >= cycle.night_day: return
	_settling = true
	var minutes := maxf(0, cycle.night_end - cycle.night_start)
	var report: Array[String] = []
	for line: String in lines: report.append(line)
	for actor in survivors:
		if actor.health <= 0: continue
		var before := actor.fatigue
		actor.hunger = minf(100, actor.hunger + minutes * 0.04 * (1.1 if actor.person.persona == "he" else 1.0))
		actor.person.thirst = minf(100, actor.person.thirst + minutes * 0.018)
		var role := cycle.roles[actor.survivor_id]
		if not residence.convoy.is_empty(): role = "guard"
		match role:
			"bed": actor.fatigue = maxf(0, actor.fatigue - 65 * CharacterAbilities.factor(actor,"sleep")); actor.person.stress = maxf(0, actor.person.stress - 12)
			"floor": actor.fatigue = maxf(0, actor.fatigue - 35 * CharacterAbilities.factor(actor,"sleep")); actor.person.stress = maxf(0, actor.person.stress - 4)
			"guard": actor.fatigue = minf(100, actor.fatigue + 28)
			"scavenge": actor.fatigue = minf(100, actor.fatigue + 35)
		actor.infection = minf(100, actor.infection + (minutes * 0.006 if actor.infection > 0 else 0))
		if actor.hunger >= 95: actor.health = maxf(0, actor.health - 8)
		if actor.person.thirst >= 95: actor.health = maxf(0, actor.health - 6)
		if actor.infection >= 60: actor.health = maxf(0, actor.health - 6)
		if role == "bed" and actor.hunger < 60 and actor.infection < 20:
			actor.health = minf(100, actor.health + 6 * CharacterAbilities.factor(actor,"recovery"))
			actor.injury = maxf(0, actor.injury - 8 * CharacterAbilities.factor(actor,"recovery"))
		report.append("%s · %s：精神%d → %d，饱腹%d，水分%d。" % [actor.display_name, "迁居行军" if not residence.convoy.is_empty() else CampaignCycle.ROLE_NAMES[CampaignCycle.ROLES.find(role)], roundi(100-before), Vitals.value(actor,"vigor"), Vitals.value(actor,"fullness"), Vitals.value(actor,"hydration")])
	_resolve_raid(report)
	simulation_time = maxf(simulation_time, cycle.night_end)
	upkeep.tick(minutes, simulation_time)
	expansion.dawn(self, minutes, report)
	residence.finish_move(self, report)
	residence.noise *= 0.4
	# Morning boundaries are processed once; disable routine orders in the report.
	var policies: Array[bool] = []
	for actor in survivors:
		policies.append(actor.person.routine)
		actor.person.routine = false
	people.tick(self, 0)
	for index in range(survivors.size()):
		var actor := survivors[index]
		actor.person.routine = policies[index] and actor.health > 0
		if actor.health <= 0: scheduler.mark_dead(actor, "夜间伤病或袭击")
	if cycle.has_build("filter") and ExpeditionState.day_at(simulation_time) % 4 == 2:
		inventory.deposit({"water": 2}, "细雨天气的雨水收集器")
		report.append("雨水收集器收获水2；晴天不会产水。")
	cycle.last_resolved_day = cycle.night_day
	cycle.report = report
	cycle.phase = "dawn"
	cycle.return_requested = false
	_loot_open = false
	expedition_view.search_held = false
	if is_instance_valid(interface): interface.has_move_target = false
	placement = ""
	context_open = false
	paused = true
	game_over = survivors.all(func(actor): return actor.health <= 0)
	_settling = false
	if is_instance_valid(interface): interface.refresh(true)
	_refresh_hud()
	if persistence_enabled: save_game(true)


func _resolve_raid(report: Array[String]) -> void:
	if not residence.convoy.is_empty():
		_resolve_convoy(report)
		return
	var roll: int = (cycle.seed + cycle.night_day * 7919) % 100
	if cycle.night_day < 3 or roll >= residence.attack_chance(55 if cycle.night_day < 8 else 70):
		report.append("这一夜没有尸群袭击。")
		return
	var defense := (0.9 if cycle.has_build("barricade") else 0.0) + residence.defense()
	for actor in survivors:
		if actor.health > 0 and cycle.roles[actor.survivor_id] == "guard": defense += actor.health / 100.0 * maxf(0.2, 1 - (actor.fatigue - 28) / 160.0) * 1.2 * residence.guard_multiplier() * CharacterAbilities.factor(actor,"melee") * (1.15 if not actor.weapon().is_empty() else 1.0)
	var threat := minf(2.0, 1.0 + cycle.night_day * 0.035)
	residence.wear(threat)
	if defense >= threat:
		report.append("守夜与隔断挡住了尸群袭击，没有丢失物资。")
		return
	var stolen := {}
	for key in ["raw_food", "water", "materials"]:
		var count := mini(inventory.amount(key), 1 if defense >= 0.8 else 2)
		if count > 0: stolen[key] = count
	inventory.try_take(stolen, "夜间防守不足，尸群闯入造成损坏")
	report.append("尸群袭击突破防守，损失%s。" % ShelterInventory.describe(stolen))
	for actor in survivors:
		if actor.health > 0 and cycle.roles[actor.survivor_id] in ["bed", "floor", "guard"]:
			actor.health = maxf(0, actor.health - (4 if defense >= 0.8 else 9) * (1 - actor.protection()) * (1 - residence.security["mesh"] * 0.1 * residence.condition / 100))
			actor.injury = minf(100, actor.injury + 8 * (1 - actor.protection()))
			if not actor.armor_item.is_empty(): actor.armor_item["durability"] = maxi(0, int(actor.armor_item["durability"]) - 4)
			actor.person.stress = minf(100, actor.person.stress + 8)
			report.append("%s在袭击中受伤；请在白天处理。" % actor.display_name)
			break


func _resolve_convoy(report: Array[String]) -> void:
	var escort := 0.0
	for actor in survivors:
		if actor.health > 0: escort += actor.health / 100 * (0.7 if actor.weapon().is_empty() else 1.2) * CharacterAbilities.factor(actor,"melee")
	var danger := 1.5 + minf(1, cycle.night_day * 0.025)
	if escort >= danger:
		report.append("搬家队伍沿勘察路线穿过尸群，装备与互相掩护避免了人员受伤。")
	else:
		for actor in survivors:
			if actor.health <= 0: continue
			actor.health = maxf(0, actor.health - 12 * (1-actor.protection()))
			actor.injury = minf(100,actor.injury+10)
			if not actor.armor_item.is_empty(): actor.armor_item["durability"] = maxi(0,int(actor.armor_item["durability"])-4)
		report.append("迁居途中遭遇尸群，护送力量不足，成员受伤；库存仍随运输队抵达。")


func begin_day() -> void:
	if cycle.phase != "dawn" or game_over or (not expansion.outcome.is_empty() and not expansion.endless): return
	cycle.phase = "day"
	cycle.roles.clear()
	cycle.loadout.clear()
	cycle.night_start = 0
	cycle.night_end = 0
	paused = false
	story.tick(self)
	_log("第%d天开始。先照料归来者，再决定今天的生产与建设。" % ExpeditionState.day_at(simulation_time))
	_refresh_hud()
	interface.refresh(true)
	if persistence_enabled: save_game(true)


func _expedition_controls() -> Dictionary:
	if _loot_open: return {}
	if cycle.phase == "returning":
		var forced := _route_controls(110,0,true)
		forced["force_exit"] = true
		return forced
	var manual := super._expedition_controls()
	# Direct movement takes priority before any pending mouse attack or search.
	if absf(float(manual.get("axis",0))) > 0 or int(manual.get("climb",0)) != 0:
		cycle.return_requested = false
		interface.has_move_target = false
		interface.target_enemy = -1
		interface.target_site = -1
		expedition_view.search_held = false
		return manual
	if cycle.return_requested:
		return _route_controls(110,0,false) if expedition.floor_level != 0 or expedition.player_x > 119 else {"interact":true}
	if is_instance_valid(interface) and interface.has_move_target:
		if interface.target_enemy >= 0:
			var enemy: Dictionary = expedition.enemies[interface.target_enemy]
			if enemy["hp"] <= 0:
				interface.has_move_target = false
				interface.target_enemy = -1
				return manual
			var distance := float(enemy["x"])-expedition.player_x
			if int(enemy["floor"]) == expedition.floor_level and absf(distance) < float(survivors[expedition.actor_id].weapon().get("reach",75))-7 and expedition.climb_target == -1:
				expedition.facing = signf(distance) if absf(distance) > 1 else expedition.facing
				if expedition.attack_cooldown <= 0:
					expedition_attack()
					interface.has_move_target = false
					interface.target_enemy = -1
				return {}
			interface.target_x = float(enemy["x"])-signf(distance)*(float(survivors[expedition.actor_id].weapon().get("reach",75))-20)
			interface.target_floor = int(enemy["floor"])
		var controls := _route_controls(interface.target_x,interface.target_floor,false)
		controls["sneak"] = Input.is_physical_key_pressed(KEY_CTRL)
		controls["sprint"] = interface.target_run and not controls["sneak"]
		var arrival := 0.5 if interface.target_floor == 0 and (interface.target_x <= 90 or interface.target_x >= expedition.right_edge(0)) else 10.0
		if absf(expedition.player_x-interface.target_x) < arrival and expedition.floor_level == interface.target_floor and expedition.climb_target == -1:
			interface.has_move_target = false
			if interface.target_site >= 0: expedition_view.search_held = true
		return controls
	return manual


func _day_keyboard_allowed() -> bool:
	if paused or game_over or center.visible or interface.workshop_open or residence_view.opened: return false
	if load_dialog.visible or new_dialog.visible or exit_dialog.visible or prep_dialog.visible or end_day_dialog.visible: return false
	var focus := get_viewport().gui_get_focus_owner()
	return not focus is LineEdit and not focus is TextEdit


func _route_controls(x: float, floor_level: int, retreat: bool) -> Dictionary:
	if expedition.climb_target != -1: return {}
	if expedition.floor_level != floor_level:
		if absf(expedition.player_x - expedition.ladder_x()) > 8: return {"axis": signf(expedition.ladder_x() - expedition.player_x), "sprint": retreat}
		return {"climb": 1 if floor_level == 1 else -1}
	var tolerance := 0.25 if floor_level == 0 and (x <= 90 or x >= expedition.right_edge(0)) else 9.0
	if absf(expedition.player_x - x) > tolerance: return {"axis": signf(x - expedition.player_x), "sprint": retreat}
	return {"interact": true} if retreat else {}


func _process(delta: float) -> void:
	_updating_frame = true
	super._process(delta)
	_updating_frame = false
	if is_instance_valid(interface):
		if expedition.active and expedition.loot_site >= 0 and not _loot_open:
			_loot_pause_before = paused
			_loot_open = true
			expedition_view.search_held = false
		interface.refresh()
	if is_instance_valid(compact): compact.refresh()
	game_audio.sync_music(not paused and cycle.phase == "day" and survivors.any(func(actor): return actor.activity.get("kind", "") == "music"))


func close_loot() -> void:
	if not _loot_open: return
	expedition.loot_site = -1
	_loot_open = false
	interface.refresh(true)


func _refresh_hud() -> void:
	if not is_instance_valid(compact) or context_open:
		super._refresh_hud()
	else:
		# Closed legacy drawers do not need strings, font shaping or new styles.
		_sync_mode()
		pause_button.disabled = game_over
		speed_button.disabled = expedition.active
		game_over_label.visible = game_over and not expedition.active
		game_over_label.text = "庇护所失守" if game_over else ""
	if not is_instance_valid(clock_label): return
	main_title.hide()
	subtitle.hide()
	upkeep_label.hide()
	if not survivors.is_empty():
		var actor := survivors[selected_id]
		detail_label.size.y = 58
		detail_label.text = "生命%d / 饱腹%d\n水分%d / 精神%d\n四项满分100，越满越好" % [Vitals.value(actor,"health"),Vitals.value(actor,"fullness"),Vitals.value(actor,"hydration"),Vitals.value(actor,"vigor")]
		detail_label.tooltip_text = Vitals.summary(actor)
	var day := cycle.night_day if cycle.phase in ["planning", "scavenge", "returning"] else ExpeditionState.day_at(simulation_time)
	var minute := CampaignCycle.minute(simulation_time)
	if not is_instance_valid(compact): clock_label.text = "第%d天  %02d:%02d  %s%s" % [day, int(minute) / 60, int(minute) % 60, {"day": "白天", "planning": "夜间分工", "scavenge": "夜间搜刮", "returning": "迟归撤离", "dawn": "清晨"}[cycle.phase], " · 暂停" if paused else ""]
	var remaining := maxf(0, (1200 - minute) / 2.0 / speed) if cycle.phase == "day" else maxf(0, cycle.night_end - simulation_time)
	phase_label.text = "%s %02d:%02d · %s" % ["距20:00结束白天" if cycle.phase == "day" else "距06:00天亮", int(ceil(remaining)) / 60, int(ceil(remaining)) % 60, "白天生活与建设 / 夜晚分工" if cycle.phase == "day" else "每晚一次搜刮 / 提前归来也等到清晨"]
	subtitle.text = "左键走动 · 双击奔跑 · 点设施行动 · 右键取消 · B建设"
	day_bar.value = clampf((minute - 360) / 840.0 * 100, 0, 100) if cycle.phase == "day" else clampf((simulation_time - cycle.night_start) / maxf(1, cycle.night_end - cycle.night_start) * 100, 0, 100)
	progress_bar.hide()
	if selected_task == "heal" and actor_is_starving(): recipe_label.text = "饱腹不足：先吃饭才能恢复生命。\n用药仍可处理伤势与感染，不能代替食物。"
	if is_instance_valid(interface):
		interface.refresh()
		_sync_props()
	if is_instance_valid(compact) and not _updating_frame: compact.refresh()


func open_station(task_id: String) -> void:
	if cycle.phase != "day" or game_over: return
	if task_id in ["eat", "sleep"]:
		assign_task(task_id)
		context_open = false
		_refresh_hud()
	else: super.open_station(task_id)


func assign_selected() -> void:
	if cycle.phase != "day" or game_over: return
	var actor := survivors[selected_id]
	if selected_task == "heal" and actor.hunger >= 80 and actor.injury <= 0 and actor.infection <= 0 and actor.illness <= 0:
		_log("%s需要先吃饭；药品不能代替食物，没有消耗药品。" % actor.display_name)
		return
	if selected_task == "heal" and actor.health >= 100 and actor.injury <= 0 and actor.infection <= 0 and actor.illness <= 0:
		_log("%s目前不需要用药；没有消耗药品。" % actor.display_name)
		return
	var append := Input.is_physical_key_pressed(KEY_SHIFT)
	if not append:
		var available := inventory.snapshot()
		for key in actor.held_cost: available[key] += int(actor.held_cost[key])
		for build in cycle.builds:
			if build["state"] == "blueprint" and build["actor"] == selected_id:
				for key in CampaignCycle.RECIPES[build["type"]]["cost"]: available[key] += int(CampaignCycle.RECIPES[build["type"]]["cost"][key])
		for job in expansion.jobs:
			if job["actor"] == selected_id:
				for key in job["cost"]: available[key] += int(job["cost"][key])
		for key in TaskCatalog.TASKS[selected_task]["cost"]:
			if available[key] < int(TaskCatalog.TASKS[selected_task]["cost"][key]):
				_log("物资不足，保留原行动：" + ShelterInventory.describe(TaskCatalog.TASKS[selected_task]["cost"]))
				return
	_cancel_external(selected_id)
	if not append: scheduler.cancel(actor)
	var count := int(batch_count.value) if is_instance_valid(batch_count) and selected_task in ["cook", "craft", "repair"] else 1
	for index in range(count):
		if not scheduler.submit(actor, selected_task): break
	_refresh_hud()


func move_selected(point: Vector2) -> bool:
	if cycle.phase != "day": return false
	var target := Vector2(clampf(point.x, 140, 960), ShelterNavigation.UPPER_Y if scheduler.navigation.floor_at(point) == 1 else ShelterNavigation.LOWER_Y)
	if scheduler.navigation.route_between(survivors[selected_id].position, target).is_empty():
		_log("位置不可达，保留原行动。")
		return false
	_cancel_external(selected_id)
	return super.move_selected(point)


func cancel_selected() -> void:
	if cycle.phase != "day": return
	_cancel_external(selected_id)
	super.cancel_selected()
	var actor := survivors[selected_id]
	if actor.state == Survivor.TaskState.RETURNING:
		# Finish a stair landing instead of leaving an impossible mid-air state.
		var landing := ShelterNavigation.TOP_STAIR if scheduler.navigation.floor_at(actor.position) == 1 else ShelterNavigation.BOTTOM_STAIR
		if actor.position.y not in [430.0, 640.0]: actor.route = scheduler.navigation.route_between(actor.position, landing)
		else:
			actor.route.clear()
			actor.state = Survivor.TaskState.IDLE


func _unhandled_key_input(event: InputEvent) -> void:
	if (is_instance_valid(departure_dialog) and departure_dialog.visible) or (is_instance_valid(expedition_view) and is_instance_valid(expedition_view.equipment_dialog) and expedition_view.equipment_dialog.visible):
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F6: save_game()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if is_instance_valid(residence_view) and residence_view.opened:
			if event.physical_keycode in [KEY_H,KEY_ESCAPE]: residence_view.close()
			elif event.physical_keycode == KEY_F6: save_game()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_H and cycle.phase in ["day","planning"]:
			residence_view.toggle()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_T and expedition.active:
			expedition_retreat()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_L and expedition.active and not _loot_open:
			expedition.reload(survivors[expedition.actor_id])
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_K and cycle.phase in ["day", "planning"]:
			interface.toggle_workshop()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(interface) and interface.workshop_open:
			if event.physical_keycode == KEY_ESCAPE: interface.close_workshop()
			elif event.physical_keycode == KEY_F6: save_game()
			elif event.physical_keycode == KEY_F9:
				interface.close_workshop()
				request_load()
			elif event.physical_keycode == KEY_F11: center._set_fullscreen(not game_audio.fullscreen)
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(interface) and (cycle.phase in ["planning", "dawn"] or _loot_open):
			if event.physical_keycode == KEY_F6: save_game()
			elif event.physical_keycode == KEY_F9: request_load()
			elif event.physical_keycode == KEY_F11: center._set_fullscreen(not game_audio.fullscreen)
			elif event.physical_keycode == KEY_ESCAPE and _loot_open: close_loot()
			elif event.physical_keycode == KEY_SPACE and _loot_open: toggle_pause()
			elif event.physical_keycode == KEY_F and _loot_open: interface._take_all()
			elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and cycle.phase == "planning": start_expedition()
			elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and cycle.phase == "dawn": begin_day()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_B and cycle.phase == "day":
			interface.toggle_build_menu()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_ESCAPE and not placement.is_empty():
			placement = ""
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_E and cycle.phase == "day" and not context_open:
			_log("点击设施图标执行行动；制作先选择配方再按E。")
			return
	super._unhandled_key_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if (is_instance_valid(departure_dialog) and departure_dialog.visible) or (is_instance_valid(expedition_view.equipment_dialog) and expedition_view.equipment_dialog.visible): return
	if not event is InputEventMouseButton or not event.pressed or game_over or center.visible or (is_instance_valid(residence_view) and residence_view.opened): return
	if cycle.phase in ["planning", "dawn"] or _loot_open: return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if expedition.active:
			cycle.return_requested = false
			interface.has_move_target = false
			expedition_view.search_held = false
		else:
			placement = ""
			cancel_selected()
		get_viewport().set_input_as_handled()
		return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	var point: Vector2 = (event.position - world_offset()) / world_scale()
	if expedition.active:
		if cycle.phase == "returning": return
		cycle.return_requested = false
		point.x += expedition_view._camera()
		var floor_level := 1 if point.y < 470 and point.x >= expedition.upper_left() else 0
		var site := -1
		for index in range(expedition.site_definitions().size()):
			var definition: Dictionary = expedition.site_definitions()[index]
			if expedition.site_hit_rect(index).has_point(point):
				site = index
				point.x = definition["x"]
				floor_level = definition["floor"]
				break
		interface.set_target(clampf(point.x, 90 if floor_level == 0 else expedition.upper_left(), expedition.right_edge(floor_level)), floor_level, event.double_click, site)
		if site < 0:
			for index in range(expedition.enemies.size()):
				var enemy: Dictionary = expedition.enemies[index]
				if enemy["hp"] > 0 and absf(point.x - float(enemy["x"])) < 34 and absf(point.y - ExpeditionState.FLOOR_Y[int(enemy["floor"])]) < 90:
					interface.target_enemy = index
					break
		get_viewport().set_input_as_handled()
	elif Rect2(113, 300, 874, 355).has_point(point):
		if not placement.is_empty():
			var slot := -1
			for index in range(CampaignCycle.SLOTS.size()):
				if point.distance_to(CampaignCycle.SLOTS[index] - Vector2(0, 25)) < 85: slot = index
			if slot >= 0: place_build(placement, slot)
		else:
			if move_selected(point): survivors[selected_id].move_multiplier = 1.8 if event.double_click else 1.0
		get_viewport().set_input_as_handled()


func begin_drink() -> void:
	if cycle.phase != "day" or survivors[selected_id].health <= 0: return
	if inventory.amount("water") < 1:
		_log("没有水，无法饮用。")
		return
	_start_action("drink", -1, water_store.position)


func _start_action(kind: String, slot: int, target: Vector2) -> bool:
	var actor := survivors[selected_id]
	if actor.health <= 0 or cycle.phase != "day": return false
	var route := scheduler.navigation.route_between(actor.position, target)
	if route.is_empty(): return false
	_cancel_external(selected_id)
	scheduler.cancel(actor)
	actor.route = route
	actor.state = Survivor.TaskState.RETURNING
	actor.feedback = "前往饮水" if kind == "drink" else "前往床位休息"
	cycle.actions.append({"actor": selected_id, "kind": kind, "slot": slot, "elapsed": 0.0})
	context_open = false
	return true


func place_build(type: String, slot: int) -> bool:
	if cycle.phase != "day" or not CampaignCycle.RECIPES.has(type) or slot < 0 or slot >= CampaignCycle.SLOTS.size() or survivors[selected_id].health <= 0: return false
	if cycle.builds.any(func(build): return build["slot"] == slot):
		_log("该建设位置已被占用。")
		return false
	if type != "bed" and cycle.builds.any(func(build): return build["type"] == type):
		_log("该设施只能建造一座。")
		return false
	if type == "bed" and cycle.builds.filter(func(build): return build["type"] == "bed").size() >= 2: return false
	var target: Vector2 = CampaignCycle.SLOTS[slot]
	var actor := survivors[selected_id]
	var route := scheduler.navigation.route_between(actor.position, target)
	if route.is_empty() or not inventory.can_take(CampaignCycle.RECIPES[type]["cost"]):
		_log("建设未执行：物资不足或位置不可达。")
		return false
	_cancel_external(selected_id)
	scheduler.cancel(actor)
	if not inventory.try_take(CampaignCycle.RECIPES[type]["cost"], "建设" + CampaignCycle.RECIPES[type]["name"]): return false
	cycle.builds.append({"slot": slot, "type": type, "state": "blueprint", "actor": selected_id, "elapsed": 0.0})
	actor.route = route
	actor.state = Survivor.TaskState.RETURNING
	actor.feedback = "前往建设位置"
	placement = ""
	_log("%s开始建设%s。到达后施工，完成才生效；取消或日落退还未完成用料。" % [actor.display_name, CampaignCycle.RECIPES[type]["name"]])
	_props_signature = ""
	return true


func _external_busy(id: int) -> bool:
	return shelter_keyboard.actor_id == id or expansion.jobs.any(func(job): return job["actor"] == id) or cycle.builds.any(func(build): return build["state"] == "blueprint" and build["actor"] == id) or cycle.actions.any(func(action): return action["actor"] == id)


func _cancel_external(id: int, refund: bool = true) -> void:
	if shelter_keyboard.actor_id == id: shelter_keyboard.stop(self)
	expansion.cancel(self, id, refund)
	for build in cycle.builds.duplicate():
		if build["state"] == "blueprint" and build["actor"] == id:
			if refund: inventory.deposit(CampaignCycle.RECIPES[build["type"]]["cost"], "取消未完成建设，退料")
			cycle.builds.erase(build)
	for action in cycle.actions.duplicate():
		if action["actor"] == id: cycle.actions.erase(action)
	survivors[id].activity.clear()
	_props_signature = ""


func _cancel_all_day_work() -> void:
	shelter_keyboard.stop(self)
	for actor in survivors:
		_cancel_external(actor.survivor_id)
		scheduler.cancel(actor)
		if actor.health > 0 and actor.state == Survivor.TaskState.RETURNING:
			# Preserve a valid landing when ending a day midway on the stairs.
			if actor.position.y not in [430.0, 640.0]: actor.position = ShelterNavigation.TOP_STAIR if scheduler.navigation.floor_at(actor.position) == 1 else ShelterNavigation.BOTTOM_STAIR
			actor.route.clear()
			actor.state = Survivor.TaskState.IDLE


func _tick_external(step: float) -> void:
	for actor in survivors:
		if actor.health <= 0 and _external_busy(actor.survivor_id): _cancel_external(actor.survivor_id, false)
	for build in cycle.builds:
		if build["state"] != "blueprint": continue
		var actor := survivors[int(build["actor"])]
		if not actor.route.is_empty(): continue
		build["elapsed"] = minf(CampaignCycle.RECIPES[build["type"]]["seconds"], float(build["elapsed"]) + step * actor.effort_factor() * actor.person.bonus("craft"))
		actor.activity = {"kind": "build", "label": "建设" + CampaignCycle.RECIPES[build["type"]]["name"], "progress": build["elapsed"] / CampaignCycle.RECIPES[build["type"]]["seconds"]}
		if build["elapsed"] >= CampaignCycle.RECIPES[build["type"]]["seconds"]:
			build["state"] = "complete"
			build["actor"] = -1
			actor.activity.clear()
			actor.person.gain("craft", 8)
			_log(CampaignCycle.RECIPES[build["type"]]["name"] + "建成，已在场景中生效。")
			_props_signature = ""
	for action in cycle.actions.duplicate():
		var actor := survivors[int(action["actor"])]
		if not actor.route.is_empty(): continue
		var duration := 20.0 if action["kind"] == "sleep" else 2.0
		action["elapsed"] = minf(duration, float(action["elapsed"]) + step)
		actor.activity = {"kind": action["kind"], "label": "床上休息" if action["kind"] == "sleep" else "饮水", "progress": action["elapsed"] / duration}
		if action["kind"] == "sleep": actor.fatigue = maxf(0, actor.fatigue - step * 3 * CharacterAbilities.factor(actor,"sleep"))
		if action["elapsed"] >= duration:
			if action["kind"] == "drink": people.drink(self, actor.survivor_id)
			else:
				actor.completed_jobs += 1
				actor.completed_by_task["sleep"] += 1
				bed.completed_jobs += 1
				scheduler.task_finished.emit(actor.survivor_id, "sleep")
			actor.activity.clear()
			cycle.actions.erase(action)


func _sync_props() -> void:
	var signature := str(cycle.builds.map(func(build): return [build["slot"], build["type"], build["state"]]))
	if signature == _props_signature: return
	_props_signature = signature
	for prop in _extra_props: prop.queue_free()
	_extra_props.clear()
	for build in cycle.builds:
		if build["state"] != "complete" or build["type"] != "bed": continue
		var station := Workstation.new()
		station.facility_id = "bed"
		station.display_name = "新增床位"
		station.position = CampaignCycle.SLOTS[int(build["slot"])]
		var slot := int(build["slot"])
		station.clicked.connect(func():
			if cycle.actions.any(func(action): return action["kind"] == "sleep" and action["slot"] == slot):
				_log("该床位正在使用，请选择另一张床。")
			else: _start_action("sleep", slot, CampaignCycle.SLOTS[slot])
		)
		world_root.add_child(station)
		_extra_props.append(station)


func _draw_house_details() -> void:
	super._draw_house_details()
	if cycle.builds.any(func(build): return build["slot"] == 4): draw_rect(Rect2(850, 520, 125, 120), Color("26302c"))
	if not placement.is_empty():
		for index in range(CampaignCycle.SLOTS.size()):
			var point: Vector2 = CampaignCycle.SLOTS[index]
			var used := cycle.builds.any(func(build): return build["slot"] == index)
			draw_rect(Rect2(point - Vector2(59, 63), Vector2(118, 63)), Color(0.5, 0.15, 0.1, 0.3) if used else Color(0.45, 0.7, 0.5, 0.25))
			draw_string(FONT, point + Vector2(-40, -72), "已占用" if used else "点击放置", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)
	for build in cycle.builds:
		var point: Vector2 = CampaignCycle.SLOTS[int(build["slot"])]
		var complete: bool = build["state"] == "complete"
		var tint := Color("7d8b70") if complete else Color("526c6b")
		match build["type"]:
			"bed":
				draw_rect(Rect2(point + Vector2(-60, -29), Vector2(120, 15)), tint)
				draw_rect(Rect2(point + Vector2(-54, -36), Vector2(26, 9)), tint.lightened(0.3))
				draw_line(point + Vector2(-53, -15), point + Vector2(-53, 0), tint, 5)
				draw_line(point + Vector2(53, -15), point + Vector2(53, 0), tint, 5)
			"heater":
				draw_rect(Rect2(point + Vector2(-27, -56), Vector2(54, 56)), tint)
				draw_rect(Rect2(point + Vector2(-18, -40), Vector2(36, 24)), Color("d59b54") if expansion.heater_remaining > 0 else Color("192424"))
				draw_line(point + Vector2(20, -56), point + Vector2(20, -110), tint, 9)
			"filter":
				draw_rect(Rect2(point + Vector2(-27, -53), Vector2(54, 53)), tint)
				draw_colored_polygon(PackedVector2Array([point + Vector2(-44, -78), point + Vector2(44, -78), point + Vector2(9, -53)]), tint.lightened(0.2))
			"barricade":
				for x in [-36, -12, 12, 36]: draw_line(point + Vector2(x, -95), point + Vector2(x, 0), tint, 8)
				draw_line(point + Vector2(-42, -65), point + Vector2(43, -36), tint.lightened(0.15), 7)
		if not complete:
			draw_string(FONT, point + Vector2(-50, -105), "施工中 · 可取消", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)


func _configure_manual() -> void:
	for node in center.tabs.get_child(3).find_children("*", "Label", true, false):
		if node.text.begins_with("1. 给留守者"):
			node.text = "1. 点击人物或底部卡片选人；左键地面行走，双击奔跑，右键取消。\n2. 点床休息、点餐桌吃饭、点水桶走过去饮水。R让选中者自行用药。\n3. 点灶台／工作台选择配方与批数后确认。新命令替换旧命令，按住Shift可追加。\n4. B选择建设，再点绿色位置；人物会走过去施工，完成后才有作用。K打开装备与战役，人物需走到工作台制作；取暖炉需点燃。H打开家园，安排门窗加固、维护、音乐和迁居。\n5. 20:00进入夜间分工，也可点击结束白天。选择一位搜刮者，其他人守夜或睡眠。\n6. 选择目的地、携带物资再出发；每晚一次，提前归来也结算到清晨。"
		elif node.text.begins_with("基地："):
			node.text = "白天：A/D或方向键移动，Shift奔跑，楼梯口W/S上下楼；左键走动，双击奔跑，右键取消；1–6／Tab选人，B建设，F／G／C／R为快捷行动，H家园与迁居，Shift追加队列。\n夜间：点地面移动、点容器走近搜索；A/D与W/S也可控制。搜索后逐份拿取／放回，F尽量全部拿走，Esc关闭；整理时夜间时间继续，空格可明确暂停。\n点击敌人靠近并挥击，J也可攻击、L为手枪换弹、R背包用药、B背包饮水、I背包、T在入口撤退。20:00出发，06:00天亮；迟归会沿实际路线自动撤回并增加疲劳与压力。\n分工画面Enter确认，清晨Enter开始新的一天。F6保存、F9读档、F11全屏、Esc菜单。"


func actor_is_starving() -> bool:
	return not survivors.is_empty() and survivors[selected_id].hunger >= 80


func _log(message: String) -> void:
	if is_instance_valid(game_audio): game_audio.cue(message)
	toast_time = 6.0
	var minute := int(CampaignCycle.minute(simulation_time))
	logs.push_front("%02d:%02d   %s" % [minute / 60, minute % 60, message])
	if logs.size() > 4: logs.pop_back()
	_refresh_log()


func _draw_day_intent() -> void:
	if cycle.phase != "day" or survivors.is_empty(): return
	var actor := survivors[selected_id]
	if actor.route.is_empty(): return
	draw_set_transform(world_offset(),0,world_scale())
	var from := actor.position
	for to in actor.route:
		var distance := from.distance_to(to)
		for step in range(0,int(distance),22): draw_circle(from.lerp(to,step/maxf(1,distance))-Vector2(0,2),1.5,Color(0.85,0.76,0.56,0.4))
		from = to
	draw_arc(actor.route.back()-Vector2(0,2),12,0,TAU,24,Color("d6b584"),1.5,true)
	draw_set_transform(Vector2.ZERO)
