extends SceneTree
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(2); return
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.save_store.path = args[1]
	var okay := true
	if args[0] == "write":
		game.end_day()
		okay = game.start_expedition()
		game.interface.set_target(300,0,false,0)
		for tick in range(78): game.advance_simulation(1.0/60)
		okay = okay and game.expedition.search_index == 0 and game.expedition.search_progress > 0 and game.expedition.loot_site == -1
	elif args[0] == "read":
		okay = game.load_game() and game.expedition.search_progress > 0
		game.paused = false
		game.expedition_view.search_held = true
		for tick in range(150): game.advance_simulation(1.0/60)
		game._process(0)
		game.expedition_view.search_held = false
		var actor: Survivor = game.survivors[game.expedition.actor_id]
		game.expedition.take_loot("raw_food",100,actor)
		game.expedition.take_loot("water",100,actor)
		game.paused = true
		game.expedition_retreat()
		okay = okay and game.cycle.return_requested and not game.expedition.site_has_supplies(0) and game.expedition.active
	elif args[0] == "return":
		okay = game.load_game() and game.cycle.return_requested and not game.expedition.site_has_supplies(0)
		game.paused = false
		for tick in range(180): game.advance_simulation(1.0/60)
		okay = okay and game.cycle.phase == "dawn" and not game.expedition.active and not game.cycle.return_requested
	elif args[0] == "verify":
		okay = game.load_game() and game.cycle.phase == "dawn" and not game.cycle.return_requested
		var before := SaveSystem.capture(game)
		game._settle_night([])
		okay = okay and SaveSystem.capture(game) == before
	else: okay = false
	var written: Dictionary = game.save_store.write_state(game)
	if not written["ok"]: print(written)
	okay = okay and written["ok"]
	print("INTERACTIONS PROCESS %s %s: partial search, empty crate, queued return and single extraction" % [args[0],"PASS" if okay else "FAIL"])
	game.free()
	await create_timer(0.12).timeout
	quit(0 if okay else 1)
