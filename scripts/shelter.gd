extends Node2D
## Scene composition and player commands. Task rules live in TaskScheduler;
## navigation lives in ShelterNavigation. The HUD only reads their state.

const FONT := preload("res://assets/fonts/interface.otf")
const INK := Color("d8ded7")
const MUTED := Color("85928e")
const GOLD := Color("d6b584")
const GREEN := Color("a5bba1")

var survivors: Array[Survivor] = []
var facility: Workstation
var stove: Workstation
var dining_table: Workstation
var bed: Workstation
var inventory := ShelterInventory.new()
var selected_task := "repair"
var scheduler := TaskScheduler.new()
var selected_id := 0
var simulation_time := 0.0
var paused := false
var speed := 1.0
var weather_time := 0.0
var hud: Control
var cards: Array[Button] = []
var clock_label: Label
var selected_label: Label
var speciality_label: Label
var detail_label: Label
var status_label: Label
var queue_label: Label
var facility_label: Label
var completed_label: Label
var tutorial_label: Label
var log_label: Label
var progress_bar: ProgressBar
var assign_button: Button
var cancel_button: Button
var pause_button: Button
var speed_button: Button
var logs: Array[String] = []
var stock_label: Label
var task_heading: Label
var recipe_label: Label
var workbench_tab: Button
var stove_tab: Button
var task_tabs: Dictionary = {}
var save_label: Label
var game_over_label: Label
var save_store := SaveSystem.new()
var persistence_enabled := true
var auto_save_allowed := true
var game_over := false
var _last_auto_attempt := 0.0
var _save_status := "F6 保存 / F9 读档"
var _initial_state: Dictionary = {}
var load_dialog: ConfirmationDialog
var new_dialog: ConfirmationDialog
var exit_dialog: ConfirmationDialog
var _dialog_pause_before := false
var _quitting := false
var expedition := ExpeditionState.new()
var regions: Dictionary = {}
var upkeep := ShelterProgress.new()
var people := PeopleSystem.new()
var story := StorySystem.new()
var goals := GoalSystem.new()
var center: CommandCenter
var game_audio: GameAudio
var prep_destination: OptionButton
var upkeep_label: Label
var expedition_view: ExpeditionView
var expedition_controls_override: Variant = null
var prep_dialog: ConfirmationDialog
var prep_tool: CheckBox
var prep_medicine: CheckBox
var prep_text: Label
var base_hud_nodes: Array[Control] = []
var main_title: Label
var subtitle: Label
var world_root: Node2D
var water_store: Workstation
var exit_door: Workstation
const WORLD_SCALE := Vector2(1.3, 1.3)
const WORLD_OFFSET := Vector2(16, -130)
var context_nodes: Array[Control] = []
var context_open := false
var day_bar: ProgressBar
var phase_label: Label
var toast_time := 0.0
var move_marker := Vector2.ZERO
var move_marker_time := 0.0


func world_scale() -> Vector2:
	return WORLD_SCALE


func world_offset() -> Vector2:
	return WORLD_OFFSET


func _region_ids() -> Array:
	return LocationCatalog.IDS


func _ready() -> void:
	get_tree().auto_accept_quit = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-slot="): save_store.path = argument.trim_prefix("--qa-slot=")
	get_window().close_requested.connect(_on_window_close_requested)
	if DisplayServer.get_name() != "headless": get_window().title = "Live Forever · 留一盏灯 v0.9"
	for id in _region_ids():
		regions[id] = expedition if id == "street" else ExpeditionState.new(id)
	_create_world()
	scheduler.upkeep = upkeep
	scheduler.configure(survivors, [facility, stove, dining_table, bed], inventory)
	scheduler.event_reported.connect(_log)
	people.sync_members(survivors)
	people.event_reported.connect(_log)
	story.event_reported.connect(_log)
	goals.event_reported.connect(_log)
	scheduler.task_finished.connect(func(id: int, task: String): people.job_completed(self, id, task))
	scheduler.task_finished.connect(func(_id: int, task: String): story.job_completed(task))
	scheduler.survivor_lost.connect(func(id: int): people.survivor_lost(self, id))
	for world: ExpeditionState in regions.values():
		world.event_reported.connect(_log)
		world.returned.connect(_on_expedition_returned)
		world.site_searched.connect(func(index: int): goals.found_site(world.location_id, index))
	upkeep.event_reported.connect(_log)
	game_audio = GameAudio.new()
	game_audio.persistent = persistence_enabled
	add_child(game_audio)
	_create_hud()
	center = CommandCenter.new()
	center.game = self
	add_child(center)
	select_survivor(0)
	_log("先做饭、吃饭，再安排休息。燃料只够三锅，补给还很有限。")
	_initial_state = SaveSystem.capture(self)
	if persistence_enabled:
		if save_store.has_save():
			load_game()
	_refresh_hud()


func _create_world() -> void:
	world_root = Node2D.new()
	world_root.position = world_offset()
	world_root.scale = world_scale()
	add_child(world_root)
	facility = Workstation.new()
	facility.position = Vector2(485, ShelterNavigation.LOWER_Y)
	facility.clicked.connect(open_station.bind("repair"))
	world_root.add_child(facility)
	stove = Workstation.new()
	stove.facility_id = "stove"
	stove.display_name = "灶台"
	stove.position = Vector2(930, ShelterNavigation.UPPER_Y)
	stove.clicked.connect(open_station.bind("cook"))
	world_root.add_child(stove)
	dining_table = Workstation.new()
	dining_table.facility_id = "table"
	dining_table.display_name = "餐桌"
	dining_table.position = Vector2(555, ShelterNavigation.UPPER_Y)
	dining_table.clicked.connect(open_station.bind("eat"))
	world_root.add_child(dining_table)
	bed = Workstation.new()
	bed.facility_id = "bed"
	bed.display_name = "床位"
	bed.position = Vector2(345, ShelterNavigation.UPPER_Y)
	bed.clicked.connect(open_station.bind("sleep"))
	world_root.add_child(bed)
	water_store = Workstation.new()
	water_store.facility_id = "water"
	water_store.display_name = "饮水储备"
	water_store.position = Vector2(190, ShelterNavigation.LOWER_Y)
	water_store.clicked.connect(func():
		if not people.drink(self, selected_id): _log("%s饮水未执行：检查水库存、口渴和人物状态。" % survivors[selected_id].display_name)
		_refresh_hud()
	)
	world_root.add_child(water_store)
	exit_door = Workstation.new()
	exit_door.facility_id = "exit"
	exit_door.display_name = "外出入口"
	exit_door.position = Vector2(115, ShelterNavigation.LOWER_Y)
	exit_door.clicked.connect(request_expedition)
	world_root.add_child(exit_door)
	for index in range(PeopleCatalog.ORIGINALS.size()):
		var actor := add_survivor(PeopleCatalog.ORIGINALS[index])
		actor.position = [Vector2(330, 430), Vector2(560, 430), Vector2(260, 640)][index]
		actor.hunger = [45.0, 58.0, 35.0][index]
		actor.fatigue = [30.0, 65.0, 45.0][index]
	expedition_view = ExpeditionView.new()
	expedition_view.game = self
	add_child(expedition_view)


