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
		game.residence_view.toggle()
		record(game.residence_view.opened and design.encloses(game.residence_view.window.get_global_rect()) and game.paused, "home and relocation drawer fits at %dx%d" % [size.x,size.y])
		game.residence_view.close()
		game.briefing.toggle()
		record(game.briefing.opened and game.paused and design.encloses(game.briefing.window.get_global_rect()) and game.briefing.offer_buttons.values().all(func(button): return design.encloses(button.get_global_rect())), "opportunity briefing fits at %dx%d" % [size.x,size.y])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("briefing_%dx%d.png" % [size.x,size.y]))
		game.briefing.close()
		game.interface.toggle_workshop()
		record(game.interface.workshop_open and design.encloses(game.interface.workshop_panel.get_global_rect()) and game.paused, "equipment workshop fits and explicitly pauses at %dx%d" % [size.x, size.y])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("workshop_%dx%d.png" % [size.x, size.y]))
		game.interface.close_workshop()
		game.open_station("heal")
		record(design.encloses(game.assign_button.get_global_rect()) and game.assign_button.text.contains(game.survivors[game.selected_id].display_name), "named treatment confirmation fits at %dx%d" % [size.x, size.y])
		game.context_open = false
		game._refresh_hud()
		game.end_day()
		for frame in range(3): await get_tree().process_frame
		game.interface._page_maps(1)
		record(game.interface.map_buttons.has("waterworks") and game.interface.map_buttons["waterworks"].disabled, "additional maps and campaign gates appear at %dx%d" % [size.x, size.y])
		game.interface._page_maps(-1)
		record(game.cycle.phase == "planning" and design.encloses(game.interface.depart_button.get_global_rect()) and game.interface.role_options.size() == 3, "night assignment fits and names all roles at %dx%d" % [size.x, size.y])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("night_%dx%d.png" % [size.x, size.y]))
		record(SaveSystem.apply_state(game, initial_campaign).is_empty(), "preflight restores untouched campaign at %dx%d" % [size.x, size.y])
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
