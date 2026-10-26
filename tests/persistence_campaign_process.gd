extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(2); return
	var phase := args[0]
	var path := args[1]
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.save_store.path = path
	var ok := true
	if phase == "write":
		game.place_build("bed", 0)
		for index in range(55 * 30): game.advance_simulation(1.0 / 30)
		game.end_day()
		game.cycle.loadout = {"medicine": 1}
		ok = game.start_expedition()
		game.expedition.player_x = 300
		game.expedition._search(8, game.survivors[game.selected_id])
		game.expedition.take_loot("raw_food", 1, game.survivors[game.selected_id])
		game.paused = true
		game.persistence_enabled = true
		ok = ok and game.save_game() and game.cycle.bed_count() == 2
	elif phase == "read":
		game.persistence_enabled = true
		ok = game.load_game() and game.cycle.phase == "scavenge" and game.expedition.loot_site == 0 and game.expedition.bag["raw_food"] == 1 and game.cycle.bed_count() == 2 and game.paused
		if ok:
			game.close_loot()
			game.expedition.player_x = 110
			game.paused = false
			game.expedition_retreat()
			game.confirm_departure()
			ok = game.cycle.phase == "dawn" and game.inventory.amount("raw_food") == 5 and game.cycle.last_resolved_day == 1 and game.save_game()
	elif phase == "verify":
		game.persistence_enabled = true
		ok = game.load_game() and game.cycle.phase == "dawn" and game.inventory.amount("raw_food") == 5 and game.inventory.amount("medicine") == 1 and game.cycle.bed_count() == 2
		var before: Dictionary = SaveSystem.capture(game)
		game._settle_night([])
		ok = ok and before == SaveSystem.capture(game)
		game.begin_day()
		ok = ok and game.cycle.phase == "day" and CampaignCycle.minute(game.simulation_time) == 360
	else: ok = false
	if not SaveSystem.validate(SaveSystem.capture(game)).is_empty(): ok = false
	print("CAMPAIGN PROCESS ", phase, " PASS:" if ok else " FAIL:", " physical construction, deliberate loot and single night settlement")
	game.free()
	await create_timer(0.12).timeout
	quit(0 if ok else 1)