func _process(delta: float) -> void:
	weather_time += delta
	toast_time = maxf(0, toast_time - delta)
	move_marker_time = maxf(0, move_marker_time - delta)
	# Window stalls must not silently simulate a long unattended period.
	advance_simulation(minf(delta, 0.1))
	_refresh_hud()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and is_instance_valid(expedition_view):
		expedition_view.search_held = false
		for code in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SHIFT, KEY_CTRL, KEY_E]:
			if Input.is_physical_key_pressed(code):
				var release := InputEventKey.new()
				release.physical_keycode = code
				release.pressed = false
				Input.parse_input_event(release)
		if not paused and not _quitting:
			paused = true
			_log("窗口失去焦点，已暂停。返回后按空格继续。")


func advance_simulation(delta: float) -> void:
	if paused or game_over or delta <= 0:
		return
	var remaining := delta * speed
	# Same maximum simulation step at 1x, 3x and in regression tests.
	while remaining > 0.0000001 and not game_over and not paused:
		var step := minf(remaining, 1.0 / 60.0)
		_advance_world_step(step)
		remaining -= step
		if survivors.all(func(actor: Survivor): return actor.health <= 0):
			game_over = true
			paused = true
			_log("庇护所失守：所有幸存者已死亡。可以读档，或新开一局。")
	if persistence_enabled and auto_save_allowed and simulation_time - _last_auto_attempt >= 60.0:
		save_game(true)


func _advance_world_step(step: float) -> void:
	simulation_time += step
	upkeep.tick(step, simulation_time)
	for actor in survivors:
		SurvivalRules.tick(actor, step)
		_check_warnings(actor)
		if actor.health <= 0 and actor.state != Survivor.TaskState.DEAD:
			scheduler.mark_dead(actor)
	people.tick(self, step)
	for actor: Survivor in survivors:
		if actor.health <= 0 and actor.state != Survivor.TaskState.DEAD: scheduler.mark_dead(actor, "严重缺水")
	scheduler.step(step)
	if expedition.active:
		expedition.tick(step, survivors[expedition.actor_id], _expedition_controls())
	story.tick(self)


func _check_warnings(actor: Survivor) -> void:
	if actor.health <= 0:
		return
	for need in ["hunger", "fatigue", "health", "infection"]:
		var value := float(actor.get(need))
		var threshold := 80.0 if need == "hunger" else 85.0 if need == "fatigue" else 30.0
		var danger := value <= threshold if need == "health" else value >= threshold
		if danger and not actor.warned[need]:
			actor.warned[need] = true
			var advice := "饱腹不足，请安排吃饭；低至5会持续损失生命。" if need == "hunger" else "精神不足，请安排睡觉；低至2会持续损失生命。" if need == "fatigue" else "感染加重，请用药治疗；达到60会持续损失生命。" if need == "infection" else "生命垂危！检查伤势、感染、食物与休息。"
			_log(actor.display_name + "：" + advice)
		elif not danger and (value > threshold + 10 if need == "health" else value < threshold - 10):
			actor.warned[need] = false


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		center._set_fullscreen(not game_audio.fullscreen)
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(center) and center.visible:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			center.close()
		return
	if (is_instance_valid(load_dialog) and load_dialog.visible) or (is_instance_valid(new_dialog) and new_dialog.visible) or (is_instance_valid(exit_dialog) and exit_dialog.visible) or (is_instance_valid(prep_dialog) and prep_dialog.visible):
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE and expedition.active and expedition_view.bag_open:
		expedition_view.toggle_bag()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE and context_open:
		context_open = false
		_refresh_hud()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode in [KEY_ESCAPE, KEY_F1, KEY_M, KEY_P, KEY_N, KEY_O]:
		open_center(7 if event.physical_keycode == KEY_O else 6 if event.physical_keycode == KEY_N else 5 if event.physical_keycode == KEY_P else 3 if event.physical_keycode == KEY_F1 else 0 if event.physical_keycode == KEY_M else 4)
		get_viewport().set_input_as_handled()
		return
	if expedition.active:
		match event.physical_keycode:
			KEY_F6: save_game()
			KEY_F9: request_load()
			KEY_SPACE: toggle_pause()
			KEY_J: expedition_attack()
			KEY_R: expedition_medicine()
			KEY_B: people.drink(self, selected_id)
			KEY_T: expedition_retreat()
			KEY_I: expedition_view.toggle_bag()
		get_viewport().set_input_as_handled()
		return
	match event.physical_keycode:
		KEY_1: select_survivor(0)
		KEY_2: select_survivor(1)
		KEY_3: select_survivor(2)
		KEY_4: select_survivor(3)
		KEY_5: select_survivor(4)
		KEY_6: select_survivor(5)
		KEY_TAB: select_survivor((selected_id + 1) % survivors.size())
		KEY_E: assign_selected()
		KEY_F: assign_task("cook")
		KEY_G: assign_task("eat")
		KEY_H: assign_task("sleep")
		KEY_C: assign_task("craft")
		KEY_R: assign_task("heal")
		KEY_V: request_expedition()
		KEY_F6: save_game()
		KEY_F9: request_load()
		KEY_Q: cancel_selected()
		KEY_SPACE: toggle_pause()
		_: return
	get_viewport().set_input_as_handled()


func select_survivor(index: int) -> void:
	if expedition.active and index != expedition.actor_id:
		return
	if index < 0 or index >= survivors.size():
		return
	selected_id = index
	for actor in survivors:
		actor.selected = actor.survivor_id == index
		actor.queue_redraw()
	if is_instance_valid(hud):
		_refresh_hud()


func assign_selected() -> void:
	scheduler.submit(survivors[selected_id], selected_task)
	_refresh_hud()


func select_task(task_id: String) -> void:
	context_open = true
	selected_task = task_id
	_refresh_hud()


func assign_task(task_id: String) -> void:
	context_open = true
	selected_task = task_id
	assign_selected()


func open_station(task_id: String) -> void:
	if expedition.active or game_over: return
	select_task(task_id)


