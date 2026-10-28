extends Node
## Runs only in the separate acceptance executable. No test code is embedded in the normal game.

const Pilot := preload("res://tests/realtime_pilot.gd")
@onready var root: Window = get_tree().root
var game: Node2D
var pilot := Pilot.new()
var output := ""
var minutes := 30.0
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var frames := 0
var worst_frame := 0.0
var started := 0
var sample_time := 0.0
var running := false
var report: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func record(ok: bool, message: String) -> void:
	checks.append({"passed": ok, "message": message})
	print(("DESKTOP PASS: " if ok else "DESKTOP FAIL: ") + message)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size() - 1):
		if args[index] == "--output": output = args[index + 1]
		if args[index] == "--minutes": minutes = clampf(float(args[index + 1]), 0.1, 120)
	if output.is_empty():
		printerr("Provide -- --output <fresh-test-folder> [--minutes 30]")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	if FileAccess.file_exists(output.path_join("session.json")):
		printerr("Refusing to overwrite an existing acceptance session")
		get_tree().quit(2)
		return
	report = {"platform": OS.get_name(), "engine": Engine.get_version_info()["string"], "requested_minutes": minutes, "status": "preflight", "checks": [], "resolutions": [], "screens": DisplayServer.get_screen_count()}
	game = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	game.save_store.path = output.path_join("session.json")
	root.add_child(game)
	game.set_process(false)
	await get_tree().process_frame
	var initial_campaign := SaveSystem.capture(game)
	var available := DisplayServer.screen_get_size()
	for size in [Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		if size.x > available.x or size.y > available.y:
			report["resolutions"].append({"requested": [size.x, size.y], "status": "skipped", "reason": "larger than attached screen"})
			continue
		root.size = size
		root.position = Vector2i.ZERO
		for frame in range(12): await get_tree().process_frame
		var actual := root.size
		record(actual == size, "actual native window size %dx%d" % [size.x, size.y])
		record(root.get_visible_rect().size.is_equal_approx(Vector2(1440, 900)), "fixed design viewport and preserved aspect at %dx%d" % [size.x, size.y])
		game._refresh_hud()
		record(game.clock_label.visible and game.day_bar.visible and game.phase_label.text.contains("20:00"), "day clock and dusk progress are visible at %dx%d" % [size.x, size.y])
		var design := Rect2(Vector2.ZERO, Vector2(1440, 900))
		record(game.cards.all(func(card): return design.encloses(card.get_global_rect())), "complete roster cards fit at %dx%d" % [size.x, size.y])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("shelter_%dx%d.png" % [size.x, size.y]))
		for page in ["starts","people","cooperate"]:
			game.chronicle_view.show_page(page)
			record(game.paused and game.chronicle_view.opened and design.encloses(game.chronicle_view.window.get_global_rect()),"new scenario / personal history page fits at %dx%d: %s" % [size.x,size.y,page])
			game.chronicle_view.close()
		game.district_view.toggle()
		record(game.district_view.opened and game.paused and design.encloses(game.district_view.window.get_global_rect()) and game.district_view.map_buttons.size() == 9,"spatial district chart fits and pauses at %dx%d" % [size.x,size.y])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("district_%dx%d.png" % [size.x,size.y]))
		game.district_view.close()
		game.residence_view.toggle()
		record(game.residence_view.opened and design.encloses(game.residence_view.window.get_global_rect()) and game.paused, "home and relocation drawer fits at %dx%d" % [size.x,size.y])
		game.residence_view.close()
		game.briefing.toggle()
		record(game.briefing.opened and game.paused and design.encloses(game.briefing.window.get_global_rect()) and game.briefing.offer_buttons.values().all(func(button): return design.encloses(button.get_global_rect())), "opportunity briefing fits at %dx%d" % [size.x,size.y])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("briefing_%dx%d.png" % [size.x,size.y]))
		game.briefing.close()
		game.security_view.toggle()
		record(game.security_view.opened and game.paused and design.encloses(game.security_view.window.get_global_rect()), "security inspection fits and pauses at %dx%d" % [size.x,size.y])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("security_%dx%d.png" % [size.x,size.y]))
		game.security_view.close()
		game.interface.toggle_workshop()
		record(game.interface.workshop_open and design.encloses(game.interface.workshop_panel.get_global_rect()) and game.paused, "equipment workshop fits and explicitly pauses at %dx%d" % [size.x, size.y])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("workshop_%dx%d.png" % [size.x, size.y]))
		game.interface.close_workshop()
		game.open_center(5)
		for frame in range(3): await get_tree().process_frame
		var people_rect := Rect2(Vector2.ZERO,Vector2(game.center.size))
		record(game.center.routine_toggle.button_pressed and not game.center.cooking_toggle.button_pressed and people_rect.encloses(game.center.routine_toggle.get_global_rect()) and people_rect.encloses(game.center.cooking_toggle.get_global_rect()),"basic self-care and separate cooking policy fit at %dx%d" % [size.x,size.y])
		game.center.close()
		game.survivors[0].person.thirst = 85
		game.paused = false;game.advance_simulation(.1)
		record(game.survivors[0].self_care_kind == "drink" and game.survivors[0].route.size()>1 and game.inventory.amount("water")==int(initial_campaign["stock"]["water"]),"autonomous water use begins with actual travel at %dx%d" % [size.x,size.y])
		var care_save_path: String = game.save_store.path
		game.save_store.path = output.path_join("care_preflight_%dx%d.json" % [size.x,size.y])
		var care_saved: bool = game.save_store.write_state(game)["ok"]
		var care_loaded: bool = game.load_game()
		game.save_store.path = care_save_path
		record(care_saved and care_loaded and game.paused and game.survivors[0].self_care_kind == "drink" and game.inventory.amount("water")==int(initial_campaign["stock"]["water"]),"unfinished autonomous travel restores without duplicate payment at %dx%d" % [size.x,size.y])
		game.paused = false;game.advance_simulation(22)
		var drank_once: bool = game.people.drinks == 1 and game.inventory.amount("water") == int(initial_campaign["stock"]["water"])-1 and game.survivors[0].person.thirst < 30 and SaveSystem.validate(SaveSystem.capture(game)).is_empty()
		var care_restored: bool = SaveSystem.apply_state(game,initial_campaign).is_empty()
		record(drank_once and care_restored,"physical self-care consumes one water and cleanly restores the test fixture at %dx%d" % [size.x,size.y])
		game.open_station("heal")
		record(design.encloses(game.assign_button.get_global_rect()) and game.assign_button.text.contains(game.survivors[game.selected_id].display_name), "named treatment confirmation fits at %dx%d" % [size.x, size.y])
		game.context_open = false
		game._refresh_hud()
		game.end_day()
		for frame in range(3): await get_tree().process_frame
		game.interface._page_maps(1)
		record(game.interface.map_buttons.has("waterworks") and game.interface.map_buttons["waterworks"].disabled, "additional maps and campaign gates appear at %dx%d" % [size.x, size.y])
		game.interface._page_maps(-1)
		record(game.interface.role_options[0].item_count == 6 and game.interface.role_options[0].is_item_disabled(5),"outpost duty is visible and gated until actual construction at %dx%d" % [size.x,size.y])
		record(game.cycle.phase == "planning" and design.encloses(game.interface.depart_button.get_global_rect()) and game.interface.role_options.size() == 3, "night assignment fits and names all roles at %dx%d" % [size.x, size.y])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("night_%dx%d.png" % [size.x, size.y]))
		game.start_expedition()
		game.paused = true
		var field: ExpeditionState = game.expedition
		field.player_x = 300
		field._search(10,game.survivors[field.actor_id])
		game._process(0)
		game.interface._take_all()
		record(game._loot_open and field.bag["raw_food"] == 2 and field.bag["water"] == 1 and field.used_capacity() == 3,"actual units are grouped into stacks at %dx%d" % [size.x,size.y])
		record(design.encloses(game.interface.cargo_grid.get_global_rect()) and design.encloses(game.interface.container_grid.get_global_rect()),"both physical stack grids fit at %dx%d" % [size.x,size.y])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("stacks_%dx%d.png" % [size.x,size.y]))
		game.close_loot(); game.expedition_view.toggle_bag(); game._process(0)
		record(game.expedition_view.stack_panel.visible and design.encloses(game.expedition_view.stack_panel.get_global_rect()),"field stack drawer fits at %dx%d" % [size.x,size.y])
		game.expedition_view.toggle_bag()
		# Declared clearance fixture; timed action, UI and snapshot APIs are real.
		field.player_x = field.route_x();field.bag["tools"] = 1
		field._clear_route(.5);game._process(0)
		record(field.route_progress == .5 and field.bag["tools"] == 1 and game.expedition_view.search_bar.visible,"timed map clearance is visible before payment at %dx%d" % [size.x,size.y])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("map_route_%dx%d.png" % [size.x,size.y]))
		field._clear_route(2.5)
		record(field.route_open and field.bag["tools"] == 0 and game._route_controls(field.route_x(),1,false).get("climb") == 1,"cleared access consumes one tool and enters real routing at %dx%d" % [size.x,size.y])
		var route_snapshot := SaveSystem.capture(game)
		record(SaveSystem.apply_state(game,route_snapshot).is_empty() and game.expedition.route_open,"opened map access survives actual restore at %dx%d" % [size.x,size.y])
		# Explicit field-work fixture. The separate two-night journey uses no grants.
		game.paused = false
		field.player_x = 1620;field.floor_level = 1;field.player_y = 400
		field.bag["materials"] = 6;field.bag["tools"] = 1;field.bag["fuel"] = 1
		for e in field.enemies: e["hp"] = 0;e["mode"] = "dead"
		field._search(10,game.survivors[field.actor_id]);game._process(0)
		var work_started: bool = game.districts.begin_work(game,"build")
		game.districts.tick_work(game,.5,{});game._process(0)
		var timed: bool = game.expedition_view.search_bar.visible and field.bag["materials"] == 6
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("outpost_%dx%d.png" % [size.x,size.y]))
		game.districts.tick_work(game,9,{})
		record(work_started and timed and game.districts.regions["street"]["built"] and field.bag["materials"] == 1 and field.bag["tools"] == 0,"field outpost work shows progress and pays only on completion at %dx%d" % [size.x,size.y])
		game.expedition_decoy();field.noise = 0
		var observer: Dictionary = field.enemies[2]
		observer["hp"] = 40;observer["mode"] = "patrol";observer["x"] = 1970;observer["direction"] = 1.0
		field._tick_enemy(observer,game.survivors[field.actor_id],.1)
		var heard: bool = field.decoys.size() == 1 and observer["target"] == field.decoys[0]["x"] and field.bag["materials"] == 0 and field.bag["fuel"] == 0
		var district_snapshot := SaveSystem.capture(game)
		record(heard and SaveSystem.apply_state(game,district_snapshot).is_empty() and game.expedition.decoys.size() == 1,"paid lure, separate enemy target and district state restore at %dx%d" % [size.x,size.y])
		record(SaveSystem.apply_state(game, initial_campaign).is_empty(), "preflight restores untouched campaign at %dx%d" % [size.x, size.y])
		await neighborhood_preflight(design,size,initial_campaign)
		game.center.open(7)
		for frame in range(3): await get_tree().process_frame
		var bounds := Rect2(Vector2(game.center.position), Vector2(game.center.size))
		record(Rect2(Vector2.ZERO, Vector2(1440, 900)).encloses(bounds), "handbook fits complete logical viewport at %dx%d" % [size.x, size.y])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("resolution_%dx%d.png" % [size.x, size.y]))
		game.center.close()
		report["resolutions"].append({"requested": [size.x, size.y], "actual": [actual.x, actual.y], "status": "checked"})
	game.center._set_fullscreen(true)
	for frame in range(15): await get_tree().process_frame
	record(DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN], "actual fullscreen mode enabled")
	game.center._set_fullscreen(false)
	for frame in range(15): await get_tree().process_frame
	record(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "actual fullscreen returns to a movable window")
	root.size = Vector2i(mini(1440, available.x), mini(900, available.y))
	pilot.setup(game)
	game.persistence_enabled = true
	started = Time.get_ticks_msec()
	running = true
	report["status"] = "running"
	write_report()


