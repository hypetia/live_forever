extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(2);return
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false;root.add_child(game);game.set_process(false);game.save_store.path = args[1]
	var okay := true
	if args[0] == "write":
		game.inventory.deposit({"materials":6,"tools":1,"fuel":2},"declared cross-process district fixture")
		game.end_day();game.cycle.loadout = {"materials":6,"tools":1,"fuel":1};okay = game.start_expedition()
		var f: ExpeditionState = game.expedition
		for e in f.enemies: e["hp"] = 0;e["mode"] = "dead"
		game.districts.trip_dead = f.enemies.size()
		f.player_x = 1620;f.floor_level = 1;f.player_y = 400;f._search(10,game.survivors[f.actor_id])
		okay = game.districts.begin_work(game,"build") and okay
		game.districts.tick_work(game,.5,{})
	elif args[0] == "resume":
		okay = game.load_game()
		var f: ExpeditionState = game.expedition
		okay = okay and game.districts.work["elapsed"] == .5 and f.bag["materials"] == 6 and f.bag["tools"] == 1
		game.toggle_pause();game.advance_simulation(8.6)
		okay = okay and game.districts.regions["street"]["built"] and f.bag["materials"] == 1 and f.bag["tools"] == 0
		game.expedition_decoy()
		var e: Dictionary = f.enemies[2]
		e["hp"] = 40;e["mode"] = "patrol";e["x"] = 1840;e["direction"] = 1.0
		game.advance_simulation(.2)
		okay = okay and f.decoys.size() == 1 and f.bag["materials"] == 0 and f.bag["fuel"] == 0 and e["target"] == f.decoys[0]["x"]
	elif args[0] == "return":
		okay = game.load_game()
		var f: ExpeditionState = game.expedition
		okay = okay and f.decoys.size() == 1 and f.decoys[0]["remaining"] > 17 and f.enemies[2]["target"] == f.decoys[0]["x"]
		game.toggle_pause();game.expedition_retreat()
		for n in range(2000):
			game.advance_simulation(.02)
			if game.departure_dialog.visible:game.confirm_departure();break
		okay = okay and game.cycle.phase == "dawn" and game.districts.regions["street"]["built"] and f.decoys.is_empty()
	elif args[0] == "shift":
		okay = game.load_game() and game.cycle.phase == "dawn"
		game.begin_day();game.end_day();game.cycle.roles.assign(["outpost","bed","scavenge"])
		var fuel: int = game.inventory.amount("fuel")
		okay = game.start_expedition() and okay
		okay = okay and game.districts.shift["map"] == "street" and game.districts.shift["fuel"] == 1 and game.districts.shift["ammo"] == 0 and game.inventory.amount("fuel") == fuel-1
	elif args[0] == "verify":
		okay = game.load_game() and game.cycle.phase == "scavenge" and game.cycle.roles[0] == "outpost" and not game.districts.shift.is_empty()
		game.toggle_pause();game.expedition_retreat();game.confirm_departure()
		okay = okay and game.cycle.phase == "dawn" and game.districts.shift.is_empty() and game.districts.regions["street"]["shifts"] == 1
		var credits: Array = game.inventory.history.filter(func(entry):return entry["reason"].begins_with("前哨轮值回收"))
		okay = okay and credits.size() == 1 and credits[0]["items"] == {"raw_food":2,"water":1}
		var before := SaveSystem.capture(game);var lines: Array[String] = []
		game.districts.dawn(game,lines);game._settle_night([])
		okay = okay and before == SaveSystem.capture(game)
	else:okay = false
	okay = game.save_store.write_state(game)["ok"] and okay
	print("DISTRICT PROCESS %s %s: field work, lure memory, return, paid crew duty and single settlement" % [args[0],"PASS" if okay else "FAIL"])
	game.free();await create_timer(.12).timeout;quit(0 if okay else 1)