func _unhandled_input(event: InputEvent) -> void:
	if expedition.active or game_over or center.visible: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var point: Vector2 = (event.position - world_offset()) / world_scale()
			if Rect2(113, 300, 874, 355).has_point(point):
				move_selected(point)
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and context_open:
			context_open = false
			_refresh_hud()


func move_selected(point: Vector2) -> bool:
	if expedition.active or game_over or center.visible or prep_dialog.visible or load_dialog.visible or new_dialog.visible or exit_dialog.visible: return false
	var actor := survivors[selected_id]
	if actor.health <= 0: return false
	var destination := Vector2(clampf(point.x, 140, 960), ShelterNavigation.UPPER_Y if scheduler.navigation.floor_at(point) == 1 else ShelterNavigation.LOWER_Y)
	var route := scheduler.navigation.route_between(actor.position, destination)
	if route.is_empty():
		_log("楼梯不可通行，无法前往该处。")
		return false
	scheduler.cancel(actor)
	actor.route = route
	actor.state = Survivor.TaskState.RETURNING
	actor.feedback = "移动到指定位置"
	move_marker = destination
	move_marker_time = 1.0
	context_open = false
	_refresh_hud()
	return true


func cancel_selected() -> void:
	scheduler.cancel(survivors[selected_id])
	_refresh_hud()


func toggle_pause() -> void:
	if game_over:
		return
	paused = not paused
	if not paused: _save_status = _save_status.replace("（已暂停）", "")
	_refresh_hud()


func toggle_speed() -> void:
	if expedition.active:
		_log("外出期间固定1倍速，防止危险被加速。")
		return
	speed = 3.0 if speed == 1.0 else 1.0
	_refresh_hud()


func _log(message: String) -> void:
	if is_instance_valid(game_audio): game_audio.cue(message)
	toast_time = 6.0
	logs.push_front("%02d:%02d   %s" % [int(simulation_time) / 60, int(simulation_time) % 60, message])
	if logs.size() > 4:
		logs.pop_back()
	_refresh_log()


func _refresh_log() -> void:
	if is_instance_valid(log_label):
		log_label.text = logs[0] if not logs.is_empty() else ""
		log_label.tooltip_text = "\n\n".join(logs)


func save_game(automatic: bool = false) -> bool:
	if not persistence_enabled:
		return false
	_last_auto_attempt = simulation_time
	var result := save_store.write_state(self)
	_save_status = ("自动保存成功" if automatic else "保存成功") if result["ok"] else "保存失败：" + result["message"]
	if result["ok"]:
		auto_save_allowed = true
	if not automatic or not result["ok"]:
		_log(_save_status)
	_refresh_hud()
	return result["ok"]


func load_game() -> bool:
	var result := save_store.read_state()
	if not result["ok"]:
		auto_save_allowed = false
		_save_status = "读档失败，自动保存已停用"
		_log("读档失败，当前游戏保留：%s。手动保存可覆盖主档。" % result["message"])
		_refresh_hud()
		return false
	var error := SaveSystem.apply_state(self, result["data"])
	if not error.is_empty():
		_save_status = "读档失败：" + error
		return false
	paused = true
	_last_auto_attempt = simulation_time
	auto_save_allowed = true
	_save_status = "已从备份恢复（已暂停）" if result["backup"] else "已恢复存档（已暂停）"
	if result.get("migrated", false):
		_save_status = "旧备份已迁移恢复（已暂停）" if result["backup"] else "旧存档已迁移（已暂停）"
	_log(_save_status + "。检查任务和状态后按空格继续。")
	_refresh_hud()
	return true


func request_load() -> void:
	if not save_store.has_save():
		_log("还没有存档。先按 F6 保存当前进度。")
		return
	_dialog_pause_before = paused
	paused = true
	load_dialog.popup_centered()
	_refresh_hud()


func request_new_game() -> void:
	_dialog_pause_before = paused
	paused = true
	new_dialog.popup_centered()
	_refresh_hud()


func start_new_game() -> void:
	var error := SaveSystem.apply_state(self, _initial_state)
	if not error.is_empty():
		_log(error)
		return
	game_over = false
	paused = false
	auto_save_allowed = true
	_last_auto_attempt = 0.0
	_log("开始新的一局。先准备热饭，再分配休息。")
	if persistence_enabled:
		save_game()
	_refresh_hud()


func _cancel_dialog() -> void:
	paused = _dialog_pause_before or game_over
	_refresh_hud()


func _confirmation(title_text: String, message: String) -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.title = title_text
	dialog.dialog_text = message
	dialog.min_size = Vector2i(580, 180)
	var dialog_theme := Theme.new()
	dialog_theme.default_font = FONT
	dialog_theme.default_font_size = 16
	dialog.theme = dialog_theme
	dialog.ok_button_text = "确认"
	dialog.cancel_button_text = "取消"
	dialog.canceled.connect(_cancel_dialog)
	add_child(dialog)
	return dialog


func _on_window_close_requested() -> void:
	_exit_note("close request received")
	if not persistence_enabled or _quitting: return
	if is_instance_valid(exit_dialog) and exit_dialog.visible: return
	if auto_save_allowed and save_game(true):
		_exit_note("save complete")
		_quit_cleanly()
	else:
		_dialog_pause_before = paused
		paused = true
		exit_dialog.popup_centered()


func _expedition_controls() -> Dictionary:
	if expedition_controls_override is Dictionary:
		return expedition_controls_override
	return {
		"axis": float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		"climb": int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) - int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)),
		"sneak": Input.is_physical_key_pressed(KEY_CTRL), "sprint": Input.is_physical_key_pressed(KEY_SHIFT),
		"interact": Input.is_physical_key_pressed(KEY_E) or expedition_view.search_held,
	}


func open_center(page: int = 0) -> void:
	if prep_dialog.visible or load_dialog.visible or new_dialog.visible or exit_dialog.visible: return
	center.open(page)


func choose_destination(id: String) -> bool:
	if expedition.active or not regions.has(id): return false
	expedition = regions[id]
	if is_instance_valid(prep_destination): prep_destination.select(maxi(0, LocationCatalog.IDS.find(id)))
	if is_instance_valid(prep_text): _refresh_preparation()
	return true


func request_expedition() -> void:
	if expedition.active or game_over or survivors[selected_id].health <= 0:
		_log("当前无法派人出发。")
		return
	_dialog_pause_before = paused
	paused = true
	prep_destination.select(LocationCatalog.IDS.find(expedition.location_id))
	_refresh_preparation()
	prep_tool.disabled = inventory.amount("tools") < 1
	prep_tool.button_pressed = not prep_tool.disabled
	prep_medicine.disabled = inventory.amount("medicine") < 1
	prep_medicine.button_pressed = not prep_medicine.disabled
	prep_dialog.popup_centered()
	_refresh_hud()