func _process(delta: float) -> void:
	if not running: return
	frames += 1
	worst_frame = maxf(worst_frame, delta)
	pilot.tick(minf(delta, 0.1))
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	if elapsed >= sample_time:
		sample_time = elapsed + 10
		samples.append({"wall_seconds": elapsed, "simulation_seconds": game.simulation_time, "frames": frames, "trips": pilot.trips, "alive": game.survivors.filter(func(a): return a.health > 0).size(), "stock": game.inventory.snapshot(), "fps": Performance.get_monitor(Performance.TIME_FPS), "static_memory": Performance.get_monitor(Performance.MEMORY_STATIC)})
		write_report()
	if elapsed >= minutes * 60 or game.game_over:
		running = false
		record(not game.game_over and game.survivors.filter(func(a): return a.health > 0).size() == 3, "three original members survive continuous actual gameplay")
		record(game.simulation_time >= elapsed * 0.5, "continuous test advances real gameplay time rather than leaving a paused window")
		record(pilot.trips > 0, "actual continuous searching and physical return completed")
		record(SaveSystem.validate(SaveSystem.capture(game)).is_empty() and game.save_game(true), "continuous session saves a fully valid world")
		game.paused = true
		report["status"] = "ready_to_close" if checks.all(func(entry): return entry["passed"]) else "failed"
		report["elapsed_seconds"] = elapsed
		report["frames"] = frames
		report["worst_frame_seconds"] = worst_frame
		report["save_path"] = game.save_store.path
		report["stock"] = game.inventory.snapshot()
		write_report()
	return