func _refresh_preparation() -> void:
	expedition.refresh_for_day(ExpeditionState.day_at(simulation_time))
	var actor := survivors[selected_id]
	var threats := 0
	for enemy in expedition.enemies:
		if enemy["hp"] > 0: threats += 1
	var area := expedition.area()
	var forecast := expedition.weather()
	prep_text.text = "%s → %s  /  风险%s  /  %s\n生命%d · 饱腹%d · 精神%d；取消本人任务并退料。\n水分%d · 心境%d · 压力%d；留守照料按授权继续。\n%s\n已知感染者%d；背包10格，必须回入口撤退。\n%s" % [actor.display_name, area["name"], area["risk"], forecast["name"], Vitals.value(actor,"health"), Vitals.value(actor,"fullness"), Vitals.value(actor,"vigor"), Vitals.value(actor,"hydration"), roundi(actor.person.morale), roundi(actor.person.stress), area["summary"], threats, forecast["hint"]]


func start_expedition(take_tool: bool = false, take_medicine: bool = false) -> bool:
	if expedition.active or game_over or survivors[selected_id].health <= 0:
		return false
	var loadout := {}
	if take_tool: loadout["tools"] = 1
	if take_medicine: loadout["medicine"] = 1
	if not inventory.try_take(loadout, "%s外出携带物资" % survivors[selected_id].display_name):
		_log("出发失败：携带物资不足，基地状态未改变。")
		return false
	expedition.refresh_for_day(ExpeditionState.day_at(simulation_time))
	var actor := survivors[selected_id]
	scheduler.cancel(actor)
	actor.route.clear()
	actor.work_elapsed = 0
	actor.state = Survivor.TaskState.AWAY
	actor.feedback = "外出探索中"
	upkeep.begin_trip(loadout)
	expedition.begin(selected_id, loadout, speed)
	context_open = false
	speed = 1.0
	paused = false
	_save_status = _save_status.replace("（已暂停）", "")
	_log("%s进入%s。观察敌人、搜刮物资；回入口才能撤退。" % [actor.display_name, expedition.area()["name"]])
	_refresh_hud()
	queue_redraw()
	return true


func expedition_attack() -> void:
	if expedition.active and not paused:
		expedition.attack(survivors[expedition.actor_id])


func expedition_medicine() -> void:
	if expedition.active and not paused:
		expedition.use_medicine(survivors[expedition.actor_id])


func expedition_drop(resource: String) -> void:
	if expedition.active:
		expedition.drop(resource)


func expedition_retreat() -> void:
	if paused: return
	expedition.request_retreat()
	_refresh_hud()


func _on_expedition_returned(id: int, cargo: Dictionary, survived: bool) -> void:
	var actor := survivors[id]
	goals.returned(cargo, upkeep.trip_loadout, survived and actor.health > 0)
	people.returned(self, actor, cargo, upkeep.trip_loadout, survived and actor.health > 0)
	upkeep.finish_trip(expedition.location_id, cargo, survived and actor.health > 0)
	if survived and actor.health > 0:
		actor.state = Survivor.TaskState.IDLE
		actor.position = Vector2(260, ShelterNavigation.LOWER_Y)
		actor.feedback = "探索归来 · 等待安排"
		var recovered := {}
		for resource in cargo:
			if cargo[resource] > 0: recovered[resource] = cargo[resource]
		inventory.deposit(recovered, "%s探索归来" % actor.display_name)
		_log("%s归来，带回%s。伤势%d、感染%d；先检查再继续。" % [actor.display_name, ShelterInventory.describe(recovered), ceili(actor.injury), ceili(actor.infection)])
		if (actor.injury > 0 or actor.infection > 0) and inventory.amount("medicine") > 0:
			selected_task = "heal"
			context_open = true
	else:
		if actor.state != Survivor.TaskState.DEAD: scheduler.mark_dead(actor, "外出遭遇")
		_log("%s未能返回，背包与携带物资全部丢失。其余成员必须重新分工。" % actor.display_name)
	actor.route.clear()
	actor.work_elapsed = 0
	speed = expedition.return_speed
	paused = true
	select_survivor(id)
	queue_redraw()


func _sync_mode() -> void:
	var base := not expedition.active
	world_root.visible = base
	for node in base_hud_nodes: node.visible = base
	for node in context_nodes: node.visible = base and context_open
	completed_label.hide()
	log_label.visible = base and toast_time > 0
	for task_id in task_tabs:
		task_tabs[task_id].visible = base and context_open and TaskCatalog.TASKS[task_id]["facility"] == TaskCatalog.TASKS[selected_task]["facility"]
	for actor in survivors: actor.visible = base
	for station: Workstation in scheduler.facilities.values(): station.visible = base
	game_over_label.visible = base and game_over
	expedition_view.visible = not base
	expedition_view.layer.visible = not base
	if not base: expedition_view.refresh()
	main_title.text = "临时避难所  /  留一盏灯"
	subtitle.text = "点击人物选择 · 点击设施查看行动 · 右键地面移动 · 空格暂停"


func _style(background: Color, border: Color, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_top = 10
	style.content_margin_right = 18
	style.content_margin_bottom = 10
	return style


func _label(text: String, point: Vector2, size: Vector2, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.position = point
	label.size = size
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(label)
	return label


func _button(text: String, point: Vector2, size: Vector2, action: Callable, primary: bool = false, compact: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = point
	button.size = size
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 13 if compact else 16)
	button.add_theme_color_override("font_color", Color("1b2525") if primary else INK)
	button.add_theme_color_override("font_hover_color", Color("152020") if primary else Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("152020") if primary else GOLD)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(GOLD if primary else Color("192529"), GOLD if primary else Color("34413f")))
	button.add_theme_stylebox_override("hover", _style(GOLD.lightened(0.12) if primary else Color("253431"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(GOLD.darkened(0.12) if primary else Color("30413b"), GOLD))
	button.add_theme_stylebox_override("disabled", _style(Color("1e292a"), Color("2b3838")))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), GOLD))
	if compact:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box: StyleBoxFlat = button.get_theme_stylebox(state)
			box.content_margin_top = 4
			box.content_margin_bottom = 4
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Space and Tab belong to pause and survivor selection in this prototype.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	hud.add_child(button)
	button.size = size
	return button


func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	_label("留 一 盏 灯  /  LIVE FOREVER", Vector2(30, 20), Vector2(310, 32), 19, GOLD)
	clock_label = _label("", Vector2(350, 14), Vector2(550, 38), 25)
	phase_label = _label("", Vector2(350, 55), Vector2(560, 26), 14, GOLD)
	day_bar = ProgressBar.new()
	day_bar.position = Vector2(350, 88)
	day_bar.show_percentage = false
	day_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for state in ["background", "fill"]:
		var box := _style(Color("2b3838") if state == "background" else GOLD, Color("2b3838"), 2)
		box.set_content_margin_all(0)
		day_bar.add_theme_stylebox_override(state, box)
	hud.add_child(day_bar)
	day_bar.size = Vector2(560, 6)
	pause_button = _button("暂停  空格", Vector2(960, 18), Vector2(140, 38), toggle_pause)
	speed_button = _button("×1", Vector2(1110, 18), Vector2(90, 38), toggle_speed)
	_button("菜单  Esc", Vector2(1210, 18), Vector2(200, 38), open_center.bind(4))
	_button("街区 M", Vector2(960, 67), Vector2(140, 30), open_center.bind(0), false, true)
	_button("人物 P", Vector2(1110, 67), Vector2(90, 30), open_center.bind(5), false, true)
	_button("故事 N / 目标 O", Vector2(1210, 67), Vector2(200, 30), open_center.bind(7), false, true)
	save_label = _label("", Vector2(30, 62), Vector2(300, 28), 12, MUTED)
	save_label.mouse_filter = Control.MOUSE_FILTER_PASS
	stock_label = _label("", Vector2(30, 111), Vector2(1380, 28), 16, GOLD)
	var header_nodes := hud.get_child_count()
	main_title = _label("", Vector2(32, 155), Vector2(440, 30), 21)
	subtitle = _label("", Vector2(32, 188), Vector2(650, 25), 13, MUTED)
	upkeep_label = _label("", Vector2(530, 157), Vector2(690, 26), 14, MUTED)
	var depart := _button("出门搜刮 V →", Vector2(1220, 150), Vector2(190, 42), request_expedition, true)
	depart.tooltip_text = "派当前选中的人外出；其余人继续留守任务。"
	log_label = _label("", Vector2(32, 217), Vector2(1000, 35), 14, GOLD)
	log_label.clip_text = true
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_label = _label("", Vector2(32, 739), Vector2(1380, 28), 14, MUTED)
	tutorial_label.clip_text = true
	sync_roster_cards()
	var context_start := hud.get_child_count()
	var background := Panel.new()
	background.position = Vector2(1055, 228)
	background.size = Vector2(355, 494)
	background.add_theme_stylebox_override("panel", _style(Color("172321"), Color("697461"), 4))
	hud.add_child(background)
	selected_label = _label("", Vector2(1075, 241), Vector2(270, 36), 23)
	_button("×", Vector2(1360, 239), Vector2(36, 32), func(): context_open = false; _refresh_hud(), false, true)
	speciality_label = _label("", Vector2(1075, 282), Vector2(310, 24), 13, GREEN)
	detail_label = _label("", Vector2(1075, 314), Vector2(310, 48), 14, MUTED)
	var choices := [["repair", "修整", 1075, 375], ["craft", "制工具 C", 1229, 375], ["eat", "吃饭 G", 1075, 375], ["heal", "本人用药 R", 1229, 375], ["sleep", "休息 H", 1075, 375], ["cook", "做饭 F", 1075, 375]]
	for choice in choices:
		var tab := _button(choice[1], Vector2(choice[2], choice[3]), Vector2(145, 32), select_task.bind(choice[0]), false, true)
		task_tabs[choice[0]] = tab
	workbench_tab = task_tabs["repair"]
	stove_tab = task_tabs["cook"]
	task_heading = _label("", Vector2(1075, 422), Vector2(310, 28), 18, GOLD)
	facility_label = _label("", Vector2(1075, 455), Vector2(310, 24), 13, MUTED)
	recipe_label = _label("", Vector2(1075, 486), Vector2(310, 52), 14, MUTED)
	assign_button = _button("", Vector2(1075, 551), Vector2(315, 44), assign_selected, true)
	assign_button.add_theme_font_size_override("font_size", 15)
	cancel_button = _button("取消此人的任务 Q", Vector2(1075, 605), Vector2(315, 34), cancel_selected, false, true)
	status_label = _label("", Vector2(1075, 646), Vector2(315, 24), 13, GOLD)
	queue_label = _label("", Vector2(1075, 675), Vector2(315, 40), 12, MUTED)
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(1075, 717)
	progress_bar.show_percentage = false
	hud.add_child(progress_bar)
	progress_bar.size = Vector2(315, 5)
	completed_label = _label("", Vector2(1075, 725), Vector2(315, 20), 11, MUTED)
	completed_label.hide()
	for index in range(context_start, hud.get_child_count()): context_nodes.append(hud.get_child(index))
	game_over_label = _label("", Vector2(370, 310), Vector2(700, 85), 25, GOLD)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for index in range(header_nodes, hud.get_child_count()): base_hud_nodes.append(hud.get_child(index))
	load_dialog = _confirmation("读取存档", "读取最近的本地存档？\n当前尚未保存的进度会被替换，读取后保持暂停。")
	load_dialog.confirmed.connect(load_game)
	new_dialog = _confirmation("开始新的一局", "开始新的一局并替换主存档？\n当前未保存的进度会丢失，上一次有效主档保留为备份。")
	new_dialog.confirmed.connect(start_new_game)
	exit_dialog = _confirmation("存档未成功", "本次进度未能保存。仍要退出吗？\n取消可回到游戏，再尝试手动保存。")
	exit_dialog.confirmed.connect(_quit_cleanly)
	prep_dialog = _confirmation("准备外出", "")
	prep_dialog.min_size = Vector2i(690, 435)
	prep_dialog.get_label().hide()
	# AcceptDialog resizes its child controls. A single margin/container tree
	# must own layout; absolute offsets overlap the built-in message label.
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	prep_dialog.add_child(margin)
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	margin.add_child(options)
	prep_destination = OptionButton.new()
	for id in LocationCatalog.IDS:
		prep_destination.add_item(LocationCatalog.area(id)["name"])
	prep_destination.item_selected.connect(func(index: int): choose_destination(LocationCatalog.IDS[index]))
	options.add_child(prep_destination)
	prep_text = Label.new()
	prep_text.custom_minimum_size = Vector2(630, 155)
	prep_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	options.add_child(prep_text)
	prep_tool = CheckBox.new()
	prep_tool.text = "带1件工具：可破锁或击倒一次，用后消耗，占1格"
	options.add_child(prep_tool)
	prep_medicine = CheckBox.new()
	prep_medicine.text = "带1份药品：途中按R急救，占1格"
	options.add_child(prep_medicine)
	prep_dialog.confirmed.connect(func(): start_expedition(prep_tool.button_pressed, prep_medicine.button_pressed))