func write_report() -> void:
	report["checks"] = checks.duplicate(true)
	report["samples"] = samples.duplicate(true)
	var file := FileAccess.open(output.path_join("desktop-report.json.tmp"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	DirAccess.rename_absolute(output.path_join("desktop-report.json.tmp"), output.path_join("desktop-report.json"))


func neighborhood_preflight(design: Rect2,size: Vector2i,initial: Dictionary) -> void:
	# Deliberate isolated display fixture; the separate campaign journeys use no grants.
	game.simulation_time=3600
	game.inventory.deposit({"materials":12,"tools":3,"fuel":4},"acceptance display fixture")
	game.end_day();game.choose_destination("clinic");game.cycle.roles.assign(["guard","bed","scavenge"])
	game.cycle.loadout={"materials":4,"tools":1,"fuel":2};game.start_expedition()
	var field: ExpeditionState=game.expedition
	for e in field.enemies:e["hp"]=0;e["mode"]="dead"
	field.player_x=NeighborhoodSystem.point("generator").x
	game.neighborhood_view.open_at("generator")
	record(game.neighborhood_view.opened and game.paused and design.encloses(game.neighborhood_view.window.get_global_rect()),"physical clinic context fits at %dx%d" % [size.x,size.y])
	var original: Dictionary=game.neighborhood.snapshot()
	game.neighborhood_view.choose("strip_cold")
	record(game.neighborhood.snapshot()==original and game.neighborhood_view.opened,"demolition requires review without changing the world at %dx%d" % [size.x,size.y])
	game.neighborhood_view.close();game.neighborhood_view.open_at("generator");game.neighborhood_view.choose("restore_cold")
	game.advance_simulation(2)
	record(not game.neighborhood.work.is_empty() and game.neighborhood.clinic["mode"]=="sealed" and field.bag["materials"]==4,"on-site project shows unpaid progress at %dx%d" % [size.x,size.y])
	var path: String=game.save_store.path
	game.save_store.path=output.path_join("neighborhood_preflight_%dx%d.json" % [size.x,size.y])
	var wrote: bool=game.save_store.write_state(game)["ok"]
	var loaded: bool=game.load_game();game.save_store.path=path
	record(wrote and loaded and game.paused and not game.neighborhood.work.is_empty(),"unfinished field project restores paused at %dx%d" % [size.x,size.y])
	game.paused=false;game.advance_simulation(13)
	record(game.neighborhood.clinic["mode"]=="running" and game.neighborhood.clinic["fuel"]==2 and field.bag["materials"]==0 and field.bag["tools"]==0,"continued field project pays once and changes actual device at %dx%d" % [size.x,size.y])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("clinic_project_%dx%d.png" % [size.x,size.y]))
	SaveSystem.apply_state(game,initial)
	game.simulation_time=3600;game.expansion.stage=2;game.expansion.collected.assign(["relay"]);game.expansion.warm_nights=2
	game.inventory.deposit({"materials":10,"tools":2},"acceptance display fixture")
	game.end_day();game.choose_destination("waterworks");game.cycle.roles.assign(["guard","bed","scavenge"]);game.cycle.loadout={"materials":9,"tools":2};game.start_expedition()
	field=game.expedition
	for e in field.enemies:e["hp"]=0;e["mode"]="dead"
	field.player_x=NeighborhoodSystem.point("pump").x;game.neighborhood.start(game,"restore_water");game.advance_simulation(15)
	field.player_x=NeighborhoodSystem.point("valve").x;field.floor_level=1;field.player_y=400
	game.neighborhood.start(game,"connect");game.advance_simulation(11);game.neighborhood_view.open_at("valve")
	record(game.neighborhood_view.opened and game.neighborhood_view.actions.size()==5 and design.encloses(game.neighborhood_view.window.get_global_rect()),"largest water diversion card fits at %dx%d" % [size.x,size.y])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("water_choices_%dx%d.png" % [size.x,size.y]))
	game.neighborhood_view.choose("route_home");game.advance_simulation(3)
	record(game.neighborhood.water["target"]=="home" and SaveSystem.validate(SaveSystem.capture(game)).is_empty() and SaveSystem.apply_state(game,initial).is_empty(),"paid plant and completed route preserve saves and reset fixture at %dx%d" % [size.x,size.y])