func _refresh_hud() -> void:
	if not is_instance_valid(hud):
		return
	var actor := survivors[selected_id]
	var definition: Dictionary = TaskCatalog.TASKS[selected_task]
	var target: Workstation = scheduler.facilities[definition["facility"]]
	upkeep_label.text = "结构 %d%% / 据点 %d级 / %s / %s" % [ceili(upkeep.integrity), upkeep.level, LocationCatalog.weather(ExpeditionState.day_at(simulation_time))["name"], "有待处理事件 M" if upkeep.pending_event >= 0 else "修整可恢复结构"]
	stock_label.text = "据点库存   生食%d / 水%d / 燃料%d / 熟食%d / 材料%d / 工具%d / 药品%d" % [inventory.amount("raw_food"), inventory.amount("water"), inventory.amount("fuel"), inventory.amount("meals"), inventory.amount("materials"), inventory.amount("tools"), inventory.amount("medicine")]
	selected_label.text = actor.display_name
	speciality_label.text = "%s / %s基础%.1f秒" % [actor.speciality, definition["label"], TaskCatalog.duration_for(selected_task, actor)]
	detail_label.text = "生命%d / 饱腹%d / 精神%d\n水分%d / 效率%d%%" % [Vitals.value(actor,"health"), Vitals.value(actor,"fullness"), Vitals.value(actor,"vigor"), Vitals.value(actor,"hydration"), int(actor.effort_factor()*100)]
	detail_label.tooltip_text = actor.description + "\n" + PeopleCatalog.DATA[actor.person.persona]["traits"] + "\n心境%d 压力%d 创伤%d 水分%d · 工艺%d 照护%d 探索%d" % [roundi(actor.person.morale), roundi(actor.person.stress), roundi(actor.person.trauma), Vitals.value(actor,"hydration"), actor.person.level("craft"), actor.person.level("care"), actor.person.level("scout")]
	detail_label.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_label.add_theme_color_override("font_color", Color("dca184") if actor.hunger >= 80 or actor.fatigue >= 85 or actor.health <= 30 or actor.infection >= 30 or actor.injury >= 50 or actor.person.thirst >= 80 else MUTED)
	status_label.text = actor.status_text()
	var queued_labels: Array[String] = []
	for order in actor.orders:
		queued_labels.append(TaskCatalog.label_for(order))
	queue_label.text = "任务队列  %d / 3（含当前）\n%s" % [actor.orders.size(), " → ".join(queued_labels) if not queued_labels.is_empty() else "暂无任务"]
	progress_bar.value = actor.progress() * 100
	completed_label.text = "此人完成 %d 项  /  队伍做饭 %d 锅" % [actor.completed_jobs, stove.completed_jobs]
	task_heading.text = "%s  /  %s" % [target.display_name, definition["label"]]
	facility_label.text = "空闲 · 可分配工作" if target.occupant_id == -1 else "%s正在使用 · 其他人排队" % survivors[target.occupant_id].display_name
	var has_materials := inventory.can_take(definition["cost"])
	match selected_task:
		"cook", "craft": recipe_label.text = "%s\n→ %s · 开工扣料 / 取消退料" % [ShelterInventory.describe(definition["cost"]), ShelterInventory.describe(definition["output"])]
		"eat": recipe_label.text = "熟食×1 · 饱腹+55，最高100\n中途取消退料，不恢复饱腹"
		"sleep": recipe_label.text = "休息20秒，每秒精神+3\n可中断，保留已获得的休息"
		"heal": recipe_label.text = "%s给自己用药 · 药品×1\n生命+25 / 伤势−50 / 感染−40" % actor.display_name
		_: recipe_label.text = "材料×1 → 完成后结构+18\n低于40%会降效；取消退料"
	if not has_materials:
		recipe_label.text = "现货不足，依赖前置任务产出\n开工仍会检查库存，不预留材料" if scheduler.can_plan_materials(actor, selected_task) else "缺料：%s\n任务不会加入队列" % inventory.missing_text(definition["cost"])
	recipe_label.add_theme_color_override("font_color", MUTED if has_materials else Color("dca184"))
	assign_button.text = "让%s接受治疗 [E]" % actor.display_name if selected_task == "heal" else "让%s%s [E]" % [actor.display_name, definition["label"]]
	assign_button.tooltip_text = "治疗对象：%s本人。去餐桌自行用药；不治疗其他人。若要医护帮助同伴，按P选择医护和受助者。" % actor.display_name if selected_task == "heal" else "为%s追加此项行动。走到设施后开工扣料；手动取消退料。最多三项。" % actor.display_name
	# Keep the button usable when short of stock so it can explain rejection;
	# the scheduler remains the authority for both mouse and keyboard orders.
	assign_button.disabled = actor.orders.size() >= TaskScheduler.MAX_ORDERS or actor.state == Survivor.TaskState.BLOCKED or actor.health <= 0 or game_over
	for task in task_tabs:
		task_tabs[task].add_theme_color_override("font_color", GOLD if selected_task == task else MUTED)
	cancel_button.disabled = actor.orders.is_empty()
	pause_button.text = "继续  /  空格" if paused else "暂停  /  空格"
	pause_button.disabled = game_over
	speed_button.text = "速度 ×%d" % int(speed)
	speed_button.disabled = expedition.active
	clock_label.text = SurvivalRules.clock_text(simulation_time) + (" · 已暂停" if paused else "")
	var minute := fposmod(480 + simulation_time * SurvivalRules.MINUTES_PER_SECOND, 1440)
	var boundary := 360.0 if minute < 360 else 1080.0 if minute < 1080 else 1800.0
	var remaining := (boundary - minute) / SurvivalRules.MINUTES_PER_SECOND / speed
	phase_label.text = "%s %02d:%02d · %s" % ["距日出" if SurvivalRules.is_night(simulation_time) else "距天黑", int(ceil(remaining)) / 60, int(ceil(remaining)) % 60, "暂停中，时间停止" if paused else "现实时间 / 当前×%d" % int(speed)]
	day_bar.value = minute / 1440.0 * 100
	day_bar.tooltip_text = "全天进度：06:00日出，18:00天黑。1倍速下现实1秒=游戏2分钟；清晨结算补给与损耗。"
	day_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	save_label.text = _save_status
	save_label.tooltip_text = _save_status + "\n" + ProjectSettings.globalize_path(save_store.path)
	game_over_label.visible = game_over
	game_over_label.text = "庇护所失守\n所有幸存者已死亡。可读档或新开一局。" if game_over else ""
	for index in range(cards.size()):
		var person := survivors[index]
		if cards[index] is SurvivorCard: continue
		cards[index].text = "%d  %s · %s\n生命%d 饱腹%d 精神%d 水分%d\n%s" % [index+1,person.display_name,person.speciality,Vitals.value(person,"health"),Vitals.value(person,"fullness"),Vitals.value(person,"vigor"),Vitals.value(person,"hydration"),person.status_text()]
		cards[index].tooltip_text = "伤势%d / 感染%d / 心境%d / 压力%d\n点击选中；P查看人物、照料授权与医疗援助。" % [ceili(person.injury), ceili(person.infection), roundi(person.person.morale), roundi(person.person.stress)]
		cards[index].add_theme_color_override("font_color", Color("dca184") if person.health <= 30 or person.hunger >= 80 or person.fatigue >= 85 or person.infection >= 30 or person.person.thirst >= 80 else INK)
		cards[index].add_theme_stylebox_override("normal", _style(Color("27332e") if index == selected_id else Color("142125"), GOLD if index == selected_id else Color("2d3c3b")))
	tutorial_label.text = story.hint(self)
	if story.guide_index() < 0 and story.pending.is_empty(): tutorial_label.text = goals.hint()
	tutorial_label.tooltip_text = StoryCatalog.GUIDE_HINTS[story.guide_index()] if story.guide_index() >= 0 else "六项新手目标已完成；按N重看操作和同伴故事。"
	_sync_mode()


func _draw() -> void:
	# The entire shelter is original procedural placeholder art. Coordinates
	# match the explicit navigation graph, so walls and paths stay consistent.
	draw_rect(Rect2(0, 0, 1440, 900), Color("101a1e"))
	if expedition.active:
		return
	draw_set_transform(world_offset(), 0, world_scale())
	draw_rect(Rect2(0, 200, 1095, 490), Color("142126"))
	_draw_city()
	for i in range(65):
		var rain_x := fposmod(i * 137.0 - weather_time * 37, 1040)
		var rain_y := 223 + fposmod(i * 79.0 + weather_time * 170, 470)
		draw_line(Vector2(rain_x, rain_y), Vector2(rain_x - 4, rain_y + 13), Color(0.65, 0.76, 0.75, 0.07), 1)
	# Building shell and two clearly separated floor slabs.
	draw_colored_polygon(PackedVector2Array([Vector2(93, 287), Vector2(154, 259), Vector2(943, 267), Vector2(1006, 287)]), Color("313d3c"))
	draw_rect(Rect2(100, 286, 900, 365), Color("242d2d"))
	draw_rect(Rect2(113, 300, 874, 127), Color("2e3632"))
	draw_rect(Rect2(113, 445, 874, 193), Color("242e2c"))
	# A separate stair bay creates an honest route across the floors.
	draw_rect(Rect2(660, 300, 199, 340), Color("202a2a"))
	for row in range(9):
		for col in range(27):
			var bx := 119 + col * 32 + (16 if row % 2 else 0)
			var by := 312 + row * 33
			if bx < 976:
				draw_line(Vector2(bx, by), Vector2(bx + 28, by), Color(0.6, 0.65, 0.57, 0.027), 1)
	_draw_window(Vector2(165, 328), Vector2(84, 71))
	_draw_window(Vector2(457, 322), Vector2(100, 72))
	_draw_window(Vector2(893, 326), Vector2(57, 70))
	# Beds and a small improvised living space upstairs.
	for bed_x in [285]:
		draw_rect(Rect2(bed_x, 404, 127, 14), Color("535c51"))
		draw_rect(Rect2(bed_x + 5, 398, 117, 10), Color("87917a"))
		draw_rect(Rect2(bed_x + 9, 397, 25, 8), Color("a4aa92"))
		draw_line(Vector2(bed_x + 7, 418), Vector2(bed_x + 7, 429), Color("626d61"), 4)
		draw_line(Vector2(bed_x + 117, 418), Vector2(bed_x + 117, 429), Color("626d61"), 4)
	for step_index in range(14):
		var t := step_index / 14.0
		var edge := ShelterNavigation.TOP_STAIR.lerp(ShelterNavigation.BOTTOM_STAIR, t)
		draw_line(edge + Vector2(-17, 0), edge + Vector2(16, 0), Color("6d7568"), 4, true)
	draw_line(Vector2(674, 409), Vector2(793, 620), Color("7b8475"), 2, true)
	draw_line(Vector2(674, 409), Vector2(674, 429), Color("7b8475"), 2)
	draw_line(Vector2(793, 620), Vector2(793, 640), Color("7b8475"), 2)
	# Shelves and crates on the work floor.
	for shelf_y in [512, 545, 578, 611]:
		draw_rect(Rect2(884, shelf_y, 74, 4), Color("667061"))
	draw_rect(Rect2(883, 499, 4, 139), Color("626d61"))
	draw_rect(Rect2(956, 499, 4, 139), Color("626d61"))
	for i in range(8):
		var shelf_x := 892 + (i % 3) * 21
		var shelf_y := 520 + (i / 3) * 33
		draw_rect(Rect2(shelf_x, shelf_y, 15, 24), Color("656f59") if i % 2 else Color("817455"))
	for x in [315, 352]:
		draw_rect(Rect2(x, 606, 33, 32), Color("5c5543"))
		draw_rect(Rect2(x + 3, 609, 27, 26), Color("76674c"), false, 2)
		draw_line(Vector2(x + 5, 611), Vector2(x + 28, 633), Color("524d3e"), 2)
	# Floor break leaves the stair opening unobstructed.
	draw_rect(Rect2(100, 430, 582, 15), Color("414c43"))
	draw_rect(Rect2(716, 430, 284, 15), Color("414c43"))
	draw_rect(Rect2(98, 640, 904, 15), Color("4b5147"))
	draw_rect(Rect2(97, 285, 14, 371), Color("424943"))
	draw_rect(Rect2(986, 285, 14, 371), Color("424943"))
	draw_rect(Rect2(110, 654, 880, 7), Color("111a1b"))
	# Warm overhead light and discreet interface panels.
	for r in range(90, 10, -10):
		draw_circle(Vector2(392, 329), r, Color(0.85, 0.65, 0.34, 0.007))
	draw_line(Vector2(392, 300), Vector2(392, 321), Color("7f805e"), 2)
	draw_rect(Rect2(383, 320, 18, 5), Color("e1c38d"))
	if SurvivalRules.is_night(simulation_time):
		draw_rect(Rect2(0, 255, 1070, 430), Color(0, 0.02, 0.05, 0.18))
	_draw_house_details()
	if move_marker_time > 0:
		draw_arc(move_marker + Vector2(0, -3), 16 + (1 - move_marker_time) * 10, 0, TAU, 24, Color(0.85, 0.73, 0.52, move_marker_time), 2, true)
	draw_set_transform(Vector2.ZERO)
	_draw_chrome()


func _draw_chrome() -> void:
	draw_rect(Rect2(0, 0, 1440, 143), Color("101a1e"))
	draw_line(Vector2(30, 143), Vector2(1410, 143), Color("425047"), 1)
	draw_rect(Rect2(0, 772, 1440, 128), Color("101a1e"))
	# Dawn and dusk ticks on the same 24-hour timeline as the model clock.
	for minute in [360, 720, 1080]:
		var x: float = 350.0 + 560.0 * minute / 1440.0
		draw_line(Vector2(x, 86), Vector2(x, 97), GOLD, 1)
	if paused:
		draw_style_box(_style(Color("25322d"), GOLD), Rect2(580, 262, 280, 42))
		draw_string(FONT, Vector2(605, 289), "已暂停 · 空格继续", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, GOLD)
	if game_over:
		draw_style_box(_style(Color("182724"), GOLD, 6), Rect2(350, 305, 740, 100))


func _draw_house_details() -> void:
	# Context comes from physical rooms and props; no permanent task dashboard.
	for x in [118, 433, 865]:
		draw_line(Vector2(x, 300), Vector2(x, 424), Color("434c43"), 4)
	for x in range(124, 984, 29):
		draw_line(Vector2(x, 640), Vector2(x + 16, 632), Color("53564a"), 1)
	# Water store, coats, a broken radio and electrical wiring.
	for x in [239, 261]:
		draw_line(Vector2(x, 339), Vector2(x, 354), Color("a39271"), 2)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 8, 354), Vector2(x + 8, 354), Vector2(x + 14, 390), Vector2(x - 12, 390)]), Color("536558"))
	draw_polyline(PackedVector2Array([Vector2(117, 306), Vector2(390, 306), Vector2(390, 317), Vector2(865, 308), Vector2(865, 475)]), Color("1b2221"), 2)
	draw_rect(Rect2(881, 489, 42, 10), Color("6f725a"))
	draw_circle(Vector2(912, 494), 3, GOLD)
	draw_line(Vector2(884, 489), Vector2(875, 467), Color("929878"), 2)
	# A visible first-aid box shares the table used by the actual treatment rule.
	draw_rect(Rect2(584, 396, 20, 21), Color("879781"))
	draw_line(Vector2(589, 406), Vector2(599, 406), Color("d8ded7"), 3)
	draw_line(Vector2(594, 401), Vector2(594, 411), Color("d8ded7"), 3)
	var light := 0.32 if SurvivalRules.is_night(simulation_time) else 0.12
	for radius in range(76, 12, -8):
		draw_circle(Vector2(392, 345), radius, Color(0.95, 0.72, 0.37, light / 12))


func _draw_city() -> void:
	for i in range(19):
		var height := 80 + fposmod(i * 67, 170)
		var x := i * 61 - 20
		draw_rect(Rect2(x, 570 - height, 53, height), Color("1b2a2e"))
		for level in range(3):
			draw_rect(Rect2(x + 13, 590 - height + level * 25, 6, 11), Color(0.46, 0.55, 0.52, 0.07))
	draw_line(Vector2(0, 685), Vector2(1070, 685), Color("233532"), 2)


func _draw_window(point: Vector2, size: Vector2) -> void:
	draw_rect(Rect2(point - Vector2(4, 4), size + Vector2(8, 8)), Color("59615a"))
	draw_rect(Rect2(point, size), Color("1d3038"))
	draw_line(point + Vector2(size.x / 2, 0), point + Vector2(size.x / 2, size.y), Color("64716a"), 3)
	draw_line(point + Vector2(0, size.y / 2), point + Vector2(size.x, size.y / 2), Color("64716a"), 3)
	draw_line(point + Vector2(3, size.y - 10), point + Vector2(size.x - 3, size.y - 30), Color("645e4c"), 7)


func _quit_cleanly() -> void:
	if _quitting: return
	_quitting = true
	paused = true
	game_audio.stop_audio()
	_exit_note("audio stopped")
	# Mixer cleanup runs on its own clock; uncapped render frames can finish
	# before even one audio buffer. Allow it to release stopped playback.
	await get_tree().create_timer(0.12).timeout
	_exit_note("quit requested after mixer grace")
	get_tree().quit()


func _exit_note(message: String) -> void:
	if OS.get_cmdline_user_args().has("--trace-exit"): printerr("EXIT TRACE: " + message)


func _exit_tree() -> void:
	_exit_note("scene leaving tree")


func add_survivor(persona: String) -> Survivor:
	var definition: Dictionary = PeopleCatalog.DATA[persona]
	var actor := Survivor.new()
	actor.survivor_id = survivors.size()
	actor.person.persona = persona
	actor.display_name = definition["name"]
	actor.speciality = definition["role"]
	actor.description = definition["bio"]
	actor.tint = Color(str(definition["tint"]))
	actor.position = Vector2(180 + actor.survivor_id * 28, ShelterNavigation.LOWER_Y)
	actor.work_duration = TaskCatalog.duration_for("repair", actor)
	actor.repair_duration = actor.work_duration
	actor.clicked.connect(func(member: Survivor): select_survivor(member.survivor_id))
	world_root.add_child(actor)
	survivors.append(actor)
	return actor


func ensure_roster(identities: Array) -> void:
	while survivors.size() > identities.size():
		var actor: Survivor = survivors.pop_back()
		actor.free()
	for index in range(identities.size()):
		if index < survivors.size() and survivors[index].person.persona != identities[index]:
			while survivors.size() > index:
				var removed: Survivor = survivors.pop_back()
				removed.free()
		if index >= survivors.size(): add_survivor(identities[index])
	selected_id = mini(selected_id, survivors.size() - 1)
	scheduler.survivors = survivors
	sync_roster_cards()


func sync_roster_cards() -> void:
	if not is_instance_valid(hud): return
	for card in cards:
		base_hud_nodes.erase(card)
		card.free()
	cards.clear()
	var count := survivors.size()
	var stride := 1380.0 / count
	for index in range(count):
		var card: Button
		if has_method("_compact_card"):
			card = call("_compact_card",index)
		else: card = _button("", Vector2(30 + index * stride, 782), Vector2(stride - 10, 94), select_survivor.bind(index))
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.clip_text = true
		card.add_theme_font_size_override("font_size", 15 if count <= 3 else 12)
		cards.append(card)
		if not base_hud_nodes.is_empty(): base_hud_nodes.append(card)
